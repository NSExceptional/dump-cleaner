//
//  DCClass.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCInterface.h"


@interface DCClass : DCObject <DCInterface>

+ (instancetype)withString:(NSString *)string categoryName:(NSString *)categoryName;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *categoryName;
@property (nonatomic, readonly) NSString *categoryKey; // name + category name

@property (nonatomic, readonly) NSString *superclassName;

@end
