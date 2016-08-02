//
//  NSScanner+ObjectiveC.m
//  dump-cleaner
//
//  Created by Tanner on 7/29/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSScanner+ObjectiveC.h"
#import "DCProperty.h"
#import "DCVariable.h"
#import "DCClass.h"
#import "DCProtocol.h"


static NSString * const kVariableNameChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$";
static NSString * const kVariableStartNameChars = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
static NSString * const kVariableAttributesChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_()&!|#,";
static NSString * const kNumericOperatorChars = @"&^|<>";

#define StaticArray(name, ...) nil; { static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ name = @[__VA_ARGS__]; }); }

#define ScanPush() NSInteger start = self.scanLocation
#define ScanPop() self.scanLocation = start
#define ScanAssert(cond) if (!cond) { return NO; }
#define ScanAssertPop(cond) if (!cond) { self.scanLocation = start; return NO; }
#define ScanVariableAssertPop(cond) if (!cond) { self.scanLocation = start; return NO; }

// Helper macros for building a string from multiple scans.
#define ScanBuilderInit() NSMutableString *__scanned = [NSMutableString string]
#define ScanBuilderString() __scanned
#define ScanAppendFormat(scan, format) ({ NSString *__tmp = nil; BOOL r = [scan:&__tmp]; if (r){[__scanned appendFormat:format, __tmp];} r; })
#define ScanAppend(scan) ({ NSString *__tmp = nil; BOOL r = [scan:&__tmp]; if(r){[__scanned appendString:__tmp];} r; })
#define ScanAppend_(scan) ScanAppendFormat(scan, @"%@ ")

#define NSMutableStringOptionalAppend(str, optional) if (optional) { [str appendFormat:@"%@ ", optional]; }

@interface NSScanner (Helper)
@property (nonatomic, readonly) NSCharacterSet *variableNameCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *variableAttributesCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *alphaCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *numericOperatorsCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *spaceCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *newlineCharacterSet;

- (BOOL)scanString:(NSString *)string;
- (BOOL)scanToString:(NSString *)string;
- (BOOL)scanCharacters:(NSCharacterSet *)characters;
- (BOOL)scanToCharacters:(NSCharacterSet *)characters;
- (BOOL)scanAny:(NSArray<NSString*> *)strings into:(NSString **)output;
- (BOOL)scanExpression:(NSString **)output;
- (BOOL)scanNumberLiteral:(NSString **)output;
- (BOOL)scanToStringOnSameLine:(NSString *)string;

@end

@implementation NSScanner (ObjectiveC)

#pragma mark Objective-C things

- (BOOL)scanInterface:(DCInterface **)output {
    ScanPush();
    
    Class cls = Nil;
    if ([self scanString:@"@interface"]) {
        cls = [DCClass class];
    } else if ([self scanString:@"@protocol"]) {
        cls = [DCProtocol class];
    }
    
    if (cls) {
        ScanAssertPop([self scanToString:@"@end"]);
        [self scanString:@"@end"];
        NSString *string = [self.string substringWithRange:NSMakeRange(start, self.scanLocation)];
        DCInterface *interface = [cls withString:string];
        
        if (interface) {
            *output = interface;
            return YES;
        }
    }
    
    ScanPop();
    return NO;
}

- (BOOL)scanProperty:(DCProperty **)output {
    ScanPush();
    ScanBuilderInit();
    
    static NSArray *propAttrs = StaticArray(propAttrs, @"nonatomic", @"copy",
                                            @"readonly",@"assign", @"strong",
                                            @"weak", @"retain", @"atomic", @"class")
    
    ScanAssert(ScanAppend_(self scanString:@"@property" intoString));
    if (ScanAppend(self scanString:@"(" intoString)) {
        do {
            ScanAssertPop(ScanAppend(self scanAny:propAttrs into));
        } while (ScanAppend_(self scanString:@"," intoString));
        
        ScanAssertPop(ScanAppend_(self scanString:@")" intoString));
    }
    
    DCVariable *variable = nil;
    ScanAssertPop([self scanVariable:&variable]);
    
    *output = [DCProperty withString:[ScanBuilderString() stringByAppendingString:variable.string]];
    return YES;
}

- (BOOL)scanMethod:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // ('-'|'+') '(' [protocol-qualifier]<type>')'
    static NSArray *prefixes = StaticArray(prefixes, @"-", @"+");
    ScanAssert(ScanAppend_(self scanAny:prefixes into));
    ScanAssertPop(ScanAppend(self scanString:@"(" intoString))
    ScanAppend_(self scanProtocolQualifier);
    ScanAssertPop(ScanAppend(self scanType) && ScanAppend(self scanString:@")" intoString));
    
    // <identifier>(":("[protocol-qualifier]<type>')'[identifier])*
    BOOL complete = YES;
    ScanAssertPop(ScanAppend(self scanIdentifier));
    while (ScanAppend(self scanString:@":" intoString)) {
        ScanAssertPop(ScanAppend(self scanString:@"(" intoString))
        ScanAppend_(self scanProtocolQualifier);
        ScanAssertPop(ScanAppend(self scanType) && ScanAppend(self scanString:@")" intoString));
        
        // Scan for parameter name and optional selector part
        if (ScanAppend(self scanIdentifier)) {
            // Will be NO if something scans, YES if none found.
            // If none found, we might come across another parameter
            // and this might execute again. `complete` is only used
            // when the loop exits because no ':' was found.
            // So we only encounter an error when a second identifier
            // was scanned but no required ':' was found.
            complete = !ScanAppendFormat(self scanIdentifier, @" %@");
        } else {
            complete = YES;
            break;
        }
    }
    
    ScanAssertPop(complete);
    
    [self scanPastClangAttribute];
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    *output = ScanBuilderString();
    return YES;
}

- (BOOL)scanClassOrProtocolForwardDeclaration:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAssert(ScanAppend_(self scanString:@"@class" intoString) || ScanAppend_(self scanString:@"@protocol" intoString));
    ScanAssertPop(ScanAppend(self scanIdentifier));
    while (ScanAppend(self scanString:@"," intoString)) {
        ScanAssertPop(ScanAppend(self scanIdentifier));
    }
    
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    *output = ScanBuilderString();
    return YES;
}

- (BOOL)scanObjectType:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    BOOL needsPointer = NO;
    
    // "id" needs no pointer
    if (ScanAppend(self scanString:@"id" intoString)) {
    } else if (ScanAppend(self scanIdentifier)) {
        needsPointer = YES;
    } else {
        return NO;
    }
    
    // Conformed protocols
    // '<'identifier[, identifier]*'>'
    if (ScanAppend(self scanString:@"<" intoString)) {
        do {
            ScanAssertPop(ScanAppend(self scanIdentifier));
        } while (ScanAppendFormat(self scanString:@"," intoString, @"%@ "));
        
        // Delete trailing ", "
        [__scanned deleteCharactersInRange:NSMakeRange(__scanned.length-2, 2)];
        ScanAssertPop(ScanAppend(self scanString:@">" intoString));
    }
    
    // Scan for pointers and return NO if we needed them but did not find them.
    // Check for pointers first because we can have more even if we don't need them.
    ScanAssertPop(ScanAppend(self scanPointers) || !needsPointer);
    
    *output = ScanBuilderString();
    return YES;
}

#pragma mark C types

- (BOOL)scanIgnoredThing {
    ScanPush();
    
    // Comments like this
    if ([self scanString:@"//"]) {
        [self scanPastSpecialMultilineCommentOrMacro];
    }
    /* comemnts like this */ /** or this */
    else if ([self scanString:@"/*"]) {
        ScanAssertPop([self scanToString:@"*/"]);
        ScanAssertPop([self scanString:@"*/"]);
    }
    // #if and #elif
    else if (([self scanString:@"#if"] ||
              [self scanString:@"#include"] || [self scanString:@"#import"]) && [self scanToString:@"\n"]) {
    }
    // Skip all #elif's, we're only going to parse the
    // first branch of all preprocessor conditionals for simplicity.
    else if ([self scanString:@"#elif"]) {
        ScanAssertPop([self scanToString:@"#endif"] && [self scanString:@"#endif"]);
    }
    // #defines, might end with \ which could make it carry onto the next line
    else if ([self scanString:@"#define"]) {
        [self scanPastSpecialMultilineCommentOrMacro];
    }
    else if ([self scanString:@"#endif"]) {
        
    } else if ([self scanString:@"@import"]) {
        ScanAssertPop([self scanIdentifier:nil] && [self scanString:@";"]);
    } else {
        NSString *identifier = nil;
        [self scanIdentifier:&identifier];
        return [identifier hasPrefix:@"NS_"]; // Only way I know how to check for valid macros rn
    }
    
    return YES;
}

- (BOOL)scanVariable:(DCVariable **)output {
    ScanPush();
    ScanBuilderInit();
    
    // The memory and type qualifiers are optional,
    // while type and name are not.
    NSString *identifier = nil;
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAppend_(self scanTypeQualifier);
    ScanAssertPop(ScanAppend(self scanType) && [self scanIdentifier:&identifier]);
    
    // Skip past clang attributes and macros to the semicolon
    [self scanPastClangAttribute];
    ScanAssertPop([self scanString:@";"]);
    
    *output = [DCVariable type:ScanBuilderString() name:identifier];
    return YES;
}

- (BOOL)scanTypedefStructUnionOrEnum:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // Struct and union typedefs are assumed to not have a trailing attribute
    ScanAssert(ScanAppend_(self scanString:@"typedef" intoString));
    if (ScanAppend_(self scanStructOrUnion)) {
        ScanAssertPop(ScanAppend(self scanIdentifier));
    } else {
        ScanAssertPop(ScanAppend_(self scanEnum));
        [self scanPastClangAttribute];
    }
    
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    *output = ScanBuilderString();
    return YES;
}

- (BOOL)scanStructOrUnion:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    BOOL isStruct = ScanAppend_(self scanString:@"struct" intoString);
    ScanAssertPop(isStruct || ScanAppend_(self scanString:@"union" intoString));
    ScanAppend_(self scanIdentifier);
    
    ScanAssertPop(ScanAppend_(self scanString:@"{" intoString));
    do {
        DCVariable *var = nil;
        if ([self scanVariable:&var]) {
            [__scanned appendFormat:@"\n\t%@", var.string];
        } else {
            ScanAssertPop(!isStruct || ScanAppendFormat(self scanBitfield, @"\n\t%@"));
        }
    } while (!ScanAppendFormat(self scanString:@"}" intoString, @"\n%@"));
    
    *output = ScanBuilderString();
    return YES;
}

- (BOOL)scanEnum:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    // enum ::= [typedef] (enum [identifier]|NS_ENUM'('identifier, identifier')') { types } [attr];
    
    if (ScanAppend_(self scanString:@"enum" intoString)) {
        ScanAppend_(self scanIdentifier);
    }
    else if (ScanAppend(self scanString:@"NS_ENUM" intoString)) {
        // '('type, name')'
        ScanAssertPop(ScanAppend(self scanString:@"(" intoString) && ScanAppend(self scanIdentifier) &&
                      ScanAppend_(self scanString:@"," intoString) && ScanAppend(self scanIdentifier) &&
                      ScanAppend_(self scanString:@")" intoString));
    }
    
    ScanAssertPop(ScanAppend_(self scanString:@"{" intoString));
    
    // val ::= identifier [attr][= expr][, val]
    do {
        ScanAssertPop(ScanAppend_(self scanIdentifier));
        [self scanPastClangAttribute];
        if (ScanAppend_(self scanString:@"=" intoString)) {
            ScanAssertPop(ScanAppend(self scanExpression));
        }
    } while (ScanAppend_(self scanString:@"," intoString));
    ScanAssertPop(ScanAppend(self scanString:@"}" intoString));
    
    *output = ScanBuilderString();
    return YES;
}

- (BOOL)scanBitfield:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // The memory and type qualifiers are optional,
    // while type and name are not.
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAppend_(self scanTypeQualifier);
    ScanAssertPop(ScanAppend_(self scanType) && ScanAppend_(self scanString:@":" intoString) && ScanAppend(self scanIdentifier));
    
    // Skip past clang attributes and macros to the semicolon
    [self scanCharacters:self.variableAttributesCharacterSet];
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    *output = ScanBuilderString();
    return YES;
}

#pragma mark Basics

- (BOOL)scanIdentifier:(NSString **)output {
    ScanPush();
    
    // Scan past whitespace, fail if scanned other than whitespace (ie digit)
    ScanAssertPop(![self scanUpToCharactersFromSet:self.alphaCharacterSet intoString:nil]);
    return [self scanCharactersFromSet:self.variableNameCharacterSet intoString:output];
}

- (BOOL)scanTypeMemoryQualifier:(NSString **)output {
    static NSArray *qualifiers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        qualifiers = @[@"const", @"volatile", @"static"];
    });
    
    return [self scanAny:qualifiers into:output];
}

- (BOOL)scanTypeQualifier:(NSString **)output {
    static NSArray *qualifiers = StaticArray(qualifiers, @"signed", @"unsigned", @"long");
    return [self scanAny:qualifiers into:output];
}

- (BOOL)scanProtocolQualifier:(NSString **)output {
    static NSArray *qualifiers = StaticArray(qualifiers, @"in", @"out", @"inout", @"bycopy", @"byref", @"oneway");
    return [self scanAny:qualifiers into:output];
}

- (BOOL)scanType:(NSString **)output {
    static NSArray *basicTypes = StaticArray(basicTypes, @"void", @"double", @"float", @"long", @"int", @"short", @"char");
    
    ScanPush();
    ScanBuilderInit();
    
    // Scan for optional const / volatile, then for signed / unsigned
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAppend_(self scanTypeQualifier);
    
    // Then primitive types, then pointers and more consts
    if (ScanAppend_(self scanAny:basicTypes into)) {
        ScanAppend(self scanPointers);
        return YES;
    }
    else {
        // Fallback to object types and structs
        BOOL ret = [self scanObjectType:output] || [self scanStructOrUnion:output] || [self scanEnum:output];
        if (!ret) {
            ScanPop();
        }
        
        return ret;
    }
}

- (BOOL)scanPointers:(NSString **)output {
    ScanBuilderInit();
    
    // We scan mutliple times for cases like "** * const * *"
    BOOL hasMemoryQualifier = NO;
    while (ScanAppend(self scanString:@"*" intoString) || (!hasMemoryQualifier && ScanAppend_(self scanTypeMemoryQualifier))) {}
    
    if (__scanned.length) {
        *output = ScanBuilderString();
        return YES;
    }
    
    return NO;
}

- (BOOL)scanPastSpecialMultilineCommentOrMacro {
    // Carefully scan to the next '\' on the same line, and if
    // it is not followed by '\n', keep checking for that. Then
    // finally check for just a newline.
    while ([self scanToStringOnSameLine:@"\\"]) {
        if ([self scanString:@"\\"] && [self scanString:@"\n"]) {
            break;
        }
    }
    [self scanString:@"\n"];
    
    return YES;
}

- (BOOL)scanPastClangAttribute {
    ScanPush();
    [self scanCharacters:self.variableAttributesCharacterSet];
    if ([self scanString:@"\""]) {
        ScanAssertPop([self scanToStringOnSameLine:@"\""] && [self scanString:@")"]);
    }
    
    return YES;
}

@end


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
    
    *output = ScanBuilderString();
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
