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

- (void)setOutputDirectory:(NSString *)outputDirectory;

@end
