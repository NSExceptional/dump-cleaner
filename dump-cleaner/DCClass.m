//
//  DCClass.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCClass.h"
#import "DCProperty.h"


@interface DCClass ()

@property (nonatomic, readonly) NSString *categoryName;
@property (nonatomic) NSMutableArray<NSString  *> *imports;
@property (nonatomic) NSMutableArray<NSString  *> *protocols;
@property (nonatomic) NSMutableArray<NSString  *> *conformedProtocols;
@property (nonatomic) NSMutableArray<DCProperty*> *properties;
@property (nonatomic) NSMutableArray<NSString  *> *ivars;
@property (nonatomic) NSMutableArray<NSString  *> *methods;
@property (nonatomic, readonly) NSString<NSPortDelegate> *stringg;

@end

@implementation DCClass
@synthesize name = _name;

+ (instancetype)withString:(NSString *)string categoryName:(NSString *)name {
    return [[self alloc] initWithString:string categoryName:name];
}

- (id)initWithString:(NSString *)string categoryName:(NSString *)name {
    self = [super init];
    if (self) {
        _string = string;
        _categoryName = name;
        
        _name = [string matchGroupAtIndex:krClass_Name forRegex:krClass_123];
        
        self.imports            = [NSMutableArray array];
        self.protocols          = [NSMutableArray array];
        self.conformedProtocols = [NSMutableArray array];
        self.properties         = [NSMutableArray array];
        self.ivars              = [NSMutableArray array];
        self.methods            = [NSMutableArray array];
        
        [self makeRepairs];
        
        [self findProperties];
        [self findIVars];
        [self findMethods];
        [self findImports];
        [self removePropertyBackingIVars];
        [self addDependenciesToImports];
    }
    
    return self;
}

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
