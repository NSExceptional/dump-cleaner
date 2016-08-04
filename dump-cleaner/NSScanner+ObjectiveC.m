//
//  NSScanner+ObjectiveC.m
//  dump-cleaner
//
//  Created by Tanner on 7/29/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSScanner+ObjectiveC.h"
#import "NSScanner+Helper.h"
#import "DCProperty.h"
#import "DCVariable.h"
#import "DCClass.h"
#import "DCProtocol.h"
#import "DCMethod.h"


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
    static NSArray *propSelectors = StaticArray(propSelectors, @"getter", @"setter")
    static NSArray *propAttrs = StaticArray(propAttrs, @"nonatomic", @"copy",
                                            @"readonly",@"assign", @"strong",
                                            @"weak", @"retain", @"atomic", @"class")
    
    NSMutableArray *attributes = [NSMutableArray array];
    
    ScanAssert([self scanString:@"@property"]);
    if ([self scanString:@"("]) {
        NSString *attr = nil;
        do {
            // Regular attributes
            if ([self scanAny:propAttrs into:&attr]) {
            } else {
                // getter= / setter= attributes
                ScanAssertPop([self scanAny:propSelectors into:&attr] && [self scanString:@"="]);
                NSString *selector = nil;
                ScanAssertPop([self scanSelector:&selector]);
                attr = [attr stringByAppendingFormat:@"=%@", selector];
            }
            [attributes addObject:attr]; attr = nil;
        } while ([self scanString:@","]);
        
        ScanAssertPop([self scanString:@")"]);
    }
    
    DCVariable *variable = nil;
    ScanAssertPop([self scanVariable:&variable]);
    
    *output = [DCProperty withAttributes:attributes variable:variable];
    return YES;
}

- (BOOL)scanMethod:(DCMethod **)output {
    ScanPush();
    ScanBuilderInit();
    
    NSMutableArray *types = [NSMutableArray array];
    NSMutableArray *argNames = [NSMutableArray array];
    
    // ('-'|'+') '(' [protocol-qualifier]<type>')'
    BOOL isInstanceMethod = [self scanString:@"-"];
    ScanAssertPop(isInstanceMethod || [self scanString:@"+"]);
    
    ScanAssertPop([self scanString:@"("]);
    ScanAppend_(self scanProtocolQualifier);
    ScanAssertPop(ScanAppend(self scanType) && [self scanString:@")"]);
    [types addObject:__scanned.copy];
    
    // Scan builder will hold the selector
    [__scanned setString:@""];
    
    // <identifier>(":("[protocol-qualifier]<type>')'[identifier])*
    BOOL complete = YES;
    ScanAssertPop(ScanAppend(self scanIdentifier));
    while (ScanAppend(self scanString:@":" intoString)) {
        // Scan parameter (protocol qualifier and type)
        NSString *protocolQualifier = nil, *type = nil, *arg = nil;
        ScanAssertPop([self scanString:@"("]);
        [self scanProtocolQualifier:&protocolQualifier];
        ScanAssertPop([self scanType:&type] && [self scanString:@")"]);
        
        // Add to types
        if (protocolQualifier) {
            type = [NSString stringWithFormat:@"%@ %@", protocolQualifier, type];
        }
        [types addObject:type];
        
        // Scan for parameter name and optional selector part
        if ([self scanIdentifier:&arg]) {
            [argNames addObject:arg];
            // Will be NO if something scans, YES if none found.
            // If none found, we might come across another parameter
            // and this might execute again. `complete` is only used
            // when the loop exits because no ':' was found.
            // So we only encounter an error when a second identifier
            // was scanned but no required ':' was found.
            complete = !ScanAppend(self scanIdentifier); // Optional parameter label
        } else {
            complete = YES;
            break;
        }
    }
    
    ScanAssertPop(complete);
    
    [self scanPastClangAttribute];
    ScanAssertPop([self scanString:@";"]);
    
    *output = [DCMethod types:types selector:ScanBuilderString() argumentNames:argNames instance:isInstanceMethod];
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

- (BOOL)scanInterfaceBody:(InterfaceBodyBlock)callback isProtocol:(BOOL)isProtocol {
    ScanPush();
    DCProperty *tmpProp = nil;
    DCMethod *tmpMethod = nil;
    NSMutableArray<DCProperty*> *properties = [NSMutableArray array];
    NSMutableArray<DCMethod*> *methods      = [NSMutableArray array];
    
    BOOL didFind = YES;
    while (didFind) {
        didFind = NO;
        if ([self scanProperty:&tmpProp]) {
            [properties addObject:tmpProp];
            
            tmpProp = nil;
            didFind = YES;
        }
        else if ([self scanMethod:&tmpMethod]) {
            [methods addObject:tmpMethod];
            
            tmpMethod = nil;
            didFind = YES;
        } else {
            // Skip past comments and things like @optional if protocol
            static NSArray *protocolThings = StaticArray(protocolThings, @"@optional", @"@required");
            didFind = isProtocol ? [self scanAny:protocolThings into:nil] : NO || [self scanIgnoredThing];
        }
    }
    
    ScanAssertPop([self scanString:@"@end"]);
    
    callback(properties, methods);
    return YES;
}

- (BOOL)scanProtocolConformanceList:(NSArray<NSString*> **)output {
    ScanAssert([self scanString:@"<"]);
    
    ScanPush();
    NSMutableArray *protocols = [NSMutableArray array];
    NSString *tmp = nil;
    
    do {
        ScanAssertPop([self scanIdentifier:&tmp]);
        [protocols addObject:tmp]; tmp = nil;
    } while ([self scanString:@","]);
    
    ScanAssertPop([self scanString:@">"]);
    
    *output = protocols;
    return YES;
}

- (BOOL)scanInstanceVariableList:(NSArray<DCVariable*> **)output {
    ScanAssert([self scanString:@"{"]);
    
    ScanPush();
    static NSArray *ivarQualifiers = StaticArray(ivarQualifiers, @"@protected", @"@private", @"@public");
    NSMutableArray *ivars = [NSMutableArray array];
    DCVariable *tmp = nil;
    
    while ([self scanAny:ivarQualifiers into:nil] || [self scanVariable:&tmp]) {
        if (tmp) {
            [ivars addObject:tmp];
            tmp = nil;
        }
    }
    
    ScanAssertPop([self scanString:@"}"]);
    
    *output = ivars;
    return YES;
}

- (BOOL)scanSelector:(NSString **)output {
    ScanBuilderInit();
    
    ScanAssert(ScanAppend(self scanIdentifier));
    while (ScanAppend(self scanString:@":" intoString)) {
        ScanAppend(self scanIdentifier);
    }
    
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

- (BOOL)scanGlobalVariale:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAppend_(self scanString:@"extern" intoString);
    ScanAssertPop(ScanAppend_(self scanType));
    ScanAssertPop(ScanAppend(self scanIdentifier));
    [self scanPastClangAttribute];
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    *output = ScanBuilderString();
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
    ScanAssertPop(![self scanToCharacters:self.alphaCharacterSet]);
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
    static NSArray *basicTypes = StaticArray(basicTypes, @"void", @"double", @"float", @"long", @"int", @"short", @"char",
                                             @"NSInteger", @"NSUInteger", @"CGFloat");
    static NSArray *complexTypes = StaticArray(complexTypes, @"struct", @"union");
    
    ScanPush();
    ScanBuilderInit();
    
    // Scan for optional static / const / volatile, then for signed / unsigned
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAppend_(self scanTypeQualifier);
    
    // Then primitive types, then pointers and more consts.
    // Might also scan a (maybe anonymous) struct or union.
    if (ScanAppend_(self scanAny:basicTypes into) || // Basic types
        (ScanAppend_(self scanAny:complexTypes into) && ScanAppend_(self scanIdentifier)) || // "struct _NSRange"
        ScanAppend_(self scanStructOrUnion)) { // Anonymous struct
        ScanAppend(self scanPointers);
        return YES;
    }
    else {
        // Fallback to object types and enums
        BOOL ret = [self scanObjectType:output] || [self scanEnum:output];
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
