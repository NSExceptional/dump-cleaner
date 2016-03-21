//
//  DCClass.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"


@interface DCClass : DCObject

- (NSArray<NSString*> *)dependenciesGivenClasses:(NSArray<NSString*> *)classes;

@property (nonatomic, readonly) NSString *superclassName;

@end
