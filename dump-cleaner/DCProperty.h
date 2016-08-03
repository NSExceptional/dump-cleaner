//
//  DCProperty.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"
#import "DCVariable.h"

@interface DCProperty : DCObject

+ (instancetype)withAttributes:(NSArray *)attrs variable:(DCVariable *)variable;

/// Ensures `retain` will be in the `string` if the property was not already known to be an object
@property (nonatomic) BOOL isObject;
@property (nonatomic, readonly) NSString *classType;
@property (nonatomic, readonly) NSArray<NSString*> *conformedProtocols;

/// Used to find and remove instances of the setter
@property (nonatomic, readonly) NSString *setterSelector;
/// Used to find and remove instances of the getter
@property (nonatomic, readonly) NSString *getterSelector;
/// Used to find and remove instances of the backing ivar
@property (nonatomic, readonly) DCVariable *ivar;
@property (nonatomic, readonly) NSString *name;

- (void)updateWithKnownStructs:(NSArray *)structNames;

@end
