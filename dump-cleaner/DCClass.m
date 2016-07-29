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
@property (nonatomic) NSMutableArray<DCIVar*> *ivars;
@property (nonatomic) DCClass *dc_superclass;
@end

@implementation DCClass

#pragma mark Initializers

+ (instancetype)withString:(NSString *)string categoryName:(NSString *)categoryName {
    DCClass *class = [self withString:string];
    class->_categoryName = categoryName;
    return class;
}

- (id)initWithString:(NSString *)string {
    self = [super initWithString:string];
    if (self) {
        _categoryName = [string matchGroupAtIndex:krCategory_name forRegex:krCategory_12];
        if (!_categoryName) {
            _superclassName = [string matchGroupAtIndex:krClass_superclass forRegex:krClass_123];
        }
        
        // Find
        [self findIVars];
        
        // Fix
        [self removePropertyBackingIVars];
        [self removePropertyMethods];
        [self removeNSObjectMethodsAndProperties];
        [self removeSuperclassMethods];
        
        // Store finished product to later recreate _string with dependencies
        // MUST NOT USE string GETTER HERE
        _orig = _string.copy;
    }
    
    return self;
}

#pragma mark Public interface

- (NSString *)outputLocation {
    if (_outputDirectory) {
        if (self.categoryName) {
            return [_outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@+%@.h", self.name, self.categoryName]];
        }
        
        return [_outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h", self.name]];
    }
    
    return nil;
}

- (void)setOutputDirectory:(NSString *)outputDirectory {
    NSParameterAssert(outputDirectory);
    _outputDirectory = outputDirectory;
    NSString *nameToUse = self.categoryName ?: [self.name stringByAppendingString:@"+AppleInternal"];
    _importStatement = DCImportStatement(outputDirectory, nameToUse);
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
        return [self.name isEqualToString:class.name];
    }
    
    return NO;
}

- (NSUInteger)hash { return _categoryName ? self.categoryKey.hash : self.name.hash; }

#pragma mark Processing

- (void)updateWithKnownClasses:(NSArray<DCClass*> *)classes {
    // Find superclass
    for (DCClass *class in classes) {
        if ([class.name isEqualToString:self.superclassName]) {
            self.dc_superclass = class;
            break;
        }
    }
    
    [super updateWithKnownClasses:classes];
}

- (void)updateWithKnownStructs:(NSArray *)structNames {
    [super updateWithKnownStructs:structNames];
    
    for (DCVariable *ivar in self.ivars)
        [ivar updateWithKnownStructs:structNames];
}

#pragma mark Searching

- (void)findIVars {
    self.ivars = [[self.string allMatchesForRegex:krIvarComponents_12 atIndex:0] map:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return [DCIVar withString:object];
    }].mutableCopy;
}

- (void)removePropertyBackingIVars {
    NSSet *ivars = [NSSet setWithArray:self.ivars];
    for (DCProperty *property in self.properties)
        if ([ivars containsObject:property.ivar])
            [self.ivars removeObject:property.ivar];
}

- (void)removePropertyMethods {
    self.methods = [self.methods map:^id(NSString *method, NSUInteger idx, BOOL *discard) {
        for (DCProperty *property in self.properties) {
            if ([method matchesPattern:property.getterRegex] || [method matchesPattern:property.setterRegex]) {
                *discard = YES;
                return nil;
            }
        }
        
        return method;
    }].mutableCopy;
}

- (void)removeNSObjectMethodsAndProperties {
    NSArray *selectors = @[@"class", @"hash", @"self", @"superclass", @"isEqual:"];
    self.methods = [self.methods map:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        if ([selectors containsObject:object.methodSelectorString])
            *discard = YES;
        return object;
    }].mutableCopy;
}

- (void)removeSuperclassMethods {
    // TODO, this will be difficult
}

@end
