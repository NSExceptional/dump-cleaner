//
//  dump-cleaner-constants.m
//  dump-cleaner
//
//  Created by Tanner on 3/20/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "dump-cleaner-constants.h"


NSString * const kUsage = @"Usage: dumpcleaner [-fxrv] [-s path] <directory|file>\n\t-s\t<path>\tSpecify the path to the SDK to use\n\t-f\tSpecify a single file to clean instead of a directory\n\t-x\tDon\'t use an SDK, just sanitize using the headers in the current directory\n\t-r\tRecursive\n\t-v\tVerbose\n";

/// Find structs in file
NSString * const krStruct      = @"struct (%@) \\{(?:\\s*\\w+ \\w+;)+\\s*\\}";
NSUInteger const krStruct_type = 1;
/// Find empty structs in file
NSString * const krEmptyStruct      = @"struct (\\w+) *\\{ *\\}";
NSUInteger const krEmptyStruct_type = 1;
NSString * const krKnownStructs     = @"CGPoint|CGSize|CGRect|UIEdgeInsets|UIEdgeRect|NSRange|NSRect|CATransform3D";

/// Find properties in file
NSString * const krProperty       = @"@property ?(?:\\((?:[\\w,:= ]+)+\\) ?)?((?:\\w+(?: ?<\\w+>)?|(?:\\w+ )+)(?: ?\\*)?) ?(\\w+);";
NSUInteger const krProperty_type  = 1;
NSUInteger const krProperty_name  = 2;
/// Find setter in a property string
NSString * const krPropertySetter = @"@property ?(?:\\((?:[\\w,= ]+, ?)?setter=(\\w+:)(?:[\\w,= ]+)?\\) ?)?";
NSUInteger const krPropertySetter_name = 1;
/// Find getter in a property string
NSString * const krPropertyGetter = @"@property ?(?:\\((?:[\\w,:= ]+, ?)?getter=(\\w+)(?:[\\w,:= ]+)?\\) ?)?";
NSUInteger const krPropertyGetter_name = 1;
/// Whether the property contains readonly
NSString * const krPropertyIsReadonly = @"@property ?\\([\\w,:= ]+readonly[\\w,:= ]*\\)";
/// Whether the property contains retain, copy, assign
NSString * const krPropertyHasARCAttribute = @"@property ?\\([\\w,:= ]+(copy|assign|retain)[\\w,:= ]*\\)";
/// Find the group of ivars 
NSString * const krIvarsPresent       = @"@interface \\w+ : \\w+ <(?:\\w+(?:, )?)+> \\{((?:[\\s]+[\\w\\s*;<>]+)+)\\}";
NSUInteger const krIvarsPresent_ivars = 1;

/// Grab parts of each ivar given a string of ivars grabbed using the krIvarsPresent regex
NSString * const krIvarComponents = @"\\s+((?:(?:\\w+ +)+|\\w+<[\\w, ]+> ?)\\*?) ?(\\w+);";
NSUInteger const krIvarComponents_type = 1;
NSUInteger const krIvarComponents_name = 2;

/// Find superclass in file
NSString * const krSupeclass      = @"@interface \\w+ : (\\w+)";
NSUInteger const krSupeclass_name = 1;

/// Find <Protocol> *propertyorivar; in file
NSString * const krDelegateMissingType          = @"(?:\\n +|\\(|\\) +)((<\\w+>) *\\*?)";
NSUInteger const krDelegateMissingType_protocol = 2;
NSUInteger const krDelegateMissingType_replace  = 1;

/// Find any protocol in file
NSString * const krProtocol                 = @"\\w+ ?<(\\w+)>";
NSUInteger const krProtocol_name            = 1;
/// Find interface-conformed protocols in file
NSString * const krConformedProtocols       = @"@interface \\w+ ?: ?\\w+ ?<([\\w, ]+)>";
NSUInteger const krConformedProtocols_value = 1;

NSString * const krImportStatement = @"#import [\"<][\\w./+-]+[>\"]";