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

@end

@implementation DCInterface

+ (instancetype)withString:(NSString *)string {
    return [[self alloc] initWithString:string];
}

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        self.protocols          = [NSMutableSet set];
        self.dependingClasses   = [NSMutableSet set];
        self.dependingProtocols = [NSMutableSet set];
        
        if (!([self parseOriginalString] && [self buildString])) {
            return nil;
        }
        
        // Store finished product to later recreate _string with dependencies
        // MUST NOT USE string GETTER HERE
        //        _orig = _string.copy;
    }
    
    return self;
}

#pragma mark Public interface

- (NSString *)string {
    if (!_string) {
        [self buildString];
    }
    
    //#warning Use .copy if it won't affect runtime too badly
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

- (BOOL)buildString {
    _string = [NSMutableString string];
    
    // TODO comments at the top of _string
    
    // Prepend imports
    for (DCInterface *interface in @[self.dependingClasses, self.dependingProtocols].flattened)
        [_string appendFormat:@"%@\n", interface.importStatement];
    
    return YES;
}

- (BOOL)parseOriginalString {
    [NSException raise:NSGenericException format:@"Subclasses must override this method and not call super."];
    return NO;
}

@end