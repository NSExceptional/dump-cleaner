//
//  DCProperty.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCProperty.h"


@interface DCProperty ()
@property (nonatomic, readonly) NSString *value;
@property (nonatomic, readonly) BOOL alreadyObject;
@end

@implementation DCProperty

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _value = string;
        // Whether is object type
        _alreadyObject = [string allMatchesForRegex:krPropertyHasARCAttribute atIndex:0].count > 0;
        self.isObject  = self.alreadyObject;
        
        // Type and name = ivar
        NSString *type = [string allMatchesForRegex:krProperty atIndex:krProperty_type].firstObject;
        NSString *name = [string allMatchesForRegex:krProperty atIndex:krProperty_name].firstObject;
        _ivar = [DCIVar withString:[NSString stringWithFormat:@"%@ _%@;", type, name]];
        NSParameterAssert(name && type);
        
        // Getter and setter
        NSString *getter = [string allMatchesForRegex:krPropertyGetter atIndex:krPropertyGetter_name].firstObject ?: name;
        NSString *setter = [string allMatchesForRegex:krPropertySetter atIndex:krPropertySetter_name].firstObject ?: [NSString stringWithFormat:@"set%@:", name.pascalCaseString];
        _rawType = [string stringByReplacingOccurrencesOfString:@" ?\\* ?" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, type.length)];
        if (self.isObject) { type = @"id"; }
        // Readonly?
        _getterRegex = [NSString stringWithFormat:@"- ?\\(%@\\)%@;", type, getter];
        if (![string allMatchesForRegex:krPropertyIsReadonly atIndex:0]) {
            _setterRegex = [NSString stringWithFormat:@"- ?\\(void\\)%@\\(%@\\)\\w+;", setter, type];
        }
        
    }
    
    return self;
}

- (NSString *)string {
    if (!_string) {
        NSMutableString *string = self.value.mutableCopy;
        [string replaceOccurrencesOfString:@"@property ?\\( ?" withString:@"@property (" options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
        [string replaceOccurrencesOfString:@" ?, ?" withString:@", " options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
        [string replaceOccurrencesOfString:@" ?\\) ?" withString:@") " options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
        [string replaceOccurrencesOfString:@" ?\\* ?" withString:@" *" options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
        if (self.isObject && !self.alreadyObject) {
            if ([string containsString:@"("]) {
                [string replaceOccurrencesOfString:@"(" withString:@"(retain, " options:0 range:NSMakeRange(0, string.length)];
            } else {
                [string replaceOccurrencesOfString:@"@property " withString:@"@property (retain) " options:0 range:NSMakeRange(0, string.length)];
            }
        }
        _string = string.copy;
    }
    
    return _string;
}

- (void)setIsObject:(BOOL)isObject {
    if (isObject == _isObject || self.alreadyObject) return;
    _isObject = isObject;
    _string = nil;
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

@end
