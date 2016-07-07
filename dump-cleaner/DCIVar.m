//
//  DCIVar.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCIVar.h"


@interface DCIVar ()
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *type;
@end

@implementation DCIVar

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _string = string;
        _name = [string allMatchesForRegex:krIvarComponents atIndex:krIvarComponents_name].firstObject;
        _type = [string allMatchesForRegex:krIvarComponents atIndex:krIvarComponents_type].firstObject;
        NSParameterAssert(_name && _type);
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
    DCIVar *ivar = [DCIVar withString:@"    NSString * _name;\n"];
    DCAssertEqualObjects(@"_name", ivar.name);
    DCAssertEqualObjects(@"NSString *", ivar.type);
    
    return YES;
}

@end
