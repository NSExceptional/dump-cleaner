//
//  DCInterface.h
//  dump-cleaner
//
//  Created by Tanner on 7/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"


@class DCProtocol, DCClass, DCProperty, DCMethod;

/// Abstract base class for DCClass and DCProtocol
@interface DCInterface : DCObject {
@protected
    NSString *_orig;
    NSString *_name;
    NSString *_importStatement;
}

- (void)updateWithKnownClasses:(NSArray<DCClass*> *)classes;
- (void)updateWithKnownStructs:(NSArray *)structNames;
- (void)updateWithKnownProtocols:(NSArray<DCProtocol*> *)protocols;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *outputLocation;
@property (nonatomic, readonly) NSString *importStatement;

// Assumes output directory will end with "Foo.framework/Headers"
- (void)setOutputDirectory:(NSString *)outputDirectory;


// Internal use only //

@property (nonatomic) NSMutableArray<DCProperty*> *properties;
@property (nonatomic) NSMutableArray<DCMethod*>   *methods;
@property (nonatomic) NSMutableSet<NSString*>     *protocols;

@property (nonatomic) NSArray<NSString*>          *conformedProtocols;
@property (nonatomic) NSMutableSet<DCClass*>      *dependingClasses;
@property (nonatomic) NSMutableSet<DCProtocol*>   *dependingProtocols;

/// Sublcasses must call super
- (BOOL)buildString;
/// Sublclasses must override and not call super
- (BOOL)parseOriginalString;

@end


static inline NSString * DCImportStatement(NSString *outputFolder, NSString *name) {
    NSString *framework = [outputFolder matchGroupAtIndex:1 forRegex:@"(\\w+)\\.framework/Headers"];
    return [NSString stringWithFormat:@"<%@/%@.h>\n", framework, name];
}
