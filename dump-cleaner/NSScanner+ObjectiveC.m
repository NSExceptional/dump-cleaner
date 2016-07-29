//
//  NSScanner+ObjectiveC.m
//  dump-cleaner
//
//  Created by Tanner on 7/29/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSScanner+ObjectiveC.h"
#import "DCVariable.h"


static NSString * const kVariableNameChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$";
static NSString * const kVariableStartNameChars = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
static NSString * const kVariableAttributesChars = @"1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_()&!|#,";
static NSString * const kNumericOperatorChars = @"&^|<>";

#define StaticArray(name, ...) nil; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ name = @[__VA_ARGS__]; })

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

- (BOOL)scanString:(NSString *)string;
- (BOOL)scanToString:(NSString *)string;
- (BOOL)scanCharacters:(NSCharacterSet *)characters;
- (BOOL)scanToCharacters:(NSCharacterSet *)characters;
- (BOOL)scanAny:(NSArray<NSString*> *)strings into:(NSString **)output;
- (BOOL)scanExpression:(NSString **)output;

@end

@implementation NSScanner (ObjectiveC)

#pragma mark Objective-C things

- (BOOL)scanInterface:(DCInterface **)output {
    return [self scanClass:(id*)output] || [self scanProtocol:(id*)output];
}

- (BOOL)scanClass:(DCClass **)output {
    return [self scanClassDefinition:output] || [self scanClassCategory:output];
}

- (BOOL)scanClassDefinition:(DCClass **)output {
    ScanPush();
    
    ScanAssert([self scanString:@"@interface"]);
    
    return YES;
}

- (BOOL)scanClassCategory:(DCClass **)output {
    
    return YES;
}

- (BOOL)scanProtocol:(DCProtocol **)output {
 
    return YES;
}

- (BOOL)scanProperty:(DCProperty **)output {
   
    return YES;
}

- (BOOL)scanObjectType:(NSString **)output {
    ScanPush();
    
    BOOL needsPointer = NO;
    NSString *pointers = nil;
    
    // "id" needs no pointer
    if ([self scanString:@"id" intoString:output]) {
    } else if ([self scanIdentifier:output]) {
        needsPointer = YES;
    } else {
        return NO;
    }
    
    // Conformed protocols
    // '<'identifier[, identifier]*'>'
    if ([self scanString:@"<"]) {
        ScanBuilderInit();
        
        do {
            ScanAssertPop(ScanAppendFormat(self scanIdentifier, @"%@, "));
        } while ([self scanString:@","]);
        [__scanned deleteCharactersInRange:NSMakeRange(__scanned.length-1, 1)];
        ScanAssertPop([self scanString:@">"]);
        
        *output = [*output stringByAppendingFormat:@"<%@>", ScanBuilderString()];
    }
    
    // Scan for pointers and return NO if we needed them but did not find them.
    ScanAssertPop([self scanPointers:&pointers] || !needsPointer);
    if (pointers) {
        *output = [*output stringByAppendingFormat:@" %@", pointers];
    }
    
    return YES;
}

#pragma mark C types

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
    [self scanCharacters:self.variableAttributesCharacterSet];
    ScanAssertPop([self scanString:@";"]);
    
    *output = [DCVariable type:ScanBuilderString() name:identifier];
    return YES;
}

// TODO
- (BOOL)scanStructOrUnion:(DCVariable **)output {
    ScanPush();
    ScanBuilderInit();
    
    BOOL needsTypedefName = ScanAppend_(self scanString:@"typedef" intoString);
    if (ScanAppend_(self scanString:@"struct" intoString) || ScanAppend_(self scanString:@"union" intoString)) {
        ScanAppend_(self scanIdentifier);
    }
    
    ScanAssertPop(ScanAppend_(self scanString:@"{" intoString));
    do {
        DCVariable *var = nil;
        [self scanVariable:&var];
        [__scanned appendFormat:@"%@ ", var.string];
    } while (
    
    return YES;
}

- (BOOL)scanEnum:(NSString **)output {
    ScanPush();
    
    ScanBuilderInit();
    // enum ::= [typedef] (enum [identifier]|NS_ENUM'('identifier, identifier')') { types } [typedef-name];
    
    BOOL needsTypedefName = ScanAppend_(self scanString:@"typedef" intoString);
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
    
    // val ::= identifier [= expr][, val]
    do {
        ScanAssertPop(ScanAppend_(self scanIdentifier));
        if (ScanAppend_(self scanString:@"=" intoString)) {
            ScanAssertPop(ScanAppend(self scanExpression));
        }
    } while (ScanAppend_(self scanString:@"," intoString));
    ScanAssertPop(ScanAppend(self scanString:@"}" intoString));
    
    if (needsTypedefName) {
        ScanAssertPop(ScanAppendFormat(self scanIdentifier, @" %@"));
    }
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
    
    // Scan primitive types first
    if ([self scanAny:basicTypes into:output]) {
        NSString *pointers = nil;
        // Check for pointers
        if ([self scanPointers:&pointers]) {
            *output = [*output stringByAppendingFormat:@" %@", pointers];
        }
        return YES;
    }
    else {
        // Fallback to object types and structs
        return [self scanObjectType:output] || [self scanStructOrUnion:output];
    }
}

- (BOOL)scanPointers:(NSString **)output {
    // We scan mutliple times for cases like "** *   *"
    NSMutableString *pointers = [NSMutableString string];
    while ([self scanCharacters:[NSCharacterSet characterSetWithCharactersInString:@"*"]]) {
        [pointers appendString:@"*"];
    }
    
    if (pointers.length) {
        *output = pointers.copy;
        return YES;
    }
    
    return NO;
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
    return [NSCharacterSet letterCharacterSet];
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kVariableAttributesChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)alphaCharacterSet {
    return [NSCharacterSet letterCharacterSet];
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kVariableStartNameChars];
    });
    
    return sharedCharacterSet;
}

- (NSCharacterSet *)numericOperatorsCharacterSet {
    return [NSCharacterSet letterCharacterSet];
    static NSCharacterSet *sharedCharacterSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCharacterSet = [NSCharacterSet characterSetWithCharactersInString:kNumericOperatorChars];
    });
    
    return sharedCharacterSet;
}

- (BOOL)scanString:(NSString *)string {
    return [self scanString:string intoString:nil];
}

- (BOOL)scanToString:(NSString *)string {
    return [self scanUpToString:string intoString:nil];
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

@end
