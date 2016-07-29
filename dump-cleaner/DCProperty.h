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

@property (nonatomic, readonly) NSString *rawType;

/// Ensures `retain` will be in the `string` if the property was not already known to be an object
@property (nonatomic) BOOL isObject;

/// Used to find and remove instances of the setter
@property (nonatomic, readonly) NSString *setterRegex;
/// Used to find and remove instances of the getter
@property (nonatomic, readonly) NSString *getterRegex;
/// Used to find and remove instances of the backing ivar
@property (nonatomic, readonly) DCVariable *ivar;

- (void)updateWithKnownStructs:(NSArray *)structNames;

@end
