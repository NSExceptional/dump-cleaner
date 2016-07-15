//
//  DCSDK.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCSDK.h"
#import "DCClass.h"
#import "DCProtocol.h"


typedef void (^DCClassBlock)(DCClass *classOrCategory);
typedef void (^DCProtocolBlock)(DCProtocol *protocol);
typedef void (^DCStructBlock)(NSString *structName);

@interface DCSDK ()
@property (nonatomic, readonly) NSString *SDKPath;
@property (nonatomic, readonly) NSString *frameworksPath;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCClass*>    *SDKClasses;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCClass*>    *SDKCategories;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCProtocol*> *SDKProtocols;

@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCClass*>    *dumpedClasses;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCClass*>    *dumpedCategories;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCProtocol*> *dumpedProtocols;
@property (nonatomic, readonly) NSMutableSet *SDKStructs;
@property (nonatomic, readonly) NSMutableSet *dumpedStructs;

@end

@implementation DCSDK

#pragma mark Initialization

+ (instancetype)SDKAtPath:(NSString *)path {
    return [[self alloc] initWithPath:path];
}

- (id)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _SDKPath = path;
        _frameworksPath = [self.SDKPath stringByAppendingPathComponent:@"System/Library/Frameworks"];
        _SDKClasses     = [NSMutableDictionary dictionary];
        _SDKCategories  = [NSMutableDictionary dictionary];
        _SDKProtocols   = [NSMutableDictionary dictionary];
        _structs        = [NSMutableSet set];
        _dumpedClasses     = [NSMutableDictionary dictionary];
        _dumpedCategories  = [NSMutableDictionary dictionary];
        _dumpedProtocols   = [NSMutableDictionary dictionary];
        
        // Assert that SDK exists
        BOOL isDirectory = NO;
        if (!([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory)) {
            DCExitWithMessage(@"SDK does not exist at the given path: %@", path);
        }
        
        [self findThingsInSDK];
    }
    
    return self;
}

#pragma mark Public interface

- (void)processFrameworksInDirectory:(NSString *)frameworksFolder andOutputTo:(NSString *)outputDirectory {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *frameworks = [manager contentsOfDirectoryAtPath:frameworksFolder error:&error];
    
    DCExitOnError(error);
    
    NSMutableDictionary *frameworksToNewNames = [NSMutableDictionary dictionary];
    NSMutableDictionary *newNamesToPaths      = [NSMutableDictionary dictionary];
    
    // Process all dumped frameworks //
    
    // framework = "Framework.framework"
    for (NSString *framework in frameworks) {
        NSString *frameworkPath = [frameworksFolder stringByAppendingPathComponent:framework];
        
        // TODO test this shit
        // Get headers in the given framework folder
        NSArray *headers = [[manager filesInDirectoryAtPath:frameworkPath recursive:YES] map:^id(NSString *item, NSUInteger idx, BOOL *discard) {
            *discard = ![item hasSuffix:@".h"];
            return item;
        }];
        
        // output = ".../outdir/Cleaned/FrameworkPrivate.framework/Headers/"
        NSString *newFrameworkName = [framework stringByReplacingOccurrencesOfString:@".framework" withString:@"Private"];
        NSString *output = [outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"/Cleaned/%@.framework/Headers/", newFrameworkName]];
        [self processFilesAtPaths:headers andSetOutputLocation:output];
        
        frameworksToNewNames[framework] = newFrameworkName;
        newNamesToPaths[newFrameworkName] = output;
    }
    
    // Write cleaned headers to output directory, write umbrella headers to each directory //
    
    [self updateAndWriteAllDumpedInterfaces];
    
    for (NSString *framework in frameworks) {
        NSString *name   = frameworksToNewNames[framework];
        NSString *outdir = newNamesToPaths[name];
        
        [self generateUmbrellaHeadersForOutputDirectory:outdir frameworkName:name];
    }
}

#pragma mark - Private -

#pragma mark Workflow

- (void)processFilesAtPaths:(NSArray<NSString*> *)paths andSetOutputLocation:(NSString *)directory {
    if (!paths.count) return;
    
    // Collect all dumped header contents
    for (NSString *path in paths)
        [self processDumpedHeader:path];
    
    // Create output folder
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
    DCExitOnError(error);
    
    // Set output folder for each dumped thing
    for (NSArray *array in @[self.dumpedClasses, self.dumpedCategories, self.dumpedProtocols])
        for (DCObject<DCInterface> *thing in array)
            [thing setOutputDirectory:directory];
}

- (void)updateAndWriteAllDumpedInterfaces {
    // Remove duplicate structs
    NSMutableSet *filteredDumps = self.dumpedStructs.mutableCopy;
    [filteredDumps minusSet:self.SDKStructs];
    _dumpedStructs = filteredDumps;
    
    NSArray *allStructs = @[self.SDKStructs.allObjects, self.dumpedStructs.allObjects].flattened;
    for (DCObject<DCInterface> *thing in @[self.dumpedClasses, self.dumpedCategories, self.dumpedProtocols].flattened) {
        [thing updateWithKnownClasses:self.SDKClasses.allValues];
        [thing updateWithKnownClasses:self.dumpedClasses.allValues];
        [thing updateWithKnownProtocols:self.SDKProtocols.allValues];
        [thing updateWithKnownProtocols:self.dumpedProtocols.allValues];
        [thing updateWithKnownStructs:allStructs];
        
        // Actually write
        NSError *error = nil;
        [thing.string writeToFile:thing.outputFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
        DCWriteError(error);
    }
}

- (void)generateUmbrellaHeadersForOutputDirectory:(NSString *)headersFolder frameworkName:(NSString *)frameworkName {
    NSParameterAssert(headersFolder); NSParameterAssert(frameworkName);
    
    // Get all existing headers
    NSError *error = nil;
    NSArray *newHeaders = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:headersFolder error:&error];
    DCExitOnError(error);
    
    // Transform header files to import statements
    NSArray *imports = [newHeaders map:^id(NSString *file, NSUInteger idx, BOOL *discard) {
        return [NSString stringWithFormat:@"#import <%@/%@>\n", frameworkName, file];
    }];
    
    // Build umbrella content
    NSMutableString *umbrella = [NSMutableString stringWithFormat:kUmbrellaHeaderHeader, frameworkName];
    for (NSString *import in imports)
        [umbrella appendString:import];
    [umbrella appendString:@"\n"];
    
    // Write it to ".../FrameworkPrivate.framework/Headers/FrameworkPrivate.h"
    NSString *outfile = [headersFolder stringByAppendingPathComponent:[frameworkName stringByAppendingString:@".h"]];
    [umbrella writeToFile:outfile atomically:YES encoding:NSUTF8StringEncoding error:&error];
    DCExitOnError(error);
}

#pragma mark Processing

- (void)findThingsInSDK {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *frameworks = [manager contentsOfDirectoryAtPath:self.frameworksPath error:&error];
    DCExitOnError(error);
    
    // Enumerate framework folders in SDK
    for (NSString *framework in frameworks) {
        // headersPath = "Framework.framework/" + "Headers", then
        // headersPath = ".../frameworksdir/" + "Framework.framework/Headers"
        NSString *headersPath = [framework stringByAppendingPathComponent:@"Headers"];
        headersPath = [self.frameworksPath stringByAppendingPathComponent:headersPath];
        BOOL isDirectory = NO;
        
        // Check if directory exists
        if ([manager fileExistsAtPath:headersPath isDirectory:&isDirectory] && isDirectory) {
            // Proccess framework headers
            NSArray *headers = [manager filesInDirectoryAtPath:headersPath recursive:NO];
            for (NSString *header in headers)
                [self proccessSDKHeader:header];
            
        } else {
            DCWriteMessage(@"No headers folder in framework '%@'", framework);
        }
    }
}

- (void)proccessSDKHeader:(NSString *)path {
    [self processHeader:path classes:^(DCClass *classOrCategory) {
        NSParameterAssert(self.SDKClasses[classOrCategory.name] == nil);
        self.SDKClasses[classOrCategory.name] = classOrCategory;
        
    } categories:^(DCClass *classOrCategory) {
        NSParameterAssert(self.SDKCategories[classOrCategory.categoryKey] == nil);
        self.SDKCategories[classOrCategory.categoryKey] = classOrCategory;
        
    } protocols:^(DCProtocol *protocol) {
        NSParameterAssert(self.SDKProtocols[protocol.name] == nil);
        self.SDKProtocols[protocol.name] = protocol;
        
    } structs:^(NSString *structName) {
        [self.dumpedStructs addObject:structName];
    }];
}

- (void)processDumpedHeader:(NSString *)path {
    [self processHeader:path classes:^(DCClass *classOrCategory) {
        // Make it a class if it is a private class, category if it is a public class.
        // We will find methods and properties later
        if (!self.SDKClasses[classOrCategory.name]) {
            NSParameterAssert(self.dumpedClasses[classOrCategory.name] == nil);
            self.dumpedClasses[classOrCategory.name] = classOrCategory;
        } else {
            classOrCategory = [DCClass withString:classOrCategory.string categoryName:@"AppleInternal"];
            NSParameterAssert(self.dumpedCategories[classOrCategory.categoryKey] == nil);
            self.dumpedCategories[classOrCategory.categoryKey] = classOrCategory;
        }
        
    } categories:^(DCClass *classOrCategory) {
        if (!self.SDKCategories[classOrCategory.categoryKey]) {
            NSParameterAssert(self.dumpedCategories[classOrCategory.categoryKey] == nil);
            self.dumpedCategories[classOrCategory.categoryKey] = classOrCategory;
        }
        
    } protocols:^(DCProtocol *protocol) {
        if (!self.SDKProtocols[protocol.name]) {
            NSParameterAssert(self.dumpedProtocols[protocol.name] == nil);
            self.dumpedProtocols[protocol.name] = protocol;
        }
        
    } structs:^(NSString *structName) {
        [self.SDKStructs addObject:structName];
    }];
}

- (void)processHeader:(NSString *)path
              classes:(DCClassBlock)classes
           categories:(DCClassBlock)categories
            protocols:(DCProtocolBlock)protocols
              structs:(DCStructBlock)structs {
    
    NSError *error = nil;
    NSString *header = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    DCExitOnError(error);
    
    
    // Classes
    for (NSTextCheckingResult *match in [header matchesForRegex:krClassDefinition]) {
        NSString *string = [header substringWithRange:match.range];
        classes([DCClass withString:string]);
    }
    
    // Categories
    for (NSTextCheckingResult *match in [header matchesForRegex:krCategoryDefinition]) {
        NSString *string = [header substringWithRange:match.range];
        categories([DCClass withString:string]);
    }
    
    // Protocols
    for (NSTextCheckingResult *match in [header matchesForRegex:krProtocolDefinition]) {
        NSString *string = [header substringWithRange:match.range];
        protocols([DCProtocol withString:string]);
    }
    
    // Structs
    for (NSTextCheckingResult *match in [header matchesForRegex:krStructUnknown_1_2]) {
        NSString *name = [header substringWithRange:[match rangeAtIndex:match.numberOfRanges-1]]; // -1 will be the typedef if 3 or the name if 2
        structs(name);
    }
}

@end
























