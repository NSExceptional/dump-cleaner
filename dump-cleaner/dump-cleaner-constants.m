//
//  dump-cleaner-constants.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "dump-cleaner-constants.h"


NSString * const kUsage = @"Usage: dumpcleaner [-fxrv] [-s path] <directory|file>\n\t-s\t<path>\tSpecify the path to the SDK to use\n\t-f\tSpecify a single file to clean instead of a directory\n\t-x\tDon\'t use an SDK, just sanitize using the headers in the current directory\n\t-r\tRecursive\n\t-v\tVerbose\n";


NSString * const krImportStatement = @"#import [\"<][\\w./+-]+[>\"]";

#pragma mark - Classes, categories, protocols -

#pragma mark Classes
NSString * const krClassDefinition    = @"@interface \\w+ ?: ?\\w+(?:(?!@end)(?:\\W|.))+@end";
NSString * const krCategoryDefinition = @"@interface \\w+ ?\\(\\w+\\)(?:(?!@end)(?:\\W|.))+@end";
NSString * const krClass_123        = @"@interface (\\w+) ?: ?(\\w+)(?: ?<(\\w+(?:, ?\\w+)*)>)?";
NSUInteger const krClass_Name       = 1;
NSUInteger const krClass_Superclass = 2;
NSUInteger const krClass_Conformed  = 3;

#pragma mark Categories
NSString * const krCategory_12    = @"@interface (\\w+) ?\\(\\w+\\)";
NSUInteger const krCategory_Class = 2;
NSUInteger const krCategory_Name  = 2;

#pragma mark Protocols
NSString * const krProtocolDefinition = @"@protocol \\w+ ?(?:(?!@end)(?:\\W|.))+@end";
NSString * const krProtocol_12 = @"@protocol (\\w+)(?: ?<(\\w+(?:, ?\\w+)*)>)?";
NSUInteger const krProtocol_Name      = 1;
NSUInteger const krProtocol_Conformed = 2;

/// Find any protocol in file
NSString * const krProtocol_1    = @"\\w+ ?<(\\w+)>";
NSUInteger const krProtocol_name = 1;

#pragma mark - Structs
// Find unknown structs
// Assumes: structs will not contain any objects said to conform to a protocol or with any special keywords
NSString * const krStructUnknown_1_2     = @"(?:typedef )?struct (\\w+) \\{(?:\\s*\\w+(?: \\w+)?(?: ?\\* ?| )\\w+ ?(?:: ?\\d)?;)+\\s*\\}(?: (\\w+))? ?;";
NSUInteger const krStructUnknown_type    = 1;
NSUInteger const krStructUnknown_typedef = 2;

/// Replacing expanded structs by name
NSString * const krStructKnown = @"struct (%@) \\{(?:\\s*\\w+(?: \\w+)?(?: ?\\* ?| )[\\w\\d]+ ?(?:: ?\\d)?;)+\\s*\\} ?;";

/// Find empty structs in file
NSString * const krEmptyStruct_1    = @"struct (\\w+) *\\{ *\\}";
NSUInteger const krEmptyStruct_type = 1;
NSString * const krKnownStructs     = @"CGPoint|CGSize|CGRect|UIEdgeInsets|UIEdgeRect|NSRange|NSRect|CATransform3D";


#pragma mark - Properties, methods, and instance variables -

#pragma mark Properties
/// Find properties
NSString * const krProperty_12   = @"@property ?(?:\\((?:[\\w,:= ]+)+\\) ?)?((?:\\w+(?: ?<\\w+>)?|(?:\\w+ )+)(?: ?\\*)?) ?([\\w\\d]+) ?;";
NSUInteger const krProperty_type = 1;
NSUInteger const krProperty_name = 2;

/// Find setter in a property string
NSString * const krPropertySetter_1    = @"@property ?(?:\\((?:[\\w,= ]+, ?)?setter=(\\w+:)(?:[\\w,= ]+)?\\) ?)?";
NSUInteger const krPropertySetter_name = 1;
/// Find getter in a property string
NSString * const krPropertyGetter_1    = @"@property ?(?:\\((?:[\\w,:= ]+, ?)?getter=(\\w+)(?:[\\w,:= ]+)?\\) ?)?";
NSUInteger const krPropertyGetter_name = 1;
/// Whether the property contains readonly
NSString * const krPropertyIsReadonly_1 = @"@property ?\\([\\w,:= ]+readonly[\\w,:= ]*\\)";
/// Whether the property is a class property
NSString * const krPropertyIsClass_1 = @"@property ?\\([\\w,:= ]+class[\\w,:= ]*\\)";
/// Whether the property contains retain, copy, assign
NSString * const krPropertyHasARCAttribute_1 = @"@property ?\\([\\w,:= ]+(copy|assign|retain)[\\w,:= ]*\\)";

#pragma mark Methods
// Find methods

#pragma mark Instance variables
/// Find the group of ivars
NSString * const krIvarsPresent_1     = @"@interface \\w+ : \\w+ <(?:\\w+(?:, )?)+> \\{((?:\\s+[\\w\\s*;<>@{]+(?:} \\w+ ?;)?)+)\\s*\\}";
NSUInteger const krIvarsPresent_ivars = 1;

/// Grab parts of each ivar given a string of ivars grabbed using the krIvarsPresent_1 regex
NSString * const krIvarComponents_12 = @"\\s+((?:(?:(?:\\w+ )?\\w+)+|\\w+<[\\w, ]+>|struct \\{(?:\\s*\\w+(?: \\w+)?(?: ?\\* ?| )[\\w\\d]+ ?(?:: ?\\d)?;)+\\s*\\})(?: ?\\*)?) ?(?<= |\\*|>|})([\\w\\d]+) ?;";
NSUInteger const krIvarComponents_type = 1;
NSUInteger const krIvarComponents_name = 2;

/// Find <Protocol> *propertyorivar; in file
//NSString * const krDelegateMissingType          = @"(?:\\n +|\\(|\\) +)((<\\w+>) *\\*?)";
//NSUInteger const krDelegateMissingType_protocol = 2;
//NSUInteger const krDelegateMissingType_replace  = 1;

