//
//  NSScanner+ObjectiveC.h
//  dump-cleaner
//
//  Created by Tanner on 7/29/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DCVariable, DCProperty, DCClass, DCProtocol, DCInterface;

@interface NSScanner (ObjectiveC)

- (BOOL)scanInterface:(DCInterface **)output;
- (BOOL)scanClass:(DCClass **)output;
- (BOOL)scanProtocol:(DCProtocol **)output;
- (BOOL)scanProperty:(DCProperty **)output;
- (BOOL)scanVariable:(DCVariable **)output;
- (BOOL)scanStructOrUnion:(NSString **)output;

@end
