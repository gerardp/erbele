#import <Cocoa/Cocoa.h>

NSArray<NSString *> *FRAFilePathsFromPasteboard(NSPasteboard *pasteboard);
NSArray *FRADraggedObjectsFromPasteboard(NSPasteboard *pasteboard, NSPasteboardType type);
