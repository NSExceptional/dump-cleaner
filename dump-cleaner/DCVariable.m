//
//  DCIVar.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCVariable.h"


@implementation DCVariable

+ (instancetype)type:(NSString *)type name:(NSString *)name {
    return [[self alloc] initWithType:type name:name];
}

- (id)initWithType:(NSString *)type name:(NSString *)name {
    NSParameterAssert(type); NSParameterAssert(name);
    NSParameterAssert(![type hasSuffix:@" "]);
    self = [super init];
    if (self) {
        _type = type;
        _name = name;
        [self buildString];
    }
    
    return self;
}

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _name = [string allMatchesForRegex:krIvarComponents_12 atIndex:krIvarComponents_name].firstObject;
        _type = [string allMatchesForRegex:krIvarComponents_12 atIndex:krIvarComponents_type].firstObject;
        
        // Replace `Type*` with `Type *`
        if ([_type hasSuffix:@"*"] || [_type hasSuffix:@"* "]) {
            _type = [_type stringByReplacingPattern:@" ?\\* ?" with:@" *"];
            _isPointer = YES;
        }
        
        NSParameterAssert(_name && _type);
        
        // Space if no pointer, no space if pointer
        if (self.isPointer) {
            _string = [NSString stringWithFormat:@"%@%@;", _type, _name].mutableCopy;
        } else {
            _string = [NSString stringWithFormat:@"%@ %@;", _type, _name].mutableCopy;
        }
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[DCVariable class]])
        return [self isEqualToIVar:object];
    
    return [super isEqual:object];
}

- (BOOL)isEqualToIVar:(DCVariable *)ivar {
    return [self.name isEqualToString:ivar.name] && [self.type isEqualToString:ivar.type];
}

+ (BOOL)test {
    DCVariable *ivar = [DCVariable withString:@"    NSString* _name;\n"];
    DCAssertEqualObjects(@"_name", ivar.name);
    DCAssertEqualObjects(@"NSString *", ivar.type);
    
    ivar = [DCVariable withString:@"    NSArray<NSString *> *_things;\n"];
    DCAssertEqualObjects(@"_things", ivar.name);
    DCAssertEqualObjects(@"NSArray<NSString *> *", ivar.type);
    
    return YES;
}

#pragma mark Public interface

- (void)updateWithKnownStructs:(NSArray *)structNames {
    for (NSString *name in structNames) {
        if ([_type matchesForRegex:[NSString stringWithFormat:krStructKnown, name]]) {
            _type = [_type stringByReplacingPattern:krStructUnknown_1_2 with:name];
            break;
        }
    }
}

- (void)setType:(NSString *)type {
    _type = type;
    [self buildString];
}

- (void)setName:(NSString *)name {
    _name = name;
    [self buildString];
}

#pragma mark Processing

- (void)buildString {
    _isPointer = [_type hasSuffix:@"*"];
    
    // Space if no pointer, no space if pointer
    if (self.isPointer) {
        _string = [NSMutableString stringWithFormat:@"%@%@;", _type, _name];
    } else {
        _string = [NSMutableString stringWithFormat:@"%@ %@;", _type, _name];
    }
    
    _rawType = [_type componentsSeparatedByString:@" "].firstObject;
    _rawType = [_rawType stringByTrimmingCharactersInSet:[NSCharacterSet letterCharacterSet].invertedSet];
    if ([_rawType isEqualToString:@"struct"] || [_rawType isEqualToString:@"union"]) {
        _rawType = nil;
    }
}

@end
