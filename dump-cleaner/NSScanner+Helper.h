//
//  NSScanner+Helper.h
//  dump-cleaner
//
//  Created by Tanner on 8/3/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSScanner (Helper)

@property (nonatomic, readonly) NSString *remainingString;
@property (nonatomic, readonly) NSString *scannedString;
@property (nonatomic, readonly) char nextScannableChar;

@property (nonatomic, readonly) NSCharacterSet *variableNameCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *variableAttributesCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *alphaCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *numericOperatorsCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *spaceCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *newlineCharacterSet;
@property (nonatomic, readonly) NSCharacterSet *hexadecimalCharacterSet;

- (BOOL)scanString:(NSString *)string;
- (BOOL)scanToString:(NSString *)string;
- (BOOL)scanWord:(NSString *)string;
- (BOOL)scanWord:(NSString *)string into:(NSString **)output;
- (BOOL)scanCharacters:(NSCharacterSet *)characters;
- (BOOL)scanToCharacters:(NSCharacterSet *)characters;
- (BOOL)scanAny:(NSArray<NSString *> *)strings ensureKeyword:(BOOL)keyword into:(NSString **)output;
- (BOOL)scanExpression:(NSString **)output;
- (BOOL)scanNumberLiteral:(NSString **)output;
- (BOOL)scanToStringOnSameLine:(NSString *)string;

@end
