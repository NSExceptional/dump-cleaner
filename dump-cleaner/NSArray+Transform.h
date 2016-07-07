//
//  NSArray+Transform.h
//  dump-cleaner
//
//  Created by Tanner on 4/4/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSArray<ObjectType> (Transform)

- (NSArray *)arrayByTransformingWithBlock:(id(^)(ObjectType object, NSUInteger idx, BOOL *discard))transform;

@end
