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

+ (instancetype)latestSDK {
    NSString *SDK = [[self firstAvailableSDKDirectory] stringByAppendingPathComponent:kDefaultSDKName];
    return SDK ? [self SDKAtPath:SDK] : nil;
}

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
        _SDKStructs     = [NSMutableSet set];
        _dumpedClasses     = [NSMutableDictionary dictionary];
        _dumpedCategories  = [NSMutableDictionary dictionary];
        _dumpedProtocols   = [NSMutableDictionary dictionary];
        _dumpedStructs     = [NSMutableSet set];
        
        [NSScanner setExistingProtocolPools:_SDKProtocols dumped:_dumpedProtocols];
        
        // Assert that SDK exists
        BOOL isDirectory = NO;
        if (!([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory)) {
            DCExitWithFormat(@"SDK does not exist at the given path: %@", path);
        }
        
        [self findThingsInSDK];
    }
    
    return self;
}

#pragma mark Public interface

+ (NSDictionary<NSString*,NSString*> *)availableSDKs {
    NSFileManager *manager = [NSFileManager defaultManager];
    
    // Get SDKs folder
    NSString *SDKFolder = [self firstAvailableSDKDirectory];
    if (!SDKFolder) { DCExitWithMessage(kCouldNotFindSDKsMessage); }
    
    // Get contents
    NSError *error = nil;
    NSArray<NSString*> *names = [manager contentsOfDirectoryAtPath:SDKFolder error:&error];
    DCExitOnError(error);
    
    if (!names.count) { DCExitWithFormat(@"No SDKs found in the SDKs folder located at: %@", SDKFolder); }
    
    // Filter by ending with .sdk, append paths
    names = [names map:^id(NSString *object, NSUInteger x) {
        return [object hasSuffix:@".sdk"] ? object : nil;
    }];
    NSArray *paths = [names map:^id(NSString *object, NSUInteger idx) {
        return [SDKFolder stringByAppendingPathComponent:object];
    }];
    
    return [NSDictionary dictionaryWithObjects:paths forKeys:names];
}

+ (NSString *)firstAvailableSDKDirectory {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    
    if ([manager fileExistsAtPath:kXcodeSDKsPath isDirectory:&isDirectory] && isDirectory) {
        return kXcodeSDKsPath;
    } else if ([manager fileExistsAtPath:kXcodeBetaSDKsPath isDirectory:&isDirectory] && isDirectory) {
        return kXcodeBetaSDKsPath;
    }
    
    return nil;
}

/// Dumped frameworks, not SDK frameworks. See findThingsInSDK for that.
- (void)processFrameworksInDirectory:(NSString *)frameworksFolder andOutputTo:(NSString *)outputDirectory {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *frameworks = [manager contentsOfDirectoryAtPath:frameworksFolder error:&error];
    frameworks = [frameworks map:^id(NSString *framework, NSUInteger idx) {
        return [framework.pathExtension isEqualToString:@"framework"] ? framework : nil;
    }];
    
    DCExitOnError(error);
    
    NSMutableDictionary *frameworksToNewNames = [NSMutableDictionary dictionary];
    NSMutableDictionary *newNamesToPaths      = [NSMutableDictionary dictionary];
    
    // Process all dumped frameworks //
    
    DCProgressBar *progress = [DCProgressBar currentProgress];
    [progress printMessage:@"Proessing dumped headers..."];
    BOOL doFrameworkProgress = [DCProgressBar currentProgress].verbosity >= 1;
    NSUInteger f = 0;
    
    // framework = "Framework.framework"
    for (NSString *framework in frameworks) {
        // Progress indicator
        if (!doFrameworkProgress) {
            progress.percentage = f++/frameworks.count * 100;
        } else {
            progress.percentage = 0;
        }
        
        [progress verbose1:framework];
        
        // TODO test this shit
        // Get headers in the given framework folder
        NSString *frameworkPath = [frameworksFolder stringByAppendingPathComponent:framework];
        NSArray *headers = [[manager filesInDirectoryAtPath:frameworkPath recursive:YES] map:^id(NSString *item, NSUInteger idx) {
            return [item.pathExtension isEqualToString:@"h"] ? item : nil;
        }];
        
        // output = ".../outdir/Cleaned/FrameworkPrivate.framework/Headers/"
        NSString *newFrameworkName = [framework stringByReplacingOccurrencesOfString:@".framework" withString:@"Private"];
        NSString *output = [outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"/Cleaned/%@.framework/Headers/", newFrameworkName]];
        [self processFilesAtPaths:headers andSetOutputLocation:output showProgress:doFrameworkProgress];
        
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

- (void)processFilesAtPaths:(NSArray<NSString*> *)paths andSetOutputLocation:(NSString *)directory showProgress:(BOOL)showProgress {
    if (!paths.count) return;
    
    // Collect all dumped header contents
    NSUInteger i = 1;
    for (NSString *path in paths) {
        [self processDumpedHeader:path];
        if (showProgress) {
            [DCProgressBar currentProgress].percentage = i++/paths.count * 100;
        }
    }
    
    // Create output folder
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
    DCExitOnError(error);
    
    // Set output folder for each dumped thing
    for (NSMutableDictionary *dict in @[self.dumpedClasses, self.dumpedCategories, self.dumpedProtocols])
        for (DCInterface *thing in dict.allValues)
            [thing setOutputDirectory:directory];
}

- (void)updateAndWriteAllDumpedInterfaces {
    // Remove duplicate structs
    NSMutableSet *filteredDumps = self.dumpedStructs.mutableCopy;
    [filteredDumps minusSet:self.SDKStructs];
    _dumpedStructs = filteredDumps;
    //    NSArray *allStructs = @[self.SDKStructs.allObjects, self.dumpedStructs.allObjects].flattened;
    
    // Remove existing protocols
    [self.dumpedProtocols removeObjectsForKeys:self.SDKProtocols.allKeys];
    
    // Update
    for (DCInterface *thing in @[self.dumpedClasses.allValues, self.dumpedCategories.allValues, self.dumpedProtocols.allValues].flattened) {
        [thing updateWithKnownClasses:self.SDKClasses.allValues];
        [thing updateWithKnownClasses:self.dumpedClasses.allValues];
        [thing updateWithKnownProtocols:self.SDKProtocols.allValues];
        [thing updateWithKnownProtocols:self.dumpedProtocols.allValues];
        
        // Actually write
        NSError *error = nil;
        [thing.string writeToFile:thing.outputLocation atomically:YES encoding:NSUTF8StringEncoding error:&error];
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
    NSArray *imports = [newHeaders map:^id(NSString *file, NSUInteger idx) {
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
    
    [[DCProgressBar currentProgress] printMessage:@"Parsing SDK..."];
    BOOL doFrameworkProgress = [DCProgressBar currentProgress].verbosity >= 1;
    NSUInteger f = 0;
    
    // Enumerate framework folders in SDK
    for (NSString *framework in frameworks) {
        // Progress indicator
        if (!doFrameworkProgress) {
            [DCProgressBar currentProgress].percentage = f++/frameworks.count * 100;
        } else {
            [DCProgressBar currentProgress].percentage = 0;
        }
        
        // headersPath = "Framework.framework/" + "Headers", then
        // headersPath = ".../frameworksdir/" + "Framework.framework/Headers"
        NSString *headersPath = [framework stringByAppendingPathComponent:@"Headers"];
        headersPath = [self.frameworksPath stringByAppendingPathComponent:headersPath];
        BOOL isDirectory = NO;
        
        // Check if directory exists
        if ([manager fileExistsAtPath:headersPath isDirectory:&isDirectory] && isDirectory) {
            [[DCProgressBar currentProgress] verbose1:framework];
            
            // Proccess framework headers
            NSArray *headers = [manager filesInDirectoryAtPath:headersPath recursive:NO];
            NSUInteger fh = 1;
            for (NSString *header in headers) {
                [self proccessSDKHeader:header];
                if (doFrameworkProgress) {
                    [DCProgressBar currentProgress].percentage = fh++/headers.count * 100;
                }
            }
            
        } else {
            [[DCProgressBar currentProgress] printMessage:Format(@"No headers folder in framework '%@'", framework)];
        }
    }
}

- (void)proccessSDKHeader:(NSString *)path {
    NSParameterAssert(path);
    
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
        [self.SDKStructs addObject:structName];
    }];
}

- (void)processDumpedHeader:(NSString *)path {
    NSParameterAssert(path);
    [self processHeader:path classes:^(DCClass *classOrCategory) {
        // Make it a class if it is a private class, category if it is a public class.
        // We will find methods and properties later
        if (!self.SDKClasses[classOrCategory.name]) {
            NSParameterAssert(self.dumpedClasses[classOrCategory.name] == nil);
            self.dumpedClasses[classOrCategory.name] = classOrCategory;
        } else {
            classOrCategory.categoryName = @"AppleInternal";
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
        [self.dumpedStructs addObject:structName];
    }];
}

- (void)processHeader:(NSString *)path
              classes:(DCClassBlock)classes
           categories:(DCClassBlock)categories
            protocols:(DCProtocolBlock)protocols
              structs:(DCStructBlock)structs {
    
    NSError *error = nil;
    NSString *header = [NSString stringWithContentsOfFile:path usedEncoding:NULL error:&error];
    // Some SDK files are in this encoding and the above does not work for some reason
    if (error) {
        NSError *error2 = nil;
        header = [NSString stringWithContentsOfFile:path encoding:NSMacOSRomanStringEncoding error:&error2];
        if (header) {
            error = nil;
        }
    }
    DCExitOnError(error);
    
    // Trim trailing whitespace
    
    [[DCProgressBar currentProgress] verbose2:path];
    
    NSAssert(header != nil, @"Header contents should be initialized here");
    header = [header stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSScanner *scanner = [NSScanner scannerWithString:header];
    BOOL success = [scanner parseHeader:^(NSArray<DCInterface *> *interfaces, NSArray *structNames) {
        for (DCInterface *interface in interfaces) {
            if ([interface class] == [DCClass class]) {
                if ([(DCClass*)interface categoryName]) {
                    categories((id)interface);
                } else {
                    classes((id)interface);
                }
            } else if ([interface class] == [DCProtocol class]) {
                protocols((id)interface);
            }
        }
        
        for (NSString *name in structNames)
            structs(name);
    }];
    
    if (!success) {
        DCExitWithFormat(@"Unable to process header: %@", path);
    }
}

@end
























