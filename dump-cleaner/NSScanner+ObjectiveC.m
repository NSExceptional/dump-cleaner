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


static NSInteger kHeaderIterationCount = 0;
static NSInteger kScanInterfaceIterationCount = 0;

@implementation NSScanner (ObjectiveC)

static NSMutableDictionary<NSString*, DCProtocol*> *SDKProtocols;
static NSMutableDictionary<NSString*, DCProtocol*> *dumpedProtocols;
+ (void)setExistingProtocolPools:(NSMutableDictionary<NSString *,DCProtocol *> *)SDKs
                          dumped:(NSMutableDictionary<NSString *,DCProtocol *> *)dumped {
    NSParameterAssert(SDKs); NSParameterAssert(dumped);
    SDKProtocols    = SDKs;
    dumpedProtocols = dumped;
}

#pragma mark Objective-C things

- (BOOL)parseHeader:(ParseCallbackBlock)completion {
    NSParameterAssert(self.string.length); NSParameterAssert(completion);
    
    NSMutableArray *interfaces  = [NSMutableArray array];
    NSMutableArray *structNames = [NSMutableArray array];
    DCInterface *tmp  = nil;
    NSString *structt = nil;
    BOOL didRunOnce   = NO;
    
    //    kHeaderIterationCount = 0;
    
    // Scan past comments and other crap, look for interfaces and struct/union declarations
    // Skip untypedef'd structs and unions, skip all enums and forward declarations,
    // skip all global variables.
    while ([self scanPastIgnoredThing] ||
           [self scanClassOrProtocolForwardDeclaration:nil] ||
           [self scanInterface:&tmp] ||
           [self scanTypedefStructUnionOrEnum:&structt] ||
           [self scanAnyTypedef:nil] ||
           [self scanGlobalVariale:nil] ||
           ([self scanStructOrUnion:nil] && [self scanString:@";"]) ||
           ([self scanEnum:nil] && ([self scanString:@";"] || ([self scanPastClangAttribute] && [self scanString:@";"]))) ||
           ([self scanNS_CF_ENUM:nil] && ([self scanString:@";"] || ([self scanPastClangAttribute] && [self scanString:@";"]))) ||
           [self scanCFunction:nil]) {
        
        didRunOnce = YES;
        
        while ([self scanPastIgnoredThing]) { }
        kHeaderIterationCount++;
        
        if (tmp) {
            [interfaces addObject:tmp];
            tmp = nil;
        }
        if (structt) {
            NSMutableString *name = structt.mutableCopy;
            structt = nil;
            [name replaceOccurrencesOfString:@"typedef " withString:@"" options:0 range:NSMakeRange(0, name.length)];
            if ([name hasPrefix:@"struct"]) {
                [name deleteLastCharacter];
                [structNames addObject:[name componentsSeparatedByString:@" "].lastObject];
            }
        }
        if (self.scanLocation == self.string.length) {
            break;
        }
    }
    
    if (didRunOnce && self.scanLocation == self.string.length) {
        completion(interfaces, structNames);
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)scanInterface:(DCInterface **)output {
    ScanPush();
    
    [self scanPastClangAttribute];
    NSInteger afterAttr = self.scanLocation;
    
    Class cls = Nil;
    if ([self scanString:@"@interface"]) {
        cls = [DCClass class];
    } else if ([self scanString:@"@protocol"]) {
        cls = [DCProtocol class];
        
        // Check whether or not we need to skip
        // this protocol entirely.
        NSString *name = nil;
        [self scanIdentifier:&name];
        if ([SDKProtocols.allKeys containsObject:name] ||
            [dumpedProtocols.allKeys containsObject:name]) {
            ScanAssertPop([self scanToString:@"@end"]);
            return YES;
        }
    }
    
    if (cls) {
        ScanAssertPop([self scanToString:@"@end"]);
        [self scanString:@"@end"];
        DCInterface *interface = [cls withString:[self.scannedString substringFromIndex:afterAttr]];
        
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
                                            @"readonly", @"assign", @"strong",
                                            @"weak", @"retain", @"atomic", @"class",
                                            @"nullable", @"nonnull", @"null_resettable", @"readwrite",
                                            @"NS_NONATOMIC_IOSONLY", @"NS_NONATOMIC_IPHONEONLY")
    NSMutableArray *attributes = [NSMutableArray array];
    
    ScanAssert([self scanString:@"@property"]);
    if ([self scanString:@"("]) {
        NSString *attr = nil;
        do {
            // Regular attributes
            if ([self scanAny:propAttrs ensureKeyword:YES into:&attr]) {
                [attributes addObject:attr]; attr = nil;
            } else if ([self scanAny:propSelectors ensureKeyword:YES into:&attr]) {
                // getter= / setter= attributes
                ScanAssertPop([self scanString:@"="]);
                NSString *selector = nil;
                ScanAssertPop([self scanSelector:&selector]);
                attr = [attr stringByAppendingFormat:@"=%@", selector];
                [attributes addObject:attr]; attr = nil;
            } else {
                // @property () Foo bar;
                break;
            }
        } while ([self scanString:@","]);
        
        ScanAssertPop([self scanString:@")"]);
        if ([self scanString:@"__attribute__("]) {
            ScanAssertPop([self scanPastClosingParenthese:nil]);
        }
    }
    
    DCVariable *variable = nil;
    if (![self scanVariable:&variable]) {
        // Block properties are special cases
        NSString *type = nil, *name = nil;
        ScanAssertPop([self scanBlockPropertyVariable:&type name:&name]);
        variable = [DCVariable type:type name:name];
    }
    
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
    if (!isInstanceMethod && ![self scanString:@"+"]) {
        // Edge case... stupid freaking unnecessary macro
        ScanAssertPop([self scanString:@"AV_INIT_UNAVAILABLE"]);
        if (output) {
            *output = [DCMethod types:@[@"instancetype"] selector:@"init" argumentNames:@[] instance:YES];
        }
        return YES;
    }
    
    ScanAssertPop([self scanString:@"("]);
    ScanAppend_(self scanReturnTypeQualifier);
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAssertPop((ScanAppend(self scanString:@"instancetype" intoString) || // Just an optimization
                   ScanAppend(self scanBlockMethodParameter) || // order does not matter for these 3
                   ScanAppend(self scanType)) && [self scanString:@")"]);
    
    [types addObject:__scanned.copy];
    
    // Scan builder will hold the selector
    [__scanned setString:@""];
    
    // <identifier>(":("[protocol-qualifier]<type>')'[identifier])*
    BOOL complete = YES;
    ScanAssertPop(ScanAppend(self scanIdentifier));
    while (ScanAppend(self scanString:@":" intoString)) {
        // Scan parameter (protocol qualifier and type)
        NSString *returnTypeQualifier = nil, *type = nil, *arg = nil;
        ScanAssertPop([self scanString:@"("]);
        [self scanTypeMemoryQualifier:&returnTypeQualifier];
        // Order matters here
        ScanAssertPop(([self scanBlockMethodParameter:&type] || [self scanType:&type]) &&
                      [self scanString:@")"]);
        
        // Add to types
        if (returnTypeQualifier) {
            type = [NSString stringWithFormat:@"%@ %@", returnTypeQualifier, type];
        }
        [types addObject:type];
        
        // Scan for parameter name and optional selector part
        if ([self scanIdentifier:&arg]) {
            [argNames addObject:arg];
            
            // For cases like
            // - (void)foo:(int)bar NS_ATTRIBUTE;
            NSInteger undo = self.scanLocation;
            if ([self scanPastClangAttribute] && self.nextScannableChar == ';') {
                // I am assuming `complete` will always be YES here
                complete = YES;
                break;
            } else {
                self.scanLocation = undo;
            }
            
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
    
    if (output) {
        *output = [DCMethod types:types selector:__scanned argumentNames:argNames instance:isInstanceMethod];
    }
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
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanObjectType:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAssertPop(ScanAppend(self scanWord:@"id" into) || ScanAppend(self scanIdentifier))
    
    // Conformed protocols or generics
    // '<'identifier[, identifier]*'>'
    if (ScanAppend(self scanString:@"<" intoString)) {
        ScanAssertPop(ScanAppend(self scanPastClosingAngleBracket));
    }
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanInterfaceBody:(InterfaceBodyBlock)callback isProtocol:(BOOL)isProtocol {
    ScanPush();
    DCProperty *tmpProp = nil;
    DCMethod *tmpMethod = nil;
    NSMutableArray<DCProperty*> *properties = [NSMutableArray array];
    NSMutableArray<DCMethod*> *methods      = [NSMutableArray array];
    
    kScanInterfaceIterationCount = 0;
    
    BOOL didFind = YES;
    while (didFind) {
        didFind = NO;
        kScanInterfaceIterationCount++;
        
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
            didFind = (isProtocol ? [self scanAny:protocolThings ensureKeyword:YES into:nil] : NO);
            didFind = (didFind || [self scanPastIgnoredThing] || [self scanAnyTypedef:nil] ||
                       [self scanGlobalVariale:nil] || [self scanString:@";"]);
        }
    }
    
    ScanAssertPop([self scanString:@"@end"]);
    kScanInterfaceIterationCount = 0;
    callback(properties, methods);
    return YES;
}

- (BOOL)scanProtocolConformanceList:(NSArray<NSString*> **)output {
    if (![self scanString:@"<"]) {
        // god dammit apple
        ScanAssert([self scanString:@"AVAudioUnitMIDIInstrument_MixingConformance"]);
        if (output) {
            *output = @[@"AVAudioMixing"];
            return YES;
        }
    }
    
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

static NSUInteger kScanIvarsCount = 0;

- (BOOL)scanInstanceVariableList:(NSArray<DCVariable*> **)output {
    ScanPush();
    ScanAssert([self scanString:@"{"]);
    
    static NSArray *ivarQualifiers = StaticArray(ivarQualifiers, @"@protected", @"@private", @"@public", @"@package");
    NSMutableArray *ivars = [NSMutableArray array];
    DCVariable *tmp = nil;
    
    kScanIvarsCount = 0;
    
    while ([self scanAny:ivarQualifiers ensureKeyword:YES into:nil] ||
           [self scanVariable:&tmp]) {
        kScanIvarsCount++;
        if (tmp) {
            [ivars addObject:tmp];
            tmp = nil;
        }
    }
    
    ScanAssertPop([self scanString:@"}"]);
    kScanIvarsCount = 0;
    
    *output = ivars;
    return YES;
}

- (BOOL)scanSelector:(NSString **)output {
    ScanBuilderInit();
    
    ScanAssert(ScanAppend(self scanIdentifier));
    while (ScanAppend(self scanString:@":" intoString)) {
        ScanAppend(self scanIdentifier);
    }
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanAnyTypedef:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAssert(ScanAppend(self scanString:@"typedef" intoString));
    // Dangerous but fuck it I didn't feel like
    // writing a function pointer parser
    ScanAssertPop([self scanToString:@";"] &&
                  ScanAppend(self scanString:@";" intoString));
    
    ScanBuilderWrite(output);
    return YES;
}

/// Starts scanning at "typedef" and scans to ";"
- (BOOL)scanBlockTypedef:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    static NSArray *nullabilities = StaticArray(nullabilities, @"__nullable", @"__nonnull");
    
    // block ::= typedef <return-type>"(^"<identifier>")("[parameters]");"
    ScanAssert(ScanAppend_(self scanWord:@"typedef" into));
    ScanAssertPop(ScanAppend(self scanType) &&
                  ScanAppend(self scanString:@"(" intoString) &&
                  ScanAppend(self scanString:@"^" intoString) &&
                  ScanAppend(self scanPastClosingParenthese) &&
                  ScanAppend(self scanFunctionParameterList));
    
    [self scanPastClangAttribute];
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    ScanBuilderWrite(output);
    return YES;
}

/// returnType (^nullability)(parameterTypes) after the :( thing
- (BOOL)scanBlockMethodParameter:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    static NSArray *nullability = StaticArray(nullability, @"nullable", @"nonnull");
    // <returnType> "(^"[nullability]")("[parameterTypes]")"
    
    ScanAssertPop(ScanAppend(self scanType) &&
                  ScanAppend(self scanString:@"(" intoString) &&
                  ScanAppend(self scanString:@"^" intoString) &&
                  ScanAppend(self scanPastClosingParenthese) &&
                  ScanAppend(self scanFunctionParameterList));
    
    ScanBuilderWrite(output);
    return YES;
}

/// Scans returnType (^blockName)(parameterTypes) after the property attributes
- (BOOL)scanBlockPropertyVariable:(NSString **)type name:(NSString **)name {
    ScanPush();
    ScanBuilderInit();
    
    // Will probably work for 99% of cases
    ScanAssert([self scanType:type]);
    
    ScanAssertPop(ScanAppend(self scanString:@"(" intoString) &&
                  ScanAppend(self scanString:@"^" intoString) &&
                  ScanAppend(self scanPastClosingParenthese) &&
                  ScanAppend(self scanFunctionParameterList));
    
    ScanBuilderWrite(name);
    return YES;
}

#pragma mark C types

- (BOOL)scanPastIgnoredThing {
    ScanPush();
    
    static NSArray *skippableMacros = StaticArray(skippableMacros, @"NS_ASSUME_NONNULL_BEGIN", @"NS_ASSUME_NONNULL_END",
                                                  @"CF_ASSUME_NONNULL_BEGIN", @"CF_ASSUME_NONNULL_END",
                                                  @"CF_EXTERN_C_BEGIN", @"CF_EXTERN_C_END");
    static NSArray *skippablePP   = StaticArray(skippablePP, @"#if", @"#include", @"#import",
                                                @"#ifndef", @"#ifdef", @"#pragma", @"#warning");
    
    // Comments, nullability macros
    if ([self scanPastComment] ||
        [self scanAny:skippableMacros ensureKeyword:YES into:nil]) {
    }
    
    // Brace yourselves. This code gets pretty narly. //
    
    // Ignoring these if's because they usually follow
    // with something difficult to handle, like `extern "C" {`
    else if ([self scanString:@"#if defined(__cplusplus)"] ||
             [self scanString:@"#ifdef __cplusplus"]) {
        //        NSInteger backup = self.scanLocation;
        // Not gonna worry about an elif or else for now
        //        if ([self scanUpToString:@"#else" intoString:&tmp]) {
        //            // If the first branch we scanned doesn't have an else, back up.
        //            if ([tmp containsString:@"#if"] && ![tmp containsString:@"#endif"]) {
        //                self.scanLocation = backup;
        //                ScanAssertPop([self scanToString:@"#endif"] &&
        //                              [self scanString:@"#endif"]);
        //            } else {
        //                ScanAssertPop([self scanString:@"#else"])
        //            }
        //        } else {
        [self scanPastClosingEndIfDirective];
        //        }
    }
    // Things we can simply skip to a new line for
    else if ([self scanAny:skippablePP ensureKeyword:YES into:nil]) {
        // If we can't scan to a newline that
        // means we're at the end of the file.
        if (![self scanToString:@"\n"] && [self.string characterAtIndex:self.scanLocation] != '\n') {
            self.scanLocation = self.string.length;
        }
    }
    // Skip all #elif's, we're only going to parse the
    // first branch of all preprocessor conditionals for simplicity.
    else if ([self scanString:@"#elif"] || [self scanString:@"#else"]) {
        [self scanPastClosingEndIfDirective];
    }
    // #defines, might end with \ which could make it carry onto the next line
    else if ([self scanString:@"#define"]) {
        [self scanPastSpecialMultilineCommentOrMacro];
    }
    else if ([self scanString:@"#endif"]) {
        
    } else if ([self scanString:@"@import"]) {
        ScanAssertPop([self scanIdentifier:nil] && [self scanString:@";"]);
    } else {
        return NO;
    }
    
    return YES;
}

- (BOOL)scanPastComment {
    // Comments like this
    if ([self scanString:@"//"]) {
        [self scanPastSpecialMultilineCommentOrMacro];
        return YES;
    }
    /* comemnts like this */ /** or this */
    else {
        return [self scanPastInlineComment];
    }
}

- (BOOL)scanPastInlineComment {
    ScanPush();
    if ([self scanString:@"/*"]) {
        ScanAssertPop([self scanToString:@"*/"]);
        ScanAssertPop([self scanString:@"*/"]);
        return YES;
    }
    
    return NO;
}

- (BOOL)scanVariable:(DCVariable **)output {
    ScanPush();
    ScanBuilderInit();
    
    // The memory and type qualifiers are optional,
    // while type and name are not.
    NSString *type = nil;
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAssertPop([self scanType:&type] && ScanAppend(self scanIdentifier));
    
    // Static arrays
    if (ScanAppend(self scanString:@"[" intoString)) {
        ScanAssertPop((ScanAppend(self scanNumberLiteral) || ScanAppend(self scanIdentifier)) &&
                      ScanAppend(self scanString:@"]" intoString));
    }
    
    // Skip past clang attributes and macros to the semicolon
    [self scanPastClangAttribute];
    ScanAssertPop([self scanString:@";"]);
    
    if (output) {
        *output = [DCVariable type:type name:__scanned];
    }
    return YES;
}

- (BOOL)scanFunctionParameter:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAssertPop(ScanAppend_(self scanType));
    // Function parameters are optional
    ScanAppend(self scanIdentifier);
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanFunctionParameterList:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAssertPop(ScanAppend(self scanString:@"(" intoString) &&
                  ScanAppend(self scanPastClosingParenthese));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanCFunction:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    static NSArray *qualifiers = StaticArray(qualifiers, @"extern", @"inline");
    
    // Case like AB_EXTERN int ABGetFoo();
    if (ScanAppend_(self scanIdentifier) &&
        (![__scanned hasSuffix:@"_EXTERN "] &&
         ![__scanned hasSuffix:@"_EXPORT "] &&
         ![__scanned hasSuffix:@"_INLINE "])) {
            ScanPop();
            [__scanned setString:@""];
        }
    
    ScanAppend_(self scanWord:@"static" into);
    ScanAppend_(self scanAny:qualifiers ensureKeyword:YES into);
    ScanAppend_(self scanAny:qualifiers ensureKeyword:YES into);
    
    ScanAppend_(self scanTypeMemoryQualifier);
    
    // Function type cannot start with typedef;
    // workaround for preceedence over other stuff
    NSString *type = nil;
    if ([self scanType:&type] && [type isEqualToString:@"typedef"]) {
        ScanPop();
        return NO;
    } else {
        ScanAssertPop(type);
        [__scanned appendString:type];
    }
    
    // Signature and parameters
    ScanAssertPop(ScanAppend(self scanIdentifier) &&
                  ScanAppend(self scanFunctionParameterList));
    
    // Some can be inline, some can be prototypes
    if (ScanAppendFormat(self scanString:@"{" intoString, @"%@\n")) {
        ScanAssertPop(ScanAppend(self scanPastClosingBracket));
    } else {
        [self scanPastClangAttribute];
        ScanAppend(self scanString:@";" intoString);
    }
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanGlobalVariale:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    // Case like AB_EXTERN NSString *const ABFoo;
    if (ScanAppend_(self scanIdentifier) &&
        (![__scanned hasSuffix:@"_EXTERN "] &&
         ![__scanned hasSuffix:@"_EXPORT "])) {
            ScanPop();
            [__scanned setString:@""];
        }
    
    static NSArray *globalQualifiers = StaticArray(globalQualifiers, @"static", @"extern");
    ScanAppend_(self scanAny:globalQualifiers ensureKeyword:YES into);
    ScanAppend_(self scanAny:globalQualifiers ensureKeyword:YES into);
    
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAssertPop(ScanAppend_(self scanType) &&
                  ScanAppend(self scanIdentifier));
    
    if (ScanAppendFormat(self scanString:@"=" intoString, @" %@ ")) {
        ScanAssertPop(ScanAppend(self scanUpToString:@";" intoString));
    } else {
        [self scanPastInlineComment];
        [self scanPastClangAttribute];
    }
    
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanTypedefStructUnionOrEnum:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    static NSArray *types = StaticArray(types, @"struct", @"union");
    
    // Struct and union typedefs are assumed to not have a trailing attribute
    ScanAssert(ScanAppend_(self scanWord:@"typedef" into));
    
    // typedef struct Foo { ... } Foo NS_ATTR();
    if (ScanAppend_(self scanStructOrUnion)) {
        ScanAssertPop(ScanAppend(self scanIdentifier));
    }
    // typedef struct Foo Bar;
    else if (ScanAppend_(self scanAny:types ensureKeyword:YES into)) {
        ScanAssertPop(ScanAppend_(self scanIdentifier) && ScanAppend(self scanIdentifier));
    }
    else if (ScanAppend_(self scanEnum)) {
        ScanAssertPop(ScanAppend(self scanIdentifier));
    } else {
        ScanAssertPop(ScanAppend_(self scanNS_CF_ENUM));
    }
    
    [self scanPastClangAttribute];
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanStructOrUnion:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    BOOL isStruct = ScanAppend_(self scanWord:@"struct" into);
    ScanAssertPop(isStruct || ScanAppend_(self scanWord:@"union" into));
    ScanAppend_(self scanIdentifier);
    
    // case like
    // struct Foo;
    if (self.nextScannableChar == ';') {
        ScanBuilderWrite(output);
        return YES;
    }
    
    ScanAssertPop(ScanAppend_(self scanString:@"{" intoString) &&
                  ScanAppend(self scanPastClosingBracket));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanEnum:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAssert(ScanAppend_(self scanWord:@"enum" into));
    // Did this because I didn't feel like accounting for
    // the various enum syntaxes.
    // enum Foo {
    // enum : Type {
    [self scanToString:@"{"];
    ScanAssertPop(ScanAppend(self scanEnumBody));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanNS_CF_ENUM:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    static NSArray *enumTypes = StaticArray(enumTypes, @"NS_ENUM", @"CF_ENUM");
    
    // enum ::= [typedef] XX_ENUM'('identifier, identifier')') { types }
    
    ScanAssertPop(ScanAppend(self scanAny:enumTypes ensureKeyword:YES into));
    // '('type, name')'
    ScanAssertPop(ScanAppend(self scanString:@"(" intoString) &&
                  ScanAppend_(self scanPastClosingParenthese) &&
                  ScanAppend(self scanEnumBody));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanEnumBody:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAssertPop(ScanAppend_(self scanString:@"{" intoString) &&
                  ScanAppend(self scanPastClosingBracket));
    
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanBitfield:(NSString **)output {
    ScanPush();
    ScanBuilderInit();
    
    ScanAppend_(self scanTypeMemoryQualifier);
    ScanAssertPop(ScanAppend_(self scanType) && ScanAppend_(self scanString:@":" intoString) && ScanAppend(self scanIdentifier));
    
    // Skip past clang attributes and macros to the semicolon
    [self scanCharacters:self.variableAttributesCharacterSet];
    ScanAssertPop(ScanAppend(self scanString:@";" intoString));
    
    ScanBuilderWrite(output);
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
    static NSArray *qualifiers = StaticArray(qualifiers, @"const", @"volatile", @"static",
                                             @"__autoreleasing", @"nonnull", @"nullable",
                                             @"__strong", @"__weak", @"__kindof");
    ScanBuilderInit();
    
    if (ScanAppend(self scanAny:qualifiers ensureKeyword:YES into)) {
        ScanAppendFormat(self scanAny:qualifiers ensureKeyword:YES into, @" %@");
        ScanAppendFormat(self scanAny:qualifiers ensureKeyword:YES into, @" %@");
        ScanAppendFormat(self scanAny:qualifiers ensureKeyword:YES into, @" %@");
        
        ScanBuilderWrite(output);
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)scanTypeQualifier:(NSString **)output {
    static NSArray *qualifiers = StaticArray(qualifiers, @"signed", @"unsigned", @"long");
    return [self scanAny:qualifiers ensureKeyword:YES into:output];
}

- (BOOL)scanReturnTypeQualifier:(NSString **)output {
    static NSArray *qualifiers = StaticArray(qualifiers, @"in", @"out", @"inout", @"bycopy", @"byref", @"oneway");
    return [self scanAny:qualifiers ensureKeyword:YES into:output];
}

- (BOOL)scanType:(NSString **)output {
    static NSArray *basicTypes = StaticArray(basicTypes, @"void", @"BOOL", @"double", @"float", @"long", @"int", @"short", @"char",
                                             @"NSInteger", @"NSUInteger", @"CGFloat", @"NSComparisonResult", @"NSTimeInterval",
                                             @"NSHashTableOptions", @"NSMapTableOptions", @"NSStringEncoding", @"bool");
    static NSArray *complexTypes = StaticArray(complexTypes, @"struct", @"union");
    
    ScanPush();
    ScanBuilderInit();
    
    ScanAppend_(self scanTypeQualifier);
    
    // Then primitive types, then pointers and more consts.
    // Might also scan a (maybe anonymous) struct or union.
    if (ScanAppend(self scanWord:@"long" into)) { // extra "long"
        ScanAppendFormat(self scanAny:basicTypes ensureKeyword:YES into, @" %@"); // Basic types
    }
    else if (ScanAppend(self scanAny:basicTypes ensureKeyword:YES into) || ScanAppend(self scanStructOrUnion) ||  // C type or anon struct
             (ScanAppend_(self scanAny:complexTypes ensureKeyword:YES into) && ScanAppend(self scanIdentifier))) // "struct _NSRange"
    {
    }
    else {
        // Fallback to object types and enums
        ScanPop();
        [__scanned setString:@""];
        BOOL ret = ScanAppend(self scanObjectType) || ScanAppend(self scanEnum);
        if (!ret) {
            ScanPop();
            return NO;
        }
    }
    
    // This only concerns the first two cases //
    
    ScanAppendFormat(self scanPointers, @" %@");
    ScanBuilderWrite(output);
    return YES;
}

- (BOOL)scanPointers:(NSString **)output {
    ScanBuilderInit();
    
    static NSArray *qualifiers = StaticArray(qualifiers, @"const", @"__nullable", @"__nonnull", @"__autoreleasing")
    // We scan mutliple times for cases like "** * const * *"
    while (ScanAppend(self scanString:@"*" intoString) ||
           ScanAppend_(self scanAny:qualifiers ensureKeyword:YES into)) { }
    
    if (__scanned.length) {
        if ([__scanned hasSuffix:@" "]) {
            [__scanned deleteLastCharacter];
        }
        ScanBuilderWrite(output);
        return YES;
    }
    
    return NO;
}

- (BOOL)scanPastSpecialMultilineCommentOrMacro {
    NSCharacterSet *backup = self.charactersToBeSkipped;
    self.charactersToBeSkipped = [NSCharacterSet whitespaceCharacterSet];
    
    // Carefully scan to the next '\' on the same line, and if
    // it is not followed by '\n', keep checking for that. Then
    // finally check for just a newline.
    BOOL found = NO;
    while ([self scanToStringOnSameLine:@"\\"]) {
        [self scanString:@"\\"];
        found = YES;
    }
    
    // If we find a \ followed by an \n,
    if (found && [self scanString:@"\n"]) {
        // try again. If we don't find another,
        if (![self scanPastSpecialMultilineCommentOrMacro]) {
            // Scan past the comment or macro itself.
            // And if we can't find a new line...
            if (![self scanToString:@"\n"] && [self.string characterAtIndex:self.scanLocation] != '\n') {
                // Then we should just go to the end of the file.
                self.scanLocation = self.string.length;
            }
        }
    } else {
        // If we don't, scan to the end of the line or file.
        if (![self scanToString:@"\n"] && [self.string characterAtIndex:self.scanLocation] != '\n') {
            self.scanLocation = self.string.length;
        }
    }
    
    self.charactersToBeSkipped = backup;
    return YES;
}

- (BOOL)scanPastClangAttribute {
    ScanPush();
    
    // Macros must start with letters
    ScanAssertPop([self scanIdentifier:nil]);
    
    // Scan to closing brace if it takes parameters
    if ([self scanString:@"("]) {
        [self scanPastClosingParenthese:nil];
    }
    
    // god dammit a;ldskjfpirhofdsv;dm
    // sometimes TWO attributes are present.
    // attributes will always be followed
    // by any of these characters
    char next = self.nextScannableChar;
    if ((next != ';' && next != '@' && next != ',' && next != '=') &&
        ![self scanPastClangAttribute] && ![self scanPastComment]) {
        ScanPop();
        return NO;
    }
    
    return YES;
}

- (BOOL)scanPastClosingTag:(char)closing opening:(char)opening output:(NSString **)output {
    NSInteger c = 1;
    NSInteger i;
    for (i = self.scanLocation; c > 0 && i < self.string.length; i++) {
        char ch = [self.string characterAtIndex:i];
        if (ch == opening) {
            c++;
        } else if (ch == closing) {
            c--;
        }
    }
    
    if (c > 0) {
        return NO;
    }
    
    if (output) {
        *output = [self.string substringWithRange:NSMakeRange(self.scanLocation, i - self.scanLocation)];
    }
    self.scanLocation = i;
    return YES;
}

- (BOOL)scanPastClosingParenthese:(NSString **)output {
    return [self scanPastClosingTag:')' opening:'(' output:output];
}

- (BOOL)scanPastClosingBracket:(NSString **)output {
    return [self scanPastClosingTag:'}' opening:'{' output:output];
}

- (BOOL)scanPastClosingAngleBracket:(NSString **)output {
    return [self scanPastClosingTag:'>' opening:'<' output:output];
}

- (BOOL)scanPastClosingEndIfDirective {
    ScanPush();
    static NSArray *openings = StaticArray(openings, @"#if", @"#ifdef", @"#ifndef");
    
    NSInteger c = 1;
    while (c > 0 && self.scanLocation < self.string.length) {
        if ([self.string characterAtIndex:self.scanLocation] == '#') {
            if ([self scanAny:openings ensureKeyword:NO into:nil]) {
                c++;
            } else if ([self scanString:@"#endif"]) {
                c--;
            } else {
                self.scanLocation++;
            }
        } else {
            self.scanLocation++;
        }
    }
    
    if (c > 0) {
        ScanPop();
        return NO;
    }
    
    return YES;
}

@end
