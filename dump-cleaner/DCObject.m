//
//  DCObject.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"


@implementation DCObject

+ (instancetype)withString:(NSString *)string {
    return [[self alloc] initWithString:string];
}

- (NSString *)string {
    if (!_string) {
        [self buildString];
    }
    
    return _string;
}

- (id)initWithString:(NSString *)string { return nil; }

+ (BOOL)test { return NO; }

- (BOOL)buildString { return NO; }

@end
