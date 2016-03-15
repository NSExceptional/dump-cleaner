# dump-cleaner
A command-line tool to tidy-up Objective-C interfaces generated with class dump tools.

Usage: `dumpcleaner [-iscpPrv] directory`

- `-i` *Keep* property-backing ivars in the interface.
- `-s` Import parent class (if available in the same directory or a subdirectory)
- `-c` Import classes used in the interface if they are in the same directory or a subdirectory
- `-P` Do not generate forward declarations for protocols
- `-p` Remove protocol conformities from class interfaces (since you cannot forward-declare these)
- `-r` Recursive
- `-v` Verbose

#What it does by default

- If properties and their respective backing-ivar are in the same interface, they will be automatically removed
- Automatically generates forward declarations for protocols
- Replaces `unsigned int` with `NSUInteger`
- Replaces inline struct definitions (i.e. `struct CGPoint { float x; float y; }`) with their name, if the name is available (this means anonymous structs are left alone)
- Fixes properties and ivars declared like `<SomeProtocol> *_ivar;`, as they should be declared like `id<SomeProtocol> _ivar;`
- Changes opaque-type structs to the opaque type (i.e. `struct __CFBinaryHeap { }*` becomes `CFBinaryHeap*`)
- Removes getters and setters for properties

#What it CAN'T do

- Fix incorrect attributes on inherited properties
- Probably some other stuff

#Todo

- Correct object properties missing `retain` / `copy` attributes to have `retain` attribute.
