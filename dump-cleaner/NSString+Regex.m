//
//  NSString+Regex.m
//  dump-cleaner
//
//  Created by Tanner Bennett on 3/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSString+Regex.h"


@implementation NSString (Regex)

- (BOOL)matchesPattern:(NSString *)pattern {
    if (!pattern) return NO;
    
    NSRegularExpression *expr = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    return [expr numberOfMatchesInString:self options:0 range:NSMakeRange(0, self.length)] > 0;
}

- (NSComparisonResult)compareSDKVersion:(NSString *)version {
    NSArray<NSNumber*> *myParts = [[self componentsSeparatedByString:@"."] map:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return @(object.integerValue);
    }];
    NSArray<NSNumber*> *otherParts = [[version componentsSeparatedByString:@"."] map:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return @(object.integerValue);
    }];
    assert(myParts.count && otherParts.count);
    
    NSComparisonResult result = [myParts[0] compare:otherParts[0]];
    
    if (result == NSOrderedSame) {
        result = [myParts[1] compare:otherParts[1]];
        if (result == NSOrderedSame) {
            if (myParts.count >= 3) {
                if (otherParts.count >= 3) {
                    return [myParts[2] compare:otherParts[2]];
                }
                
                return NSOrderedDescending;
            }
            else if (otherParts.count >= 3) {
                return NSOrderedAscending;
            }
            else {
                return NSOrderedSame;
            }
        }
        
        return result;
    }
    
    return result;
}

- (NSString *)matchGroupAtIndex:(NSUInteger)idx forRegex:(NSString *)regex {
    NSArray *matches = [self matchesForRegex:regex];
    if (matches.count == 0) return nil;
    NSTextCheckingResult *match = matches[0];
    if (idx >= match.numberOfRanges) return nil;
    
    if (match.numberOfRanges <= idx)
        idx = match.numberOfRanges-1;
    return [self substringWithRange:[match rangeAtIndex:idx]];
}

- (NSArray<NSTextCheckingResult*> *)matchesForRegex:(NSString *)pattern {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    if (error) {
        return nil;
    }
    
    NSArray *matches = [regex matchesInString:self options:0 range:NSMakeRange(0, self.length)];
    return matches.count == 0 ? nil : matches;
}

- (NSArray *)allMatchesForRegex:(NSString *)regex atIndex:(NSUInteger)idx {
    NSArray *matches = [self matchesForRegex:regex];
    if (matches.count == 0) return @[];
    
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *result in matches) {
        if (result.numberOfRanges > idx) {
            NSRange r = [result rangeAtIndex:idx];
            if (r.location != NSNotFound) {
                [strings addObject:[self substringWithRange:r]];
            }
        }
    }
    
    return strings;
}

- (NSString *)stringByReplacingMatchesForRegex:(NSString *)pattern withString:(NSString *)replacement {
    return [self stringByReplacingOccurrencesOfString:pattern withString:replacement options:NSRegularExpressionSearch range:NSMakeRange(0, self.length)];
}

- (NSArray<NSValue*> *)rangesForAllMatchesForRegex:(NSString *)regex atIndex:(NSUInteger)idx {
    NSArray *matches = [self matchesForRegex:regex];
    if (matches.count == 0) return @[];
    
    NSMutableArray *ranges = [NSMutableArray array];
    for (NSTextCheckingResult *result in matches) {
        if (result.numberOfRanges >= idx)
            [ranges addObject:[NSValue valueWithRange:[result rangeAtIndex:idx]]];
    }
    
    return ranges;
}

@end