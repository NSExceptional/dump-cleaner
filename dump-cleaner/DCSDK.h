//
//  DCSDK.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DCSDK : NSObject

+ (instancetype)SDKAtPath:(NSString *)path;

- (void)processFrameworksInDirectory:(NSString *)frameworksFolder andOutputTo:(NSString *)outputDirectory;

@end
