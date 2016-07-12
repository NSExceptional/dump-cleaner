//
//  DCSDK.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCSDK.h"


@interface DCSDK ()
@property (nonatomic, readonly) NSString *SDKPath;
@property (nonatomic, readonly) NSString *frameworksPath;
@property (nonatomic, readonly) NSMutableDictionary *knownClasses;
@property (nonatomic, readonly) NSMutableDictionary *knownProtocols;
@property (nonatomic, readonly) NSArray *knownStructs;
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
        _knownClasses = [NSMutableDictionary dictionary];
        
        // Assert that SDK exists
        BOOL isDirectory = NO;
        if (!([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory)) {
            [NSException raise:NSInvalidArgumentException format:@"SDK does not exist at the given path: %@", path];
        }
    }
    
    return self;
}

#pragma mark Public interface

- (void)processFilesAtPaths:(NSArray<NSString *> *)paths {
    
}

#pragma mark Private

- (void)findClassesInSDK {
    NSError *error = nil;
    NSArray *frameworks = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.frameworksPath error:&error];
    
    if (error) {
        printf("%s", error.localizedDescription.UTF8String);
        exit(1);
    }
    
    
}

@end
























