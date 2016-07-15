//
//  NSFileManager+SubdirectoryContents.m
//  dump-cleaner
//
//  Created by Tanner on 7/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import "NSFileManager+SubdirectoryContents.h"


@implementation NSFileManager (SubdirectoryContents)

- (NSArray<NSString*> *)filesInDirectoryAtPath:(NSString *)path recursive:(BOOL)recursive {
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsHiddenFiles | (recursive ? 0 : NSDirectoryEnumerationSkipsSubdirectoryDescendants);
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:path]
                                                             includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                options:options
                                                                           errorHandler:^(NSURL *url, NSError *error) {
                                                                               DCWriteError(error);
                                                                               return YES;
                                                                           }];
    NSMutableArray *files = [NSMutableArray array];
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            DCWriteError(error);
        } else if (!isDirectory.boolValue) {
            [files addObject:url.relativePath];
        }
    }
    
    return files.copy;
}

@end
