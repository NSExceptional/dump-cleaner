//
//  DCObject.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DCObject : NSObject {
    @protected
    NSString *_string;
}

+ (instancetype)withString:(NSString *)string;
/// Subclasses should not call super
- (id)initWithString:(NSString *)string;
+ (BOOL)test;

@property (nonatomic, readonly) NSString *string;

@end
