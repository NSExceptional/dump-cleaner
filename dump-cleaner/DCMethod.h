//
//  DCMethod.h
//  dump-cleaner
//
//  Created by Tanner on 8/3/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"


@interface DCMethod : DCObject

+ (instancetype)types:(NSArray<NSString*> *)types selector:(NSString *)selector argumentNames:(NSArray *)names instance:(BOOL)instance;

@property (nonatomic, readonly) NSString *selectorString;
@property (nonatomic, readonly) NSMutableArray<NSString*> *types;

- (void)updateWithKnownStructs:(NSArray *)structNames;

@end
