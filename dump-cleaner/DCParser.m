//
//  DCParser.m
//  dump-cleaner
//
//  Created by Tanner on 7/23/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCParser.h"
#import "DCVariable.h"


static DCParser  * parser = nil;
static NSScanner * scanner = nil;
@implementation DCParser

+ (void)initialize {
    if (self == [self class]) {
        parser = [self new];
    }
}

+ (NSArray<DCInterface*> *)parseString:(NSString *)file {
    
}



- (BOOL)parse

+ (BOOL)parseVariable:(NSString *)input into:(NSString *)output {
    
}

@end

@interface NSScanner (Parsing)

- (BOOL)scanVariable:(DCVariable **)output {
    
}

- (BOOL)parseInterface:(DCInterface **)output {
    
}

- (BOOL)parseVariable:(NSString **)output {
    
}

@end