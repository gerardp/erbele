#import "FRAPasteboard.h"

NSArray<NSString *> *FRAFilePathsFromPasteboard(NSPasteboard *pasteboard)
{
    NSArray<NSURL *> *urls = [pasteboard readObjectsForClasses:@[[NSURL class]]
        options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
    return [urls valueForKey:@"path"];
}

NSArray *FRADraggedObjectsFromPasteboard(NSPasteboard *pasteboard, NSPasteboardType type)
{
    NSMutableIndexSet *rows = [NSMutableIndexSet indexSet];
    NSMutableArray<NSURL *> *uris = [NSMutableArray array];
    for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
        if (![item.types containsObject:type]) continue;
        id value = [item propertyListForType:type];
        if (![value isKindOfClass:[NSDictionary class]]) return nil;
        NSNumber *row = value[@"row"];
        NSString *uriString = value[@"uri"];
        if (![row isKindOfClass:[NSNumber class]] || row.integerValue < 0 ||
            ![uriString isKindOfClass:[NSString class]]) return nil;
        NSURL *uri = [NSURL URLWithString:uriString];
        if (![uri.scheme isEqualToString:@"x-coredata"] || [rows containsIndex:row.unsignedIntegerValue]) return nil;
        [rows addIndex:row.unsignedIntegerValue];
        [uris addObject:uri];
    }
    return uris.count ? @[rows, uris] : nil;
}
