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
+ (instancetype)withString:(NSString *)string categoryName:(NSString *)name;

- (void)updateWithKnownClasses:(NSArray *)classNames;
- (void)updateWithKnownStructs:(NSArray *)structNames;
- (void)updateWithKnownProtocols:(NSDictionary<NSString*, NSString*> *)namesToFilenames;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *superclassName;

@end
