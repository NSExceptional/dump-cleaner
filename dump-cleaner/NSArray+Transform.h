//
//  NSArray+Transform.h
//  dump-cleaner
//
//  Created by Tanner on 4/4/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSArray<ObjectType> (Transform)

- (NSArray *)map:(id(^)(ObjectType object, NSUInteger idx))transform;
- (NSString *)join:(NSString *)separator;

@property (nonatomic, readonly) NSArray *flattened;

@end
