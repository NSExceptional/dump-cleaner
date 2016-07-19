//
//  DCInterface.m
//  dump-cleaner
//
//  Created by Tanner on 7/19/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCClass.h"
#import "DCProtocol.h"
#import "DCProperty.h"


@interface DCInterface ()

@property (nonatomic) NSArray<NSString*>          *conformedProtocols;

@property (nonatomic) NSMutableSet<DCClass*>    *dependingClasses;
@property (nonatomic) NSMutableSet<DCProtocol*> *dependingProtocols;

@end

@implementation DCInterface

+ (instancetype)withString:(NSString *)string {
    return [[self alloc] initWithString:string];
}

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _string       = string.mutableCopy;
        _name         = [string matchGroupAtIndex:krClass_name    forRegex:krClass_123];
        
        self.protocols          = [NSMutableSet set];
        self.dependingClasses   = [NSMutableSet set];
        self.dependingProtocols = [NSMutableSet set];
        
        // Find
        [self findProtocols];
        [self findProperties];
        [self findMethods];
        
        // Store finished product to later recreate _string with dependencies
        // MUST NOT USE string GETTER HERE
        _orig = _string.copy;
    }
    
    return self;
}

#pragma mark Public interface

- (NSString *)string {
    if (!_string) {
        _string = [NSMutableString string];
        
        // Prepend imports
        for (DCInterface *interface in @[self.dependingClasses, self.dependingProtocols].flattened)
            [_string appendString:interface.importStatement];
        
        [_string appendString:@"\n\n"];
        [_string appendString:_orig];
    }
    
#warning Use .copy if it won't affect runtime too badly
    return _string;
}

- (void)setOutputDirectory:(NSString *)outputDirectory { assert(false); }

#pragma mark Processing

- (void)updateWithKnownClasses:(NSArray<DCClass*> *)classes {
    // Prepare to update class dependencies by
    // filtering .properties by whether the property
    // is an object or pointer, to make finding
    // dependencies easier below
    
    NSSet *classNames = [NSSet setWithArray:[classes valueForKeyPath:@"@unionOfObjects.name"]];
    NSArray *nonObjectProperties = [self.properties map:^id(DCProperty *property, NSUInteger idx, BOOL *discard) {
        *discard = !property.isObject || !property.ivar.isPointer;
        return property;
    }];
    
    // Update object properties
    for (DCProperty *property in nonObjectProperties) {
        BOOL isObject = [classNames containsObject:property.rawType];
        property.isObject = isObject;
        
        // Add class dependency
        if (isObject) {
            for (DCClass *class in classes) {
                if ([class.name isEqualToString:property.rawType]) {
                    [self.dependingClasses addObject:class];
                    break;
                }
            }
        }
    }
}

- (void)updateWithKnownStructs:(NSArray *)structNames {
    for (DCProperty *property in self.properties)
        [property updateWithKnownStructs:structNames];
}

- (void)updateWithKnownProtocols:(NSArray<DCProtocol*> *)protocols {
    NSMutableSet *dependencies = [NSMutableSet setWithArray:protocols];
    [dependencies intersectSet:self.protocols];
    [self.protocols minusSet:dependencies];
    self.dependingProtocols = dependencies.allObjects.mutableCopy;
}

#pragma mark Searching

- (void)findProtocols {
    self.conformedProtocols = [self.string allMatchesForRegex:krClass_123 atIndex:krClass_conformed];
    [self.protocols addObjectsFromArray:[self.string allMatchesForRegex:krProtocolType_1 atIndex:krProtocolType_protocol]];
}

- (void)findProperties {
    self.properties = [[self.string allMatchesForRegex:krProperty_12 atIndex:0] map:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return [DCProperty withString:object];
    }].mutableCopy;
}

- (void)findMethods {
    self.methods = [self.string allMatchesForRegex:krMethod atIndex:0].mutableCopy;
}

@end