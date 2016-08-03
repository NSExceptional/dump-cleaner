//
//  DCProperty.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCProperty.h"


@interface DCProperty ()
@property (nonatomic, readonly) BOOL alreadyObject;
@property (nonatomic, readonly) NSMutableArray *attributes;
@end

@implementation DCProperty

+ (instancetype)withAttributes:(NSArray *)attrs variable:(DCVariable *)variable {
    return [[self alloc] initWithAttributes:attrs variable:variable];
}

- (id)initWithString:(NSString *)string { return nil; }
- (id)initWithAttributes:(NSArray *)attrs variable:(DCVariable *)variable {
    NSParameterAssert(attrs); NSParameterAssert(variable);
    self = [super init];
    if (self) {
        _name          = variable.name;
        _ivar          = variable;
        _attributes    = attrs.mutableCopy;
        _isObject      = _alreadyObject = ({
            [attrs containsObject:@"copy"] || [attrs containsObject:@"retain"] ||
            [attrs containsObject:@"assign"] || [variable.type isEqualToString:@"id"] ||
            ([variable.type hasPrefix:@"id"] && ![variable.type containsString:@"*"]);
        });
        
        variable.name = [@"_" stringByAppendingString:variable.name];
        
        // Getter and setter //
        // Filter the attibutes array to find the
        // getter/setter attributes, or default
        // to the compiler generated ones.
        
        _getterSelector = [[attrs map:^id(NSString *str, NSUInteger idx, BOOL *discard) {
            *discard = ![str hasPrefix:@"getter"];
            return str;
        }].firstObject componentsSeparatedByString:@"="][1] ?: variable.name;
        if (![attrs containsObject:@"readonly"]) {
            _setterSelector = [[attrs map:^id(NSString *str, NSUInteger idx, BOOL *discard) {
                *discard = ![str hasPrefix:@"setter"];
                return str;
            }].firstObject componentsSeparatedByString:@"="][1] ?:
            [NSString stringWithFormat:@"set%@:", variable.name.capitalizedString];
        }
    }
    
    return self;
}

- (NSString *)string {
    if (!_string) {
        [self buildString];
    }
    
    return _string;
}

- (NSString *)classType {
    if (_isObject) {
        return _ivar.rawType;
    }
    
    return nil;
}

#pragma mark Tests

+ (BOOL)test {
    DCProperty *p = [DCProperty withString:@"@property( nonatomic,readonly, setter=food:)MYClass *food;"];
    DCAssertEqualObjects(@"- ?\\(void\\)food:\\(id\\)\\w+", p.setterRegex);
    DCAssertEqualObjects(@"MYClass", p.rawType);
    DCAssertNil(p.getterRegex);
    DCAssertFalse(p.isObject);
    p.isObject = YES;
    DCAssertEqualObjects(@"@property (retain, nonatomic, readonly, setter=food: ) MYClass *food;", p.string);
    
    p = [DCProperty withString:@"@property (nonatomic, copy) int food;"];
    DCAssertTrue(p.isObject);
    DCAssertEqualObjects(@"- ?\\(int\\)food;", p.getterRegex);
    DCAssertEqualObjects(@"- ?\\(void\\)setFood:\\(int\\)\\w+", p.setterRegex);
    DCAssertEqualObjects(p.value, p.string);
    
    return YES;
}

#pragma mark Public interface

- (void)setIsObject:(BOOL)isObject {
    if (isObject == _isObject || self.alreadyObject) return;
    _isObject = isObject;
    _string = nil;
}

- (void)updateWithKnownStructs:(NSArray *)structNames {
    if ([self.ivar.type hasPrefix:@"struct"]) {
        NSString *structName = [self.ivar.type componentsSeparatedByString:@" "][1];
        assert(structName);
        for (NSString *name in structNames) {
            if ([structName isEqualToString:name]) {
                self.ivar.type = name;
                _string = nil;
                break;
            }
        }
    }
}

#pragma mark Processing

- (void)buildString {
    _string = [NSMutableString stringWithString:@"@property "];
    // Property attributes
    if (_attributes.count) {
        [_string appendString:@"("];
        for (NSString *attribute in _attributes)
            [_string appendFormat:@"%@, ", attribute];
        if (_isObject && !_alreadyObject) {
            [_string appendString:@"retain) "];
        } else {
            [_string deleteCharactersInRange:NSMakeRange(_string.length-2, 2)];
            [_string appendString:@") "];
        }
    }
    
    [_string appendFormat:@"%@ %@;", self.ivar.type, self.name];
}

@end
