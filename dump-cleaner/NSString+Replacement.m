//
//  NSString+Replacement.m
//  dump-cleaner
//
//  Created by Tanner on 7/15/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSString+Replacement.h"


@implementation NSString (Replacement)

- (instancetype)stringByReplacingPattern:(NSString *)pattern with:(NSString *)replacement {
    return [self stringByReplacingOccurrencesOfString:pattern withString:replacement options:NSRegularExpressionSearch range:NSMakeRange(0, self.length)];
}

- (NSString *)methodSelectorString {
    NSArray *matches = [self allMatchesForRegex:krMethodSelectorWithParams atIndex:0];
    if (matches) {
        return [matches join:nil];
    }
    
    return [self allMatchesForRegex:krMethodSelectorWithoutParams atIndex:0].firstObject;
}

@end
