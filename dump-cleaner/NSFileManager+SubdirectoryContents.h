//
//  NSFileManager+SubdirectoryContents.h
//  dump-cleaner
//
//  Created by Tanner on 7/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSFileManager (SubdirectoryContents)

- (NSArray<NSString*> *)filesInDirectoryAtPath:(NSString *)path recursive:(BOOL)recursive;

@end
