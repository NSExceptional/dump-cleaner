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

- (void)updateWithKnownClasses:(NSArray<DCClass*> *)classes;
- (void)updateWithKnownStructs:(NSArray *)structNames;
- (void)updateWithKnownProtocols:(NSArray<DCProtocol*> *)protocols;

- (void)makeRepairs {
    
}

- (void)findImports {
    [self.imports addObjectsFromArray:[self.string allMatchesForRegex:krImportStatement atIndex:0]];
}

- (void)findProtocols {
    [self.conformedProtocols addObjectsFromArray:[self.string allMatchesForRegex:krProtocol atIndex:krProtocol_name]];
    [self.protocols addObjectsFromArray:self.conformedProtocols];
    [self.protocols addObjectsFromArray:[self.string allMatchesForRegex:krConformedProtocols atIndex:krConformedProtocols_value]];
}

- (void)findProperties {
    NSArray *properties = [[self.string allMatchesForRegex:krProperty atIndex:0] arrayByTransformingWithBlock:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return [DCProperty withString:object];
    }];
    
    [self.properties addObjectsFromArray:properties];
}

- (void)findIVars {
    NSArray *ivars = [[self.string allMatchesForRegex:krIvarComponents atIndex:0] arrayByTransformingWithBlock:^id(NSString *object, NSUInteger idx, BOOL *discard) {
        return [DCIVar withString:object];
    }];
    
    [self.ivars addObjectsFromArray:ivars];
}

- (void)findMethods {
    NSArray *methods = [[self.string allMatchesForRegex:kr atIndex:<#(NSUInteger)#>]]
}

- (void)removePropertyBackingIVars {
    
}

- (void)addDependenciesToImports {
    
}

@end
