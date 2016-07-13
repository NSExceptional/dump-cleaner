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


@interface DCSDK ()
@property (nonatomic, readonly) NSString *SDKPath;
@property (nonatomic, readonly) NSString *frameworksPath;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCClass*> *SDKClasses;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, DCProtocol*> *SDKProtocols;
@property (nonatomic, readonly) NSMutableDictionary<NSString*, NSString*> *SDKStructs;
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
        _SDKClasses   = [NSMutableDictionary dictionary];
        _SDKProtocols = [NSMutableDictionary dictionary];
        _SDKStructs   = [NSMutableDictionary dictionary];
        
        // Assert that SDK exists
        BOOL isDirectory = NO;
        if (!([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory)) {
            DCExitWithMessage(@"SDK does not exist at the given path: %@", path);
        }
    }
    
    return self;
}

#pragma mark Public interface

- (void)processFilesAtPaths:(NSArray<NSString *> *)paths {
    
}

#pragma mark Private

- (void)findThingsInSDK {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *frameworks = [manager contentsOfDirectoryAtPath:self.frameworksPath error:&error];
    
    DCExitOnError(error);
    }
    
    
}

@end
























