//
//  DCParser.h
//  dump-cleaner
//
//  Created by Tanner on 7/23/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DCInterface.h"


@interface DCParser : NSObject

+ (NSArray<DCInterface*> *)parseString:(NSString *)file;

@end
