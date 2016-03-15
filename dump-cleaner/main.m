//
//  main.m
//  dump-cleaner
//
//  Created by Tanner Bennett on 3/13/16.
//  Copyright © 2016 Tanner Bennett. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+Regex.h"


NSString * const kMessage = @"Usage: dumpcleaner [-iscpPrv] directory\n\t-i\tKeep property-backing ivars\n\t-s\tImport parent class (if available)\n\t-c\tImport used classes in the same directory\n\t-P\tDo not generate forward declarations for protocols\n\t-p\tRemove protocol conformities from class interfaces\n\t-r\tRecursive\n\t-v\tVerbose\n";

NSString * const krStruct = @"struct (CGPoint|CGSize|CGRect|UIEdgeInsets|UIEdgeRect|NSRange|NSRect|CATransform3D) \\{(?:\\s*\\w+ \\w+;)+\\s*\\}";
NSUInteger const krStruct_type = 1;
NSString * const krEmptyStruct = @"struct (\\w+) *\\{ *\\}";
NSUInteger const krEmptyStruct_type = 1;
NSString * const krProperty = @"@property ?(?:\\((?:[\\w, =:]+)+\\) ?)?((?:\\w+(?: ?<\\w+>)?|\\w+ \\w+)(?: ?\\*)?) ?(\\w+);";
NSUInteger const krProperty_type = 1;
NSUInteger const krProperty_name = 2;
NSString * const krIvarsPresent = @"@interface \\w+ : \\w+ <(?:\\w+(?:, )?)+>( \\{(?:[\\s]+[\\w\\s*;<>]+)+\\})";
NSString * const krSupeclass = @"@interface \\w+ : (\\w+)";
NSUInteger const krSupeclass_name = 1;
NSString * const krDelegateMissingType = @"(?:\\n +|\\(|\\) +)((<\\w+>) *\\*?)";
NSUInteger const krDelegateMissingType_type = 2;
NSUInteger const krDelegateMissingType_replace = 1;
NSString * const krProtocol = @"\\w+ ?<(\\w+)>";
NSUInteger const krProtocol_name = 1;
NSString * const krConformedProtocols = @"@interface \\w+ : \\w+( <[\\w, ]+>)";
NSUInteger const krConformedProtocols_value = 1;


typedef NS_OPTIONS(NSUInteger, DCOptions) {
    DCOptionsKeepPropertyIVars        = 1 << 0,
    DCOptionsImportSuperclass         = 1 << 1,
    DCOptionsImportAvailibleClasses   = 1 << 2,
    DCOptionsForwardDeclareProtocols  = 1 << 3,
    DCOptionsRemoveConformedProtocols = 1 << 4,
    DCOptionsRecursive                = 1 << 5,
    DCOptionsVerbose                  = 1 << 6
};

NSArray * DCArgsFromCharPtr(const char **vargs, int c);
NSString * DCValueForArgument(NSString *param, NSArray *args);
NSString * DCGetFlags(NSArray *args);
NSString * DCGetDirectory(NSArray *args, NSString *allowedFlags, NSString *givenFlags);
NSString * DCRemoveQuotes(NSString *str);
NSArray * DCFilesInDirectory(NSString *path, BOOL recursive);
void DCProcessFile(NSString *path, NSArray *otherFilePaths, DCOptions options, NSMutableArray *errors);
BOOL DCPathIsDirectory(NSString *path);
NSString * DCRelativePathForClassFile(NSString *class, NSString *currentPath, NSArray *otherFilePaths);
DCOptions DCOptionsFromString(NSString *flags);

#define TESTING 1

int main(int argc, const char * argv[]) {
    @autoreleasepool {
#if !TESTING
        if (argc < 2) {
            printf("%s", kMessage.UTF8String);
            return 0;
        }
        
        NSArray *args = DCArgsFromCharPtr(argv, argc);
#else
        NSArray *args = @[@"exe", @"-scprv", @"/opt/theos/include/ChatKit.framework"];
#endif
        NSString *flags = DCGetFlags(args);
        
        // Get absolute path to working folder
        NSString *directory = DCGetDirectory(args, @"iscpPrv", flags);
        if (!directory.isAbsolutePath) {
            directory = [NSURL URLWithString:directory relativeToURL:[NSURL fileURLWithPath:[NSFileManager defaultManager].currentDirectoryPath]].absoluteString;
            directory = [directory stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        }
        
        DCOptions options = DCOptionsFromString(flags);
        
        // Process files
        NSArray *filePaths = DCFilesInDirectory(directory, options & DCOptionsRecursive);
        NSMutableArray *errors = [NSMutableArray array];
        for (NSString *path in filePaths) {
            DCProcessFile(path, filePaths, options, errors);
            
            if (options & DCOptionsVerbose)
                printf("Processed file: %s\n", path.lastPathComponent.UTF8String);
        }
        
        if (errors.count) {
            printf("There were some errors:\n\n");
            for (NSError *error in errors)
                printf("%s\n\n", error.localizedDescription.UTF8String);
        }
    }
    
    return 0;
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
        printf("%s%s", [NSString stringWithFormat:@"\tUnknown flags: %@\n\n", unknownFlags].UTF8String, kMessage.UTF8String);
        exit(0);
    }
    
    // Remove all flags, should only have directory left
    args = [args filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *arg, NSDictionary<NSString *,id> *bindings) {
        return ![arg hasPrefix:@"-"];
    }]];
    if (args.count > 2) {
        printf("\tToo many arguments\n\n%s\n\n%s", args.description.UTF8String, kMessage.UTF8String);
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
        return !DCPathIsDirectory(item) && [item hasSuffix:@".h"];
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

void DCProcessFile(NSString *path, NSArray *otherFilePaths, DCOptions options, NSMutableArray *errors) {
    NSError *error = nil;
    NSMutableString *fileContents = [NSMutableString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        [errors addObject:error];
    } else {
        // Replace "unsigned int" and "unsigned long" with NSUInteger
        [fileContents replaceOccurrencesOfString:@"unsigned int" withString:@"NSUInteger" options:0 range:NSMakeRange(0, fileContents.length)];
        [fileContents replaceOccurrencesOfString:@"unsigned long" withString:@"NSUInteger" options:0 range:NSMakeRange(0, fileContents.length)];
        
        // Replace full structs with their types
        [fileContents replaceOccurrencesOfString:krStruct withString:@"$1" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
        
        // Remove NSObject overrides
        // hash, class, superclass, description, debugDescription, etc
        static NSArray *regexes = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            regexes = @[@"- \\(NSUInteger\\)hash; ?\n", @"- \\(id\\)class; ?\n", @"- \\(id\\)superclass; ?\n", @"- \\(id\\)description; ?\n", @"- \\(id\\)debugDescription; ?\n"];
        });
        for (NSString *expr in regexes)
            [fileContents replaceOccurrencesOfString:expr withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
        
        // Import parent class
        if (options & DCOptionsImportSuperclass) {
            NSString *superclass = [fileContents matchGroupAtIndex:krSupeclass_name forRegex:krSupeclass];
            NSString *relativePath = DCRelativePathForClassFile(superclass, path, otherFilePaths);
            if (relativePath) {
                NSString *import = [NSString stringWithFormat:@"#import \"%@\"\n", relativePath];
                if (![fileContents containsString:import])
                    [fileContents insertString:import atIndex:0];
            }
        }
        
        // Fix "id<protocol> foo" where id is missing
        NSArray<NSString*> *hiccups = [fileContents allMatchesForRegex:krDelegateMissingType atIndex:krDelegateMissingType_type];
        NSArray<NSValue*>  *ranges  = [fileContents rangesForAllMatchesForRegex:krDelegateMissingType atIndex:krDelegateMissingType_replace];
        int i = 0, offset = 0;
        for (NSString *protocol in hiccups) {
            NSString *replacement = [[@"id" stringByAppendingString:protocol] stringByAppendingString:@" "];
            NSRange r = ranges[i++].rangeValue;
            r.location += offset;
            offset += replacement.length - r.length;
            [fileContents replaceCharactersInRange:r withString:replacement];
        }
        
        // Fix empty struct refs, ie "struct __CFBinaryHeap { }*"
        NSArray *emptyStructs = [fileContents allMatchesForRegex:krEmptyStruct atIndex:krEmptyStruct_type];
        ranges = [fileContents rangesForAllMatchesForRegex:krEmptyStruct atIndex:0];
        i = 0, offset = 0;
        for (NSString *structType in emptyStructs) {
            NSString *replacement = [structType stringByReplacingOccurrencesOfString:@"__" withString:@""];
            NSRange r = ranges[i++].rangeValue;
            r.location += offset;
            offset += replacement.length - r.length;
            [fileContents replaceCharactersInRange:r withString:replacement];
        }
        
        // Remove property getters and setters
        NSArray *properties = [fileContents allMatchesForRegex:krProperty atIndex:krProperty_name];
        NSArray *types = [fileContents allMatchesForRegex:krProperty atIndex:krProperty_type];
        assert(properties.count == types.count);
        i = 0;
        for (NSString *property in properties) {
            NSString *type = types[i++];
            
            // Hacky but it'll do for 99% of classes
            if (([type containsString:@"*"] && ![type hasPrefix:@"char"]) || [type allMatchesForRegex:krProtocol atIndex:krProtocol_name].count) {
                NSString *regex = [NSString stringWithFormat:@"- \\(void\\)set%@:\\(id\\)\\w+;\n", property.pascalCaseString];
                [fileContents replaceOccurrencesOfString:regex withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
                regex = [NSString stringWithFormat:@"- \\(id\\)%@;\n", property];
                [fileContents replaceOccurrencesOfString:regex withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
            } else {
                NSString *regex = [NSString stringWithFormat:@"- \\(void\\)set%@:\\(%@\\)\\w+;\n", property.pascalCaseString, type];
                [fileContents replaceOccurrencesOfString:regex withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
                regex = [NSString stringWithFormat:@"- \\(%@\\)%@;\n", type, property];
                [fileContents replaceOccurrencesOfString:regex withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
            }
            
            if (!(options & DCOptionsKeepPropertyIVars)) {
                type = [type stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
                NSString *regex = [NSString stringWithFormat:@" +%@ ?_%@;\n", type, property];
                [fileContents replaceOccurrencesOfString:regex withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
                
                // Remove empty braces
                [fileContents replaceOccurrencesOfString:@" \\{\\n\\}" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, fileContents.length)];
            }
        }
        
        // Forward protocols
        if (options & DCOptionsForwardDeclareProtocols) {
            NSArray *protocols = [fileContents allMatchesForRegex:krProtocol atIndex:krProtocol_name];
            protocols = [NSSet setWithArray:protocols].allObjects;
            if (protocols.count) {
                NSMutableString *forward = [NSMutableString stringWithString:@"@protocol "];
                for (NSString *proto in protocols)
                    [forward appendFormat:@"%@, ", proto];
                [forward replaceCharactersInRange:NSMakeRange(forward.length-2, 2) withString:@";\n"];
                if (![fileContents containsString:forward])
                    [fileContents insertString:forward atIndex:0];
            }
        }
        
        // Remove conformed protocols
        if (options & DCOptionsRemoveConformedProtocols) {
            NSRange r = [fileContents rangesForAllMatchesForRegex:krConformedProtocols atIndex:krConformedProtocols_value].firstObject.rangeValue;
            [fileContents replaceCharactersInRange:r withString:@""];
        }
        
        // Import possible classes
        if (options & DCOptionsImportAvailibleClasses) {
            NSArray *classes = [fileContents allMatchesForRegex:@"(\\w+) ?\\* ?\\w+;" atIndex:1];
            for (NSString *missingClass in classes) {
                NSString *relativePath = DCRelativePathForClassFile(missingClass, path, otherFilePaths);
                if (relativePath) {
                    NSString *import = [NSString stringWithFormat:@"#import \"%@\"\n", relativePath];
                    if (![fileContents containsString:import])
                        [fileContents insertString:import atIndex:0];
                }
            }
        }
        
        // Save changes
        [fileContents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
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
    if ([flags containsString:@"i"])
        options |= DCOptionsKeepPropertyIVars;
    if ([flags containsString:@"s"])
        options |= DCOptionsImportSuperclass;
    if ([flags containsString:@"c"])
        options |= DCOptionsImportAvailibleClasses;
    if ([flags containsString:@"p"])
        options |= DCOptionsForwardDeclareProtocols;
    if ([flags containsString:@"P"])
        options |= DCOptionsRemoveConformedProtocols;
    if ([flags containsString:@"r"])
        options |= DCOptionsRecursive;
    if ([flags containsString:@"v"])
        options |= DCOptionsVerbose;
    
    return options;
}













