//
//  NSScanner+Helper.m
//  dump-cleaner
//
//  Created by Tanner on 8/3/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSScanner+Helper.h"

static NSString * const kVariableNameChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$";
static NSString * const kVariableStartNameChars = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
static NSString * const kVariableAttributesChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_()&!|#,";
static NSString * const kNumericOperatorChars = @"&^|<>";


@implementation NSScanner (Helper)

- (NSCharacterSet *)variableNameCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kVariableNameChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)variableAttributesCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kVariableAttributesChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)alphaCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kVariableStartNameChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)numericOperatorsCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kNumericOperatorChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)spaceCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)newlineCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\n"];
    });
    
    return sharedCharacterSet;
}

- (BOOL)scanString:(NSString *)string {
    return [self scanString:string intoString:nil];
}

- (BOOL)scanToString:(NSString *)string {
    ScanPush();
    BOOL ret = [self scanUpToString:string intoString:nil];
    
    // Default behavior is undesirable; we don't want to
    // scan to the end of a string and succeed if the
    // string does not exist when we expect it to.
    if (ret && self.scanLocation == self.string.length) {
        if (![self.string hasSuffix:string]) {
            ScanPop();
            return NO;
        }
    }
    
    return ret;
}

- (BOOL)scanCharacters:(NSCharacterSet *)characters {
    return [self scanCharactersFromSet:characters intoString:nil];
}

- (BOOL)scanToCharacters:(NSCharacterSet *)characters {
    return [self scanUpToCharactersFromSet:characters intoString:nil];
}

- (BOOL)scanAny:(NSArray<NSString *> *)strings into:(NSString **)output {
    for (NSString *string in strings)
        if ([self scanString:string intoString:output]) {
            return YES;
        }
    return NO;
}

- (BOOL)scanExpression:(NSString **)output {
    ScanPush();
    
    NSMutableString *result = [NSMutableString string];
    NSString *tmp = nil;
    
    // expr = [(] digit [operator expr]* [)]
    
    // [(] digit
    BOOL needsClosingBrace = [self scanString:@"("];
    ScanAssertPop([self scanNumberLiteral:&tmp]);
    [result appendString:tmp];
    
    // [operator expr]*
    while ([self scanCharactersFromSet:self.numericOperatorsCharacterSet intoString:&tmp]) {
        [result appendFormat:@" %@ ", tmp];
        ScanAssertPop([self scanExpression:&tmp]);
        [result appendString:tmp];
    }
    
    if (needsClosingBrace) {
        ScanAssertPop([self scanString:@")"]);
    }
    
    *output = result.copy;
    return YES;
}

- (BOOL)scanNumberLiteral:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // num ::= (0x digit+) | (digit*['.' digit*][f])
    BOOL hex = ScanAppend(self scanString:@"0x" intoString);
    ScanAssertPop(ScanAppend(self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString));
    if (!hex) {
        if (ScanAppend(self scanString:@"." intoString)) {
            ScanAppend(self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString);
        }
        ScanAppend(self scanString:@"f" intoString);
    }
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanToStringOnSameLine:(NSString *)string {
    ScanPush();
    
    NSString *scanned = nil;
    BOOL ret = [self scanUpToString:string intoString:&scanned];
    if ([scanned containsString:@"\n"]) {
        ScanPop();
        return NO;
    }
    
    return ret;
}

@end
