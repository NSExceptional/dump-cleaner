//
//  NSString+Replacement.m
//  dump-cleaner
//
//  Created by Tanner on 7/15/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSString+Replacement.h"
#import "NSScanner+ObjectiveC.h"

@implementation NSString (Replacement)

- (instancetype)stringByReplacingPattern:(NSString *)pattern with:(NSString *)replacement {
    return [self stringByReplacingOccurrencesOfString:pattern withString:replacement options:NSRegularExpressionSearch range:NSMakeRange(0, self.length)];
}

- (NSString *)methodSelectorString {
    NSScanner *scanner = [NSScanner scannerWithString:self];
    
    if (![self scanstring])
    NSArray *matches = [self allMatchesForRegex:krMethodSelectorWithParams atIndex:0];
    if (matches) {
        NSString *selector = [matches join:nil];
        return [selector stringByReplacingPattern:@" +$" with:@";"];
    }
    
    return [self allMatchesForRegex:krMethodSelectorWithoutParams atIndex:0].firstObject;
}

@end
