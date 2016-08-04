//
//  NSArray+Transform.m
//  dump-cleaner
//
//  Created by Tanner on 4/4/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSArray+Transform.h"
#import <objc/runtime.h>

@implementation NSArray (Transform)

- (NSArray *)map:(id(^)(id object, NSUInteger idx, BOOL *discard))transform {
    NSParameterAssert(transform);
    
    NSMutableArray *array = [NSMutableArray array];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BOOL discard = NO;
        id newObj = transform(obj, idx, &discard);
        
        if (discard) {
            return;
        } else {
            [array addObject:newObj];
        }
    }];
    
    return array.copy;
}

- (NSString *)join:(NSString *)separator {
    NSMutableString *joined = [NSMutableString string];
    
    if (separator.length) {
        for (NSString *string in self) {
            [joined appendFormat:@"%@%@", string, separator];
        }
        
        [joined deleteCharactersInRange:NSMakeRange(joined.length-separator.length, separator.length)];
    } else {
        for (NSString *string in self) {
            [joined appendString:string];
        }
    }
    
    return joined.copy;
}

- (NSArray *)flattened {
    return [self valueForKeyPath:@"@unionOfArrays.self"];
}

@end
