//
//  NSScanner+Helper.h
//  dump-cleaner
//
//  Created by Tanner on 8/3/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSScanner (Helper)

@property (nonatomic, readonly) NSCharacterSet *variableNameCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *variableAttributesCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *alphaCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *numericOperatorsCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *spaceCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *newlineCharacterSet;

- (BOOL)scanString:(NSString *)string;
- (BOOL)scanToString:(NSString *)string;
- (BOOL)scanCharacters:(NSCharacterSet *)characters;
- (BOOL)scanToCharacters:(NSCharacterSet *)characters;
- (BOOL)scanAny:(NSArray<NSString*> *)strings into:(NSString **)output;
- (BOOL)scanExpression:(NSString **)output;
- (BOOL)scanNumberLiteral:(NSString **)output;
- (BOOL)scanToStringOnSameLine:(NSString *)string;

@end
