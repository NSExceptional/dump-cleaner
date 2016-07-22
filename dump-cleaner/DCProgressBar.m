//
//  DCProgressBar.m
//  dump-cleaner
//
//  Created by Tanner on 7/21/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCProgressBar.h"
#include <sys/ioctl.h>


@interface DCProgressBar ()
@property (nonatomic) BOOL showing;
@property (nonatomic, readonly) NSString *progressString;
@property (nonatomic, readonly) int progressMaxWidth;
@property (nonatomic) int lastConsoleWidth;
@end

@implementation DCProgressBar

+ (instancetype)currentProgress {
    static DCProgressBar *sharedProgress = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedProgress = [self new];
    });
    
    return sharedProgress;
}

- (void)setPercentage:(NSInteger)percentage {
    _percentage = percentage;
    [self update];
    
    if (percentage == 100) {
        printf("\n");
        fflush(stdout);
    }
}

- (void)verbose1:(NSString *)message {
    if (self.verbosity >= 1)
        [self printMessage:message];
}

- (void)verbose2:(NSString *)message {
    if (self.verbosity >= 2)
        [self printMessage:message];
}

- (void)printMessage:(NSString *)message {
    if (!self.showing) return;
    
    NSString *format = [@"\r%" stringByAppendingString:[NSString stringWithFormat:@"-%ds\n", self.lastConsoleWidth]];
    printf(format.UTF8String, message.UTF8String);
    fflush(stdout);
    [self update];
}

- (void)start {
    self.showing = YES;
    printf("\n");
    fflush(stdout);
    [self update];
}

- (void)stop {
    self.showing = NO;
    printf("\n");
    fflush(stdout);
}

- (void)update {
    if (!self.showing) return;
    
    printf("\r%s", self.progressString.UTF8String);
    fflush(stdout);
}

- (int)progressMaxWidth {
    //     For testing in Xcode when the below doesn't work
    return 80;
    struct winsize ww;
    ioctl(STDOUT_FILENO, TIOCGWINSZ, &ww);
    return MIN(80, ww.ws_col);
}

- (NSString *)progressString {
    CGFloat percentage = self.percentage / 100.f;
    
    int progressMaxWidth = self.progressMaxWidth;
    int length = progressMaxWidth-2;
    int count = (int)(percentage * length);
    int i = 0;
    
    NSString *message = [NSString stringWithFormat:@"%lu%%", self.percentage];
    
    NSMutableString *string = [NSMutableString stringWithString:@"["];
    for (; i < count; i++) {
        if (i == length/2 - message.length/2) {
            [string appendString:message];
            i += message.length;
        } else {
            [string appendString:@"="];
        }
    }
    
    for (; i < length; i++) {
        if (i == length/2 - message.length/2) {
            [string appendString:message];
            i += message.length;
        } else {
            [string appendString:@" "];
        }
    }
    
    [string appendString:@"]"];
    
    self.lastConsoleWidth = progressMaxWidth;
    return string;
}

@end
