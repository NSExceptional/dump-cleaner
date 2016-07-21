//
//  DCProgressBar.h
//  dump-cleaner
//
//  Created by Tanner on 7/21/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DCProgressBar : NSObject

/// Singleton, do not use others
+ (instancetype)currentProgress;

- (void)start;
- (void)printMessage:(NSString *)message;
- (void)stop;

// Prints newline when percentage == 100
@property (nonatomic) NSInteger percentage;

@end
