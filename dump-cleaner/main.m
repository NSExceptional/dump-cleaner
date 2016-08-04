//
//  main.m
//  dump-cleaner
//
//  Created by Tanner Bennett on 3/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#include <getopt.h>
#import "DCSDK.h"


typedef NS_OPTIONS(NSUInteger, DCOptions) {
    DCOptionsVerbose = 1 << 0
};

NSArray * DCArgsFromCharPtr(const char **vargs, int c);
NSString * DCValueForArgument(NSString *param, NSArray *args);
NSString * DCGetFlags(NSArray *args);
NSString * DCGetDirectory(NSArray *args, NSString *allowedFlags, NSString *givenFlags);
NSString * DCRemoveQuotes(NSString *str);
NSArray * DCFilesInDirectory(NSString *path, BOOL recursive);
BOOL DCPathIsDirectory(NSString *path);
NSString * DCRelativePathForClassFile(NSString *class, NSString *currentPath, NSArray *otherFilePaths);
DCOptions DCOptionsFromString(NSString *flags);

void chooseFromExistingFrameworks(NSString *inputLoc, NSString *outputLoc);

#define TESTING 1

int main(int argc, const char * argv[]) {
    @autoreleasepool {
#if !TESTING
        if (argc < 3) {
            DCLog(kUsage);
            return 0;
        }
        
        NSArray *args = DCArgsFromCharPtr(argv, argc);
#else
        NSArray *args = @[@".", @"/Users/tantan/Desktop/dumped/System/Library/Frameworks", @"/Users/tantan/Desktop/"];
#endif
        NSString *inputLoc  = args[args.count-2];
        NSString *outputLoc = args[args.count-1];
        
        //        NSString *flags     = DCGetFlags(args.copy);
        //        DCOptions options = DCOptionsFromString(flags);
        
        // Get absolute path to working folder
        //        NSString *directory = DCGetDirectory(args, @"v", flags);
        //        if (!directory.isAbsolutePath) {
        //            directory = [NSURL URLWithString:directory relativeToURL:[NSURL fileURLWithPath:[NSFileManager defaultManager].currentDirectoryPath]].path;
        //        }
        
        // User choose from available SDKs
        chooseFromExistingFrameworks(inputLoc, outputLoc);
    }
    
    return 0;
}

void chooseFromExistingFrameworks(NSString *inputLoc, NSString *outputLoc) {
    
    // Get available SDKs, compile choice list
    NSDictionary *SDKs = [DCSDK availableSDKs];
    NSMutableString *choose = [NSMutableString stringWithString:@"Dump cleaner\n------------\n"];
    int i = 1;
    for (NSString *sdk in SDKs.allKeys)
        [choose appendFormat:@"  [%d.]\t %@\n", i++, sdk];
    [choose appendFormat:@"Choose an SDK to use: "];
    
    // Make sure they choose a valid option
    NSInteger choice = 0;
    while (!NSLocationInRange(choice, NSMakeRange(1, SDKs.count))) {
        DCLog(choose);
        NSString *option = [NSString stringWithUTF8String:[NSFileHandle fileHandleWithStandardInput].availableData.bytes];
        choice = option.integerValue;
    }
    
    // Start progress bar
    DCProgressBar *progress = [DCProgressBar currentProgress];
    progress.verbosity = 1;
    [progress start];
    
    // Start processing
    DCSDK *sdk = [DCSDK SDKAtPath:SDKs[SDKs.allKeys[choice-1]]];
    [sdk processFrameworksInDirectory:inputLoc andOutputTo:outputLoc];
    [progress stop];
    DCLog(@"Done");
}

NSArray * DCArgsFromCharPtr(const char **vargs, int c) {
    NSMutableArray *m = [NSMutableArray array];
    
    for (int i = 0; i < c; i++)
        [m addObject:@(vargs[i])];
    
    return m;
}

NSString * DCValueForArgument(NSString *param, NSArray *args) {
    for (int i = 1; i < args.count; i++)
        if ([param isEqualToString:args[i-1]])
            return args[i];
    return nil;
}

NSString * DCGetFlags(NSArray *args) {
    NSMutableString *flags = [NSMutableString string];
    for (NSString *arg in args)
        if ([arg hasPrefix:@"-"])
            [flags appendString:arg];
    
    [flags replaceOccurrencesOfString:@"-" withString:@"" options:0 range:NSMakeRange(0, flags.length)];
    return flags.copy;
}

NSString * DCGetDirectory(NSArray *args, NSString *allowedFlags, NSString *givenFlags) {
    // Check for allowed flags
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:allowedFlags];
    NSString *unknownFlags = [givenFlags stringByTrimmingCharactersInSet:allowed];
    if (unknownFlags.length) {
        printf("%s%s", [NSString stringWithFormat:@"\tUnknown flags: %@\n\n", unknownFlags].UTF8String, kUsage.UTF8String);
        exit(0);
    }
    
    // Remove all flags, should only have directory left
    args = [args filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *arg, NSDictionary<NSString *,id> *bindings) {
        return ![arg hasPrefix:@"-"];
    }]];
    if (args.count > 2) {
        printf("\tToo many arguments\n\n%s\n\n%s", args.description.UTF8String, kUsage.UTF8String);
        exit(0);
    }
    
    return DCRemoveQuotes(args.lastObject);
}

NSString * DCRemoveQuotes(NSString *str) {
    if ([str hasPrefix:@"\""] && [str hasSuffix:@"\""])
        return [str substringWithRange:NSMakeRange(1, str.length-1)];
    return str;
}

NSArray * DCFilesInDirectory(NSString *path, BOOL recursive) {
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    if (error) {
        printf("%s\n", error.localizedDescription.UTF8String);
        return nil;
    }
    
    // Add leading path to file names
    NSMutableArray *full = [NSMutableArray array];
    for (NSString *p in contents)
        [full addObject:[path stringByAppendingPathComponent:p]];
    contents = full.copy;
    
    NSMutableArray *files = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *item, NSDictionary<NSString *,id> *bindings) {
        return !DCPathIsDirectory(item) && [item.pathExtension isEqualToString:@"h"];
    }]].mutableCopy;
    
    if (recursive) {
        NSArray *directories = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *item, NSDictionary<NSString *,id> *bindings) {
            return DCPathIsDirectory(item);
        }]];
        
        for (NSString *directory in directories)
            [files addObjectsFromArray:DCFilesInDirectory(directory, YES)];
    }
    
    return files.copy;
}

BOOL DCPathIsDirectory(NSString *path) {
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        return isDirectory;
    }
    
    return NO;
}

NSString * DCRelativePathForClassFile(NSString *class, NSString *currentPath, NSArray *otherFilePaths) {
    // Foo = Foo.h
    class = [class stringByAppendingString:@".h"];
    for (NSString *file in otherFilePaths) {
        // ~/path/to/Foo.h = Foo.h
        NSString *filename = file.lastPathComponent;
        
        if ([filename isEqualToString:class]) {
            // grab !/path/to/with/intermediate/dirs/, then get Foo.h
            NSString *absolutePathPrefix = [currentPath stringByReplacingOccurrencesOfString:currentPath.lastPathComponent withString:@""];
            if ([file containsString:absolutePathPrefix]) {
                NSString *relativePath = [file stringByReplacingOccurrencesOfString:absolutePathPrefix withString:@""];
                if ([relativePath hasPrefix:@"/"])
                    relativePath = [relativePath stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                
                return relativePath;
            } else {
                return nil;
            }
        }
    }
    
    return nil;
}

DCOptions DCOptionsFromString(NSString *flags) {
    DCOptions options;
    
    return options;
}













