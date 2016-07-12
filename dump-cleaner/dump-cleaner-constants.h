//
//  dump-cleaner-constants.h
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


extern NSString * const kUsage;
extern NSString * const krImportStatement;

#pragma mark - Classes, categories, protocols -

#pragma mark Classes
extern NSString * const krClassDefinition;
extern NSString * const krCategoryDefinition;
extern NSString * const krClass_123;
extern NSUInteger const krClass_Name;
extern NSUInteger const krClass_Superclass;
extern NSUInteger const krClass_Conformed;

#pragma mark Categories
extern NSString * const krCategory_12;
extern NSUInteger const krCategory_Class;
extern NSUInteger const krCategory_Name;

#pragma mark Protocols
extern NSString * const krProtocolDefinition;
extern NSString * const krProtocol_12;
extern NSUInteger const krProtocol_Name;
extern NSUInteger const krProtocol_Conformed;

/// Find any protocol in file
extern NSString * const krProtocol_1;
extern NSUInteger const krProtocol_name;

#pragma mark - Structs
// Find unknown structs
// Assumes: structs will not contain any objects said to conform to a protocol or with any special keywords
extern NSString * const krStructUnknown_1_2;
extern NSUInteger const krStructUnknown_type;
extern NSUInteger const krStructUnknown_typedef;

/// Replacing expanded structs by name
extern NSString * const krStructKnown;

/// Find empty structs in file
extern NSString * const krEmptyStruct_1;
extern NSUInteger const krEmptyStruct_type;
extern NSString * const krKnownStructs;


#pragma mark - Properties, methods, and instance variables -

#pragma mark Properties
/// Find properties
extern NSString * const krProperty_12;
extern NSUInteger const krProperty_type;
extern NSUInteger const krProperty_name;

/// Find setter in a property string
extern NSString * const krPropertySetter_1;
extern NSUInteger const krPropertySetter_name;
/// Find getter in a property string
extern NSString * const krPropertyGetter_1;
extern NSUInteger const krPropertyGetter_name;
/// Whether the property contains readonly
extern NSString * const krPropertyIsReadonly_1;
/// Whether the property is a class property
extern NSString * const krPropertyIsClass_1;
/// Whether the property contains retain, copy, assign
extern NSString * const krPropertyHasARCAttribute_1;

#pragma mark Methods
// Find methods

#pragma mark Instance variables
/// Find the group of ivars
extern NSString * const krIvarsPresent_1;
extern NSUInteger const krIvarsPresent_ivars;

/// Grab parts of each ivar given a string of ivars grabbed using the krIvarsPresent_1 regex
extern NSString * const krIvarComponents_12;
extern NSUInteger const krIvarComponents_type;
extern NSUInteger const krIvarComponents_name;

