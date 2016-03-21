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

@property (nonatomic) NSMutableArray<NSString  *> *imports;
@property (nonatomic) NSMutableArray<NSString  *> *protocols;
@property (nonatomic) NSMutableArray<DCProperty*> *properties;
@property (nonatomic) NSMutableArray<NSString  *> *ivars;
@property (nonatomic) NSMutableArray<NSString  *> *methods;

@end

@implementation DCClass

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        [self findImports:string];
        [self findProperties:string];
        [self findProperties:string];
        [self findIVars:string];
        [self findMethods:string];
        [self removePropertyBackingIVars];
    }
    
    return self;
}

- (void)findImports:(NSString *)string {
    
}

- (void)findProtocols:(NSString *)string {
    
}

- (void)findProperties:(NSString *)string {
    
}

- (void)findIVars:(NSString *)string {
    
}

- (void)findMethods:(NSString *)string {
    
}

- (void)removePropertyBackingIVars {
    
}

- (NSArray<NSString*> *)dependenciesGivenClasses:(NSArray<NSString*> *)classes {
    
    return nil;
}

@end
