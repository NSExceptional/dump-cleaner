//
//  DCMethod.m
//  dump-cleaner
//
//  Created by Tanner on 8/3/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCMethod.h"


@interface DCMethod ()
@property (nonatomic, readonly) BOOL isInstanceMethod;
@property (nonatomic, readonly) NSArray<NSString*> *argumentNames;
@end

@implementation DCMethod

+ (instancetype)types:(NSArray<NSString*> *)types selector:(NSString *)selector argumentNames:(NSArray *)names instance:(BOOL)instance {
    return [[self alloc] initWithTypes:types selector:selector argumentNames:names instance:instance];
}

- (id)initWithTypes:(NSArray<NSString*> *)types selector:(NSString *)selector argumentNames:(NSArray *)names instance:(BOOL)instance {
    NSParameterAssert(types.count); NSParameterAssert(selector);
    self = [super init];
    if (self) {
        _types            = types.mutableCopy;
        _selectorString   = selector;
        _argumentNames    = names;
        _isInstanceMethod = instance;
    }
    
    return self;
}

- (BOOL)buildString {
    NSInteger c = 0;
    NSArray *selectorParts = [_selectorString componentsSeparatedByString:@":"];
    NSString *returnType   = _types[0];
    
    // Start with the method type, return type, and first selector component
    _string = [NSMutableString stringWithString:_isInstanceMethod ? @"- " : @"+ "];
    [_string appendFormat:@"(%@)%@", returnType, selectorParts[0]];
    
    if (selectorParts.count > 1) {
        [_string appendString:@":"];
        
        // Loop over remaining selector components and type
        selectorParts  = [selectorParts subarrayWithRange:NSMakeRange(1, selectorParts.count-1)];
        NSArray *types = [_types subarrayWithRange:NSMakeRange(1, _types.count-1)];
        for (NSString *selectorPart in selectorParts) {
            [_string appendFormat:@"(%@)%@ %@:", types[c], _argumentNames[c++], selectorPart];
        }
        // Append the last ones because there will be one less selector component
        [_string appendFormat:@"(%@)%@", types[c], _argumentNames[c++]];
    }
    
    [_string appendString:@";"];
    
    return YES;
}

#pragma mark Public interface

+ (BOOL)test {
    DCMethod *method = [DCMethod types:@[@"void"] selector:@"foo" argumentNames:nil instance:YES];
    DCAssertEqualObjects(method.string, @"- (void)foo;");
    
    method = [DCMethod types:@[@"void", @"Foo", @"char"] selector:@"foo:bar:" argumentNames:@[@"data", @"c"] instance:NO];
    DCAssertEqualObjects(method.string, @"+ (void)foo:(Foo)data bar:(char)c;");
    
    method = [DCMethod types:@[@"void", @"double", @"char", @"int"]
                    selector:@"foo::bar:" argumentNames:@[@"dd", @"cc", @"ii"] instance:NO];
    DCAssertEqualObjects(method.string, @"+ (void)foo:(double)dd :(char)cc bar:(int)ii;");
    
    method = nil;
    NSScanner *scanner = [NSScanner scannerWithString:@"+(void) foo: (  double )dd :(char*)cc bar:(int)ii NS_FOO;"];
    [scanner scanMethod:&method];
    DCAssertEqualObjects(method.string, @"+ (void)foo:(double)dd :(char *)cc bar:(int)ii;");
    
    return YES;
}

- (void)updateWithKnownStructs:(NSArray *)structNames {
    // I'm not sure this is necessary anymore
}

@end
