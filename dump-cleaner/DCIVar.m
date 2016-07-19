//
//  DCIVar.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCIVar.h"


@implementation DCIVar

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
            _string = [NSString stringWithFormat:@"    %@%@;", _type, _name].mutableCopy;
        } else {
            _string = [NSString stringWithFormat:@"    %@ %@;", _type, _name].mutableCopy;
        }
    }
    
    return self;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[DCIVar class]])
        return [self isEqualToIVar:object];
    
    return [super isEqual:object];
}

- (BOOL)isEqualToIVar:(DCIVar *)ivar {
    return [self.name isEqualToString:ivar.name] && [self.type isEqualToString:ivar.type];
}

+ (BOOL)test {
    DCIVar *ivar = [DCIVar withString:@"    NSString* _name;\n"];
    DCAssertEqualObjects(@"_name", ivar.name);
    DCAssertEqualObjects(@"NSString *", ivar.type);
    
    ivar = [DCIVar withString:@"    NSArray<NSString *> *_things;\n"];
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

@end
