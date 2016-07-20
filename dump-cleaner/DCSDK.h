//
//  DCSDK.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DCSDK : NSObject

/// @return {name, path}
+ (NSDictionary<NSString*,NSString*> *)availableSDKs;
+ (instancetype)SDKAtPath:(NSString *)path;
+ (instancetype)latestSDK;

- (void)processFrameworksInDirectory:(NSString *)frameworksFolder andOutputTo:(NSString *)outputDirectory;

@end
