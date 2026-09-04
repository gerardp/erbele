#import "FRAArchive.h"
#import "FRAPasteboard.h"
#import "FRAPrintTextView.h"
#import <PDFKit/PDFKit.h>
#include <assert.h>

// Exercise the real print view without opening projects or modifying an application session.
@interface FRAProjectsController : NSDocumentController
@end
@implementation FRAProjectsController
+ (id)sharedDocumentController { return nil; }
@end

static NSData *Archive(id value)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:&error];
    assert(data && !error);
    return data;
}

static BOOL SamePreference(id first, id second)
{
    if ([first isKindOfClass:[NSColor class]] && [second isKindOfClass:[NSColor class]]) {
        NSColor *a = [first colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        NSColor *b = [second colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        return a && b && fabs(a.redComponent - b.redComponent) < 0.0001 &&
            fabs(a.greenComponent - b.greenComponent) < 0.0001 &&
            fabs(a.blueComponent - b.blueComponent) < 0.0001 && fabs(a.alphaComponent - b.alphaComponent) < 0.0001;
    }
    return [first isEqual:second];
}

int main(int argc, const char *argv[])
{
    assert(argc == 2);
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:@"FRAPreferenceArchiveTransformer"];
        assert(transformer && [[transformer class] allowsReverseTransformation]);
        NSArray *preferences = @[[NSFont fontWithName:@"Menlo" size:11],
                                 [NSFont fontWithName:@"Courier" size:10],
                                 [NSColor textColor], [NSColor whiteColor],
                                 [NSColor colorWithCalibratedRed:0.15 green:0.26 blue:0.08 alpha:1]];
        for (id preference in preferences) {
            NSData *modern = [transformer reverseTransformedValue:preference];
            assert(modern);
            assert(SamePreference([transformer transformedValue:modern], preference));
            assert(SamePreference([FRAPreferenceArchiveTransformer unarchiveObjectWithData:modern], preference));
        }
        assert([transformer transformedValue:[NSData data]] == nil);
        assert([transformer transformedValue:nil] == nil);
        assert([transformer transformedValue:Archive(@"wrong preference type")] == nil);

        // Fixed typedstream samples from an old font preference and an empty project.
        NSData *legacyFont = [[NSData alloc] initWithBase64EncodedString:@"BAtzdHJlYW10eXBlZIHoA4QBQISEhAZOU0ZvbnQehIQITlNPYmplY3QAhYQBaSSEBVszNmNdBgAAABwAAAD//k0AZQBuAGwAbwAtAFIAZQBnAHUAbABhAHIAhAFmC4QBYwCYAZgAmACG" options:0];
        NSData *legacyProject = [[NSData alloc] initWithBase64EncodedString:@"BAtzdHJlYW10eXBlZIHoA4QBQISEhAxOU0RpY3Rpb25hcnkAhIQITlNPYmplY3QAhYQBaQKShISECE5TU3RyaW5nAZSEASsOZG9jdW1lbnRzQXJyYXmGkoSEhAdOU0FycmF5AJSVAIaShJaXB3ZlcnNpb26GkoSEhAhOU051bWJlcgCEhAdOU1ZhbHVlAJSEASqElZUDhoY=" options:0];
        assert([transformer transformedValue:legacyFont] == nil);
        NSError *legacyError = nil;
        assert(!FRAReadProjectArchive(legacyProject, &legacyError) && legacyError);

        NSString *suite = [@"org.erbele.archive-check." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSData *fontData = Archive(preferences[0]);
        NSData *colourData = Archive([NSColor redColor]);
        NSDictionary *initialValues = @{@"TextFont": fontData, @"PrintFont": fontData,
                                        @"TextColourWell": Archive([NSColor blackColor]),
                                        @"BackgroundColourWell": Archive([NSColor whiteColor]), @"TabWidth": @4};
        [defaults setObject:legacyFont forKey:@"TextFont"];
        [defaults setObject:colourData forKey:@"PrintFont"];
        [defaults setObject:[NSData data] forKey:@"TextColourWell"];
        [defaults setObject:colourData forKey:@"BackgroundColourWell"];
        [defaults setInteger:8 forKey:@"TabWidth"];
        NSUserDefaultsController *controller = [[NSUserDefaultsController alloc] initWithDefaults:defaults initialValues:initialValues];
        [FRAPreferenceArchiveTransformer resetUnsupportedPreferencesInController:controller];
        for (NSString *key in @[@"TextFont", @"PrintFont", @"TextColourWell"]) {
            assert([[controller.values valueForKey:key] isEqual:initialValues[key]]);
        }
        assert([[controller.values valueForKey:@"BackgroundColourWell"] isEqual:colourData]);
        assert([defaults integerForKey:@"TabWidth"] == 8);
        [defaults removePersistentDomainForName:suite];

        NSDictionary *document = @{@"path": @"/tmp/example.txt", @"encoding": @4,
                                   @"sortOrder": @0, @"selectedRange": @"{1, 2}"};
        NSArray *version2 = @[document];
        NSDictionary *version3 = @{@"documentsArray": version2, @"version": @3,
                                   @"windowFrame": @"{{0, 0}, {800, 600}}", @"viewSize": @100,
                                   @"view": @0, @"dividerPosition": @0.2, @"selectedDocumentName": @"example.txt"};
        for (id project in @[version2, version3]) {
            NSError *error = nil;
            assert([FRAReadProjectArchive(Archive(project), &error) isEqual:project] && !error);
        }
        NSError *error = nil;
        assert(!FRAReadProjectArchive(Archive(@{@"documentsArray": @[@{@"path": @42}]}), &error) && error);
        assert(!FRAReadProjectArchive([@"damaged archive" dataUsingEncoding:NSUTF8StringEncoding], &error) && error);

        NSArray *collection = @[@{@"name": @"Example", @"text": @"echo hello", @"collectionName": @"Commands",
                                  @"shortcutDisplayString": @"", @"shortcutMenuItemKeyString": @"",
                                  @"shortcutModifier": @0, @"sortOrder": @0, @"version": @3,
                                  @"inline": @YES, @"interpreter": @"/bin/sh"}];
        // Earlier exports were keyed archives without requiring secure coding.
        NSData *oldCollection = [NSKeyedArchiver archivedDataWithRootObject:collection requiringSecureCoding:NO error:&error];
        assert([FRAReadCollectionArchive(oldCollection, &error) isEqual:collection] && !error);
        assert([FRAReadCollectionArchive(Archive(collection), &error) isEqual:collection] && !error);
        assert(!FRAReadCollectionArchive(Archive(@[@"not a record"]), &error) && error);
        assert(!FRAReadCollectionArchive(Archive(@[@{@"name": @"Bad", @"text": @42, @"collectionName": @"Bad"}]), &error) && error);
        assert(!FRAReadCollectionArchive(legacyProject, &error) && error);

        NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
        NSArray *urls = @[[NSURL fileURLWithPath:@"/tmp/a file.txt"], [NSURL fileURLWithPath:@"/tmp/ñ.txt"]];
        assert([pasteboard writeObjects:urls]);
        assert([FRAFilePathsFromPasteboard(pasteboard) isEqual:[urls valueForKey:@"path"]]);
        [pasteboard clearContents];
        assert([pasteboard writeObjects:@[[NSURL URLWithString:@"https://example.com/file.txt"]]]);
        assert(FRAFilePathsFromPasteboard(pasteboard).count == 0);

        NSString *type = @"org.erbele.dragged-document";
        NSMutableArray *items = [NSMutableArray array];
        NSArray *indices = @[@1, @3];
        for (NSNumber *row in indices) {
            NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
            NSString *uri = [NSString stringWithFormat:@"x-coredata://store/Document/p%@", row];
            [item setPropertyList:@{@"row": row, @"uri": uri} forType:type];
            [item setString:row.stringValue forType:NSPasteboardTypeString];
            [items addObject:item];
        }
        [pasteboard clearContents];
        assert([pasteboard writeObjects:items]);
        NSArray *dragged = FRADraggedObjectsFromPasteboard(pasteboard, type);
        NSIndexSet *rows = dragged[0];
        assert(rows.count == 2 && [rows containsIndex:1] && [rows containsIndex:3]);
        assert([dragged[1] count] == 2);
        assert([[dragged[1][1] absoluteString] isEqual:@"x-coredata://store/Document/p3"]);
        assert([[pasteboard stringForType:NSPasteboardTypeString] isEqual:@"1\n3"]);
        assert(!FRADraggedObjectsFromPasteboard(pasteboard, @"org.erbele.dragged-snippet"));
        // The row writer places concatenated snippet text on one item to preserve whitespace.
        NSPasteboardItem *firstSnippet = [[NSPasteboardItem alloc] init];
        NSPasteboardItem *secondSnippet = [[NSPasteboardItem alloc] init];
        NSString *snippetType = @"org.erbele.dragged-snippet";
        [firstSnippet setPropertyList:@{@"row": @1, @"uri": @"x-coredata://store/Snippet/p1"} forType:snippetType];
        [secondSnippet setPropertyList:@{@"row": @3, @"uri": @"x-coredata://store/Snippet/p3"} forType:snippetType];
        [firstSnippet setString:@"firstsecond" forType:NSPasteboardTypeString];
        [pasteboard clearContents];
        assert(([pasteboard writeObjects:@[firstSnippet, secondSnippet]]));
        assert([[pasteboard stringForType:NSPasteboardTypeString] isEqual:@"firstsecond"]);
        assert([FRADraggedObjectsFromPasteboard(pasteboard, snippetType)[1] count] == 2);
        for (id invalid in @[@"not a record", @{@"row": @-1, @"uri": @"x-coredata://store/Document/p1"},
                             @{@"row": @1, @"uri": @"https://example.com"}]) {
            NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
            [item setPropertyList:invalid forType:type];
            [pasteboard clearContents];
            assert([pasteboard writeObjects:@[item]]);
            assert(!FRADraggedObjectsFromPasteboard(pasteboard, type));
        }
        [pasteboard releaseGlobally];

        [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:
            @{@"PrintHeader": @YES, @"PrintFont": Archive([NSFont fontWithName:@"Courier" size:10]),
              @"MarginsMin": @24, @"TabWidth": @4}];
        FRAPrintTextView *view = [[FRAPrintTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 700)];
        [view setString:@"Print body check"];
        NSURL *pdfURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSPrintInfo *info = [[NSPrintInfo alloc] initWithDictionary:
            @{NSPrintJobDisposition: NSPrintSaveJob, NSPrintJobSavingURL: pdfURL}];
        NSPrintOperation *operation = [NSPrintOperation printOperationWithView:view printInfo:info];
        operation.showsPrintPanel = NO;
        operation.showsProgressPanel = NO;
        assert([operation runOperation]);
        PDFDocument *pdf = [[PDFDocument alloc] initWithURL:pdfURL];
        assert([pdf.string containsString:@"Print body check"] && [pdf.string containsString:@"·"]);
        PDFPage *page = [pdf pageAtIndex:0];
        NSRect pageBounds = [page boundsForBox:kPDFDisplayBoxMediaBox];
        NSRect headerBounds = [[pdf findString:@"·" withOptions:0][0] boundsForPage:page];
        assert(NSContainsRect(pageBounds, headerBounds));
        assert(NSMinY(headerBounds) > NSMaxY(pageBounds) - 50);
        puts("Archive validation, preference recovery, pasteboard, and print header checks passed.");
    }
    return 0;
}
