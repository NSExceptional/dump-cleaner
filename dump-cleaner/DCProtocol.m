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
        return [self.name isEqualToString:[object name]];
    
    return [super isEqual:object];
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

#pragma mark Searching

- (BOOL)buildString {
    [super buildString];
    [_string appendFormat:@"\n\n@protocol %@", _name];
    
    // Conformed protocols
    if (self.conformedProtocols.count) {
        [_string appendString:@"<"];
        for (NSString *prot in self.conformedProtocols) {
            [_string appendFormat:@"%@, ", prot];
        }
        [_string appendString:@">"];
        [_string deleteLastCharacter];
    }
    
    // Properties and methods
    // FIXME making them all optional for now since they can't all be required all the time
    [_string appendString:@"\n\n@optinal"];
    for (DCProperty *property in self.properties)
        [_string appendFormat:@"%@\n", property];
    for (DCMethod *method in self.methods)
        [_string appendFormat:@"%@\n", method];
    
    [_string appendString:@"@end\n"];
    
    return YES;
}

- (BOOL)parseOriginalString {
    NSAssert(_orig != nil, @"_orig should be initialized here");
    NSScanner *scanner = [NSScanner scannerWithString:_orig];
    NSString *tmp = nil;
    
    ScanAssert([scanner scanString:@"@protocol"]);
    ScanAssert([scanner scanIdentifier:&tmp]);
    _name = tmp; tmp = nil;
    
    // Conformed protocols
    NSArray *protocols = nil;
    if ([scanner scanProtocolConformanceList:&protocols]) {
        self.conformedProtocols = protocols;
    }
    
    // Protocol body
    // TODO somehow make distinction between optional and required protocols
    ScanAssert([scanner scanInterfaceBody:^(NSArray<DCProperty *> *properties, NSArray<DCMethod *> *methods) {
        [self.properties addObjectsFromArray:properties];
        [self.methods addObjectsFromArray:methods];
    } isProtocol:YES]);
    
    return YES;
}

@end
