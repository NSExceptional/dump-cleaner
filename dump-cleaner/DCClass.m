//
//  DCClass.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCClass.h"
#import "DCProperty.h"
#import "DCProtocol.h"


@interface DCClass ()

@property (nonatomic) NSMutableSet<NSString*>     *protocols;
@property (nonatomic) NSMutableSet<NSString*>     *classes;
@property (nonatomic) NSArray<NSString*>          *conformedProtocols;
@property (nonatomic) NSMutableArray<DCProperty*> *properties;
@property (nonatomic) NSMutableArray<NSString*>   *ivars;
@property (nonatomic) NSMutableArray<NSString*>   *methods;

@property (nonatomic) NSMutableSet<DCClass*>    *dependingClasses;
@property (nonatomic) NSMutableSet<DCProtocol*> *dependingProtocols;

@end

@implementation DCClass

#pragma mark Initializers

+ (instancetype)withString:(NSString *)string {
    return [[self alloc] initWithString:string];
}

+ (instancetype)withString:(NSString *)string categoryName:(NSString *)categoryName {
    DCClass *class = [self withString:string];
    class->_categoryName = categoryName;
    return class;
}

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _string       = string.mutableCopy;
        _name         = [string matchGroupAtIndex:krClass_name    forRegex:krClass_123];
        _categoryName = [string matchGroupAtIndex:krCategory_name forRegex:krCategory_12];
        if (!_categoryName) {
            _superclassName = [string matchGroupAtIndex:krClass_superclass forRegex:krClass_123];
        }
        
        self.protocols          = [NSMutableSet set];
        self.dependingClasses   = [NSMutableSet set];
        self.dependingProtocols = [NSMutableSet set];
    }
    
    return self;
}

#pragma mark Public interface

- (NSString *)outputFile {
    if (_outputDirectory) {
        if (self.categoryName) {
            return [_outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@+%@.h", self.name, self.categoryName]];
        }
        
        return [_outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h", self.name]];
    }
    
    return nil;
}

#pragma mark Internal

- (NSString *)categoryKey { return self.categoryName ? [self.name stringByAppendingString:self.categoryName] : nil; }

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[self class]])
        return [self isEqualToDCClass:object];
    
    return [super isEqual:object];
}

- (BOOL)isEqualToDCClass:(DCClass *)class {
    NSString *myKey = self.categoryKey;
    NSString *otherKey = class.categoryKey;
    
    if (myKey && otherKey) {
        return [myKey isEqualToString:otherKey];
    } else if (!myKey && !otherKey) {
        return [_name isEqualToString:class.name];
    }
    
    return NO;
}

- (NSUInteger)hash { return _categoryName ? self.categoryKey.hash : _name.hash; }

#pragma mark Processing

- (void)updateWithKnownClasses:(NSArray<DCClass*> *)classes {
    NSSet *classNames = [NSSet setWithArray:[classes valueForKeyPath:@"@unionOfObjects.name"]];
    NSArray *nonObjectProperties = [self.properties map:^id(DCProperty *property, NSUInteger idx, BOOL *discard) {
        *discard = property.isObject || !property.ivar.isPointer;
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
    for (DCIVar *ivar in self.ivars)
        [ivar updateWithKnownStructs:structNames];
}

- (void)updateWithKnownProtocols:(NSArray<DCProtocol*> *)protocols {
    NSMutableSet *dependencies = [NSMutableSet setWithArray:protocols];
    [dependencies intersectSet:self.protocols];
    [self.protocols minusSet:dependencies];
    self.dependingProtocols = dependencies.allObjects.mutableCopy;
}

#pragma mark Searching

- (void)findIVars {
    self.ivars = [[self.string allMatchesForRegex:krIvarComponents_12 atIndex:0] map:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return [DCIVar withString:object];
    }].mutableCopy;
}

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
    
}

- (void)removePropertyBackingIVars {
    
}

- (void)removePropertyMethods {
    
}

- (void)removeNSObjectMethodsAndProperties {
    
}

- (void)removeSuperclassMethods {
    
}

@end
