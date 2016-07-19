//
//  DCProtocol.m
//  dump-cleaner
//
//  Created by Tanner on 7/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "DCProtocol.h"

@implementation DCProtocol

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[DCProtocol class]])
        return [self isEqualToDCProtocol:object];
    
    return [super isEqual:object];
}

- (BOOL)isEqualToDCProtocol:(DCProtocol *)protocol {
    return [self.name isEqualToString:protocol.name];
}

- (NSUInteger)hash { return self.name.hash; }

#pragma mark Public interface

- (NSString *)outputLocation {
    if (_outputDirectory) {
        return [_outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h", self.name]];
    }
    
    return nil;
}

- (void)setOutputDirectory:(NSString *)outputDirectory {
    NSParameterAssert(outputDirectory);
    _outputDirectory = outputDirectory;
    _importStatement = DCImportStatement(outputDirectory, self.name);
}

@end
