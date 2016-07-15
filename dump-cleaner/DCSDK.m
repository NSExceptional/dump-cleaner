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
    
}

#pragma mark Private

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
























