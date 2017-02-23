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
static NSString * const kHexChars = @"abcdefABCDEF1234567890";
static NSString * const kVariableAttributesChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_&!|#,";
static NSString * const kNumericOperatorChars = @"&^|<>";


@implementation NSScanner (Helper)

- (NSString *)remainingString {
    NSInteger remaining = self.string.length - self.scanLocation;
    return [self.string substringWithRange:NSMakeRange(self.scanLocation, remaining)];
}

- (NSString *)scannedString {
    return [self.string substringToIndex:self.scanLocation];
}

- (char)nextScannableChar {
    NSCharacterSet *backup = self.charactersToBeSkipped;
    self.charactersToBeSkipped = nil;
    [self scanToCharacters:backup.invertedSet];
    self.charactersToBeSkipped = backup;
    
    if (self.scanLocation == self.string.length) {
        return EOF;
    } else {
        return [self.string characterAtIndex:self.scanLocation];
    }
}

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

- (NSCharacterSet *)hexadecimalCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kHexChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)multilineEscapeCharacterSet {
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\\"];
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

- (BOOL)scanWord:(NSString *)string {
    return [self scanWord:string into:nil];
}

- (BOOL)scanWord:(NSString *)string into:(NSString **)output {
    ScanPush();
    if ([self scanString:string intoString:output] &&
        (self.scanLocation == self.string.length ||
         ![self.variableNameCharacterSet characterIsMember:[self.string characterAtIndex:self.scanLocation]])) {
            return YES;
        }
    
    ScanPop();
    return NO;
}

- (BOOL)scanCharacters:(NSCharacterSet *)characters {
    return [self scanCharactersFromSet:characters intoString:nil];
}

- (BOOL)scanToCharacters:(NSCharacterSet *)characters {
    return [self scanUpToCharactersFromSet:characters intoString:nil];
}

- (BOOL)scanAny:(NSArray<NSString *> *)strings ensureKeyword:(BOOL)keyword into:(NSString **)output {
    if (keyword) {
        for (NSString *string in strings) {
            if ([self scanWord:string into:output]) {
                return YES;
            }
        }
    } else {
        for (NSString *string in strings) {
            if ([self scanString:string intoString:output]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)scanExpression:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // expr = ['('] digit_or_identifier [operator expr]* [')']
    
    // [(] digit_or_identifier
    BOOL needsClosingBrace = [self scanString:@"("];
    ScanAssertPop(ScanAppend(self scanNumberLiteral) || ScanAppend(self scanIdentifier));
    
    // [operator expr]*
    while (ScanAppendFormat(self scanCharactersFromSet:self.numericOperatorsCharacterSet intoString, @" %@ ")) {
        ScanAssertPop(ScanAppend(self scanExpression));
    }
    
    if (needsClosingBrace) {
        ScanAssertPop([self scanString:@")"]);
    }
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanNumberLiteral:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // num ::= (0x digit+) | (digit*['.' digit*][f])
    BOOL hex = ScanAppend(self scanString:@"0x" intoString);
    BOOL isFloat = NO, isChar = NO;
    if (hex) {
        ScanAssertPop(ScanAppend(self scanCharactersFromSet:self.hexadecimalCharacterSet intoString));
        static NSArray *bs = StaticArray(bs, @"b", @"B");
        ScanAppend(self scanAny:bs ensureKeyword:NO into);
    } else {
        // Character literals
        if (ScanAppend(self scanString:@"'" intoString)) {
            isChar = YES;
            ScanAssertPop(ScanAppend(self scanUpToString:@"'" intoString) &&
                          ScanAppend(self scanString:@"'" intoString))
            ScanAssertPop(![__scanned containsString:@"\n"]);
        }
        
        // Decimals
        else {
            ScanAppend(self scanString:@"-" intoString);
            ScanAssertPop(ScanAppend(self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString));
            if (ScanAppend(self scanString:@"." intoString)) {
                ScanAppend(self scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString);
            }
            
            isFloat = ScanAppend(self scanString:@"f" intoString);
        }
        
        if (!isFloat) {
            static NSArray *us = StaticArray(us, @"U", @"u");
            ScanAppend(self scanAny:us ensureKeyword:NO into);
        }
    }
    
    if (!isFloat && !isChar) {
        static NSArray *us = StaticArray(us, @"L", @"l");
        ScanAppend(self scanAny:us ensureKeyword:NO into);
    }
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanToStringOnSameLine:(NSString *)string {
    ScanPush();
    
    NSString *scanned = nil;
    BOOL ret = [self scanUpToString:string intoString:&scanned];
    if ([scanned containsString:@"\n"] || self.scanLocation == self.string.length) {
        ScanPop();
        return NO;
    }
    
    return ret;
}

@end
