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
    return [_name isEqualToString:protocol.name];
}

- (NSUInteger)hash { return _name.hash; }

#pragma mark Public interface

- (NSString *)outputFile {
    if (_outputDirectory) {
        return [_outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.h", self.name]];
    }
    
    return nil;
}

@end
