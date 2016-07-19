//
//  NSString+Replacement.h
//  dump-cleaner
//
//  Created by Tanner on 7/15/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSString (Replacement)

- (instancetype)stringByReplacingPattern:(NSString *)pattern with:(NSString *)replacement;

@property (nonatomic, readonly) NSString *methodSelectorString;

@end
