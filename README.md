# dump-cleaner
A command-line tool to tidy-up Objective-C interfaces generated with class dump tools.

Usage: `dumpcleaner [-iscpPrv] directory`

- `-i` *Keep* property-backing ivars in the interface.
- `-s` Import parent class (if available in the same directory or a subdirectory)
- `-c` Import classes used in the interface if they are in the same directory or a subdirectory
- `-p` Do not generate forward declarations for protocols
- `-P` Remove protocol conformities from class interfaces (since you cannot forward-declare these)
- `-n` *Do* forward declare NSObject protocol (as long as `-p` is not specified)
- `-r` Recursive
- `-v` Verbose

## What it does by default

- If properties and their respective backing-ivar are in the same interface, the ivars will be automatically removed
- Automatically generates forward declarations for protocols found in the interface (excluding the `NSObject` protocol)
- Replaces `unsigned int` with `NSUInteger`
- Replaces most inline struct definitions (i.e. `struct CGPoint { float x; float y; }`) with their name, if the name is available (this means anonymous structs are left alone)
- Fixes properties and ivars declared like `<SomeProtocol> *_ivar;`, as they should be declared like `id<SomeProtocol> _ivar;`
- Changes opaque-type structs to the opaque type (i.e. `struct __CFBinaryHeap { }*` becomes `CFBinaryHeap*`)
- Removes getters and setters for properties
- Removes some methods, like `hash` and `debugDescription`

## What it CAN'T do

- Fix incorrect attributes on inherited properties
- Probably some other stuff

## Todo

- Correct object properties missing `retain` / `copy` attributes to have `retain` attribute.
- Remove a distinct set of methods if present (i.e. `hash`, `cxx.destruct`, `class`, etc)
