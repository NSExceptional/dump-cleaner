//
//  DCIVar.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"

@interface DCVariable : DCObject

+ (instancetype)type:(NSString *)type name:(NSString *)name;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) BOOL isPointer;

- (void)updateWithKnownStructs:(NSArray *)structNames;

@end
