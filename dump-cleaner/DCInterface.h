//
//  DCInterface.h
//  dump-cleaner
//
//  Created by Tanner on 7/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCObject.h"


@class DCProtocol, DCClass;

/// Abstract base class for DCClass and DCProtocol
@protocol DCInterface <NSObject>

- (void)updateWithKnownClasses:(NSArray<DCClass*> *)classes;
- (void)updateWithKnownStructs:(NSArray *)structNames;
- (void)updateWithKnownProtocols:(NSArray<DCProtocol*> *)protocols;

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *outputFile;
@property (nonatomic, readonly) NSString *importStatement;

// Assumes output directory will end with "Foo.framework/Headers"
- (void)setOutputDirectory:(NSString *)outputDirectory;

@end

static inline NSString * DCImportStatement(NSString *outputFolder, NSString *name) {
    NSString *framework = [outputFolder matchGroupAtIndex:1 forRegex:@"(\\w+)\\.framework/Headers"];
    return [NSString stringWithFormat:@"<%@/%@.h>\n", framework, name];
}