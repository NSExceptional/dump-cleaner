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

@end


@implementation NSMutableString (Delete)

- (void)deleteLastCharacter {
    [self deleteCharactersInRange:NSMakeRange(self.length-1, 1)];
}

- (void)deleteCharacter:(NSUInteger)idx {
    [self deleteCharactersInRange:NSMakeRange(idx, 1)];
}

@end