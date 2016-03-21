//
//  dump-cleaner-constants.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


extern NSString * const kUsage;

extern NSString * const krKnownStructs;
extern NSString * const krStruct;
extern NSUInteger const krStruct_type;
extern NSString * const krEmptyStruct;
extern NSUInteger const krEmptyStruct_type;

extern NSString * const krProperty;
extern NSUInteger const krProperty_type;
extern NSUInteger const krProperty_name;
extern NSString * const krPropertySetter;
extern NSUInteger const krPropertySetter_name;
extern NSString * const krPropertyGetter;
extern NSUInteger const krPropertyGetter_name;
extern NSString * const krPropertyIsReadonly;
extern NSString * const krPropertyHasARCAttribute;

extern NSString * const krIvarsPresent;
extern NSUInteger const krIvarsPresent_ivars;
extern NSString * const krIvarComponents;
extern NSUInteger const krIvarComponents_type;
extern NSUInteger const krIvarComponents_name;

extern NSString * const krSupeclass;
extern NSUInteger const krSupeclass_name;

extern NSString * const krDelegateMissingType;
extern NSUInteger const krDelegateMissingType_protocol;
extern NSUInteger const krDelegateMissingType_replace;

extern NSString * const krProtocol;
extern NSUInteger const krProtocol_name;
extern NSString * const krConformedProtocols;
extern NSUInteger const krConformedProtocols_value;
