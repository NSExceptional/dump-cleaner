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

@property (nonatomic) NSMutableArray<NSString  *> *imports;
@property (nonatomic) NSMutableArray<NSString  *> *protocols;
@property (nonatomic) NSMutableArray<NSString  *> *conformedProtocols;
@property (nonatomic) NSMutableArray<DCProperty*> *properties;
@property (nonatomic) NSMutableArray<NSString  *> *ivars;
@property (nonatomic) NSMutableArray<NSString  *> *methods;

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
        _name         = [string matchGroupAtIndex:krClass_Name    forRegex:krClass_123];
        _categoryName = [string matchGroupAtIndex:krCategory_Name forRegex:krCategory_12];
        
        self.imports            = [NSMutableArray array];
        self.protocols          = [NSMutableArray array];
        self.conformedProtocols = [NSMutableArray array];
        self.properties         = [NSMutableArray array];
        self.ivars              = [NSMutableArray array];
        self.methods            = [NSMutableArray array];
        
        [self findProperties];
        [self findIVars];
        [self findMethods];
        [self findImports];
        [self removePropertyBackingIVars];
        [self addDependenciesToImports];
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
