//
//  DCProperty.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"
#import "DCIVar.h"

@interface DCProperty : DCObject

@property (nonatomic, readonly) NSString *rawType;

/// Ensures `retain` will be in the `string`
@property (nonatomic) BOOL isObject;

@property (nonatomic, readonly) NSString *setterRegex;
@property (nonatomic, readonly) NSString *getterRegex;
@property (nonatomic, readonly) DCIVar *ivar;

@end
