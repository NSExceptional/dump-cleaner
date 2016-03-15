//
//  NSString+Regex.m
//  dump-cleaner
//
//  Created by Tanner Bennett on 3/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSString+Regex.h"


@implementation NSString (Regex)

- (NSString *)pascalCaseString {
    if (!self.length) return self;
    char c = [self characterAtIndex:0];
    c = toupper(c);
    return [NSString stringWithFormat:@"%c%@", c, [self stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""]];
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

- (NSArray *)matchesForRegex:(NSString *)pattern {
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    if (error)
        return nil;
    NSArray *matches = [regex matchesInString:self options:0 range:NSMakeRange(0, self.length)];
    if (matches.count == 0)
        return nil;
    
    return matches;
}

- (NSArray *)allMatchesForRegex:(NSString *)regex atIndex:(NSUInteger)idx {
    NSArray *matches = [self matchesForRegex:regex];
    if (matches.count == 0) return @[];
    
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *result in matches) {
        if (result.numberOfRanges >= idx)
            [strings addObject:[self substringWithRange:[result rangeAtIndex:idx]]];
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