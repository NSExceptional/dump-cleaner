//
//  DCClass.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"


@interface DCClass : DCObject

/// @param classes A mapping of [class : path] of all recognized classes.
+ (instancetype)withString:(NSString *)string knownClasses:(NSDictionary *)classes knownStructs:(NSDictionary *)structs;

@property (nonatomic, readonly) NSString *superclassName;

@end
