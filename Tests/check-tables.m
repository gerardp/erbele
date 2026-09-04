#import "FRATableView.h"
#import "FRADocumentsListCell.h"
#include <assert.h>

// Isolate the table's existing application actions from real projects and collections.
@interface FRACommandsController : NSObject
@property NSTableView *commandsTableView;
@property NSTableView *commandCollectionsTableView;
@property NSArrayController *commandsArrayController;
+ (instancetype)sharedInstance;
@end
@implementation FRACommandsController
+ (instancetype)sharedInstance { static id instance; if (!instance) instance = [self new]; return instance; }
@end
@interface FRASnippetsController : NSObject @end
@implementation FRASnippetsController
+ (id)sharedInstance { return nil; }
@end
@interface FRAToolsMenuController : NSObject @end
@implementation FRAToolsMenuController
+ (id)sharedInstance { return nil; }
@end
@interface FRAProjectsController : NSObject @end
@implementation FRAProjectsController
+ (id)sharedDocumentController { return nil; }
@end

static NSEvent *Key(NSWindow *window, unichar character, unsigned short code)
{
    NSString *text = [NSString stringWithCharacters:&character length:1];
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0
        windowNumber:window.windowNumber context:nil characters:text charactersIgnoringModifiers:text isARepeat:NO keyCode:code];
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        assert(argc == 2);
        [NSApplication sharedApplication];
        [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:
            @{@"SizeOfDocumentsListTextPopUp": @0, @"ShowFullPathInDocumentsList": @NO}];
        NSString *directory = [NSString stringWithUTF8String:argv[1]];
        NSUInteger tested = 0;
        for (NSString *filename in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil]) {
            if (![filename.pathExtension isEqual:@"nib"]) continue;
            NSLog(@"Checking %@", filename);
            NSNib *nib = [[NSNib alloc] initWithNibData:[NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:filename]] bundle:nil];
            NSArray *objects;
            assert([nib instantiateWithOwner:nil topLevelObjects:&objects]);
            NSWindow *window;
            NSArrayController *controller;
            for (id object in objects) {
                if ([object isKindOfClass:NSWindow.class]) window = object;
                if ([object isKindOfClass:NSArrayController.class]) controller = object;
            }
            assert(window && controller);
            NSScrollView *scroll = window.contentView.subviews[0];
            FRATableView *table = (id)scroll.documentView;
            NSMutableDictionary *first = [@{@"name": @"Alpha", @"nameWithPath": @"/tmp/Alpha", @"path": @"/tmp/Alpha",
                @"isEdited": @NO, @"isNewDocument": @NO, @"fromExternal": @NO,
                @"inline": @NO, @"interpreter": @"/bin/sh", @"shortcutDisplayString": @"⌘A"} mutableCopy];
            first[@"icon"] = [NSImage imageWithSystemSymbolName:@"doc" accessibilityDescription:@"Document"];
            first[@"unsavedIcon"] = [NSImage imageWithSystemSymbolName:@"circle.fill" accessibilityDescription:@"Unsaved document"];
            NSMutableDictionary *second = [first mutableCopy]; second[@"name"] = @"Bravo";
            controller.content = [NSMutableArray arrayWithArray:@[first, second]];
            [controller setSelectionIndex:0];
            FRACommandsController.sharedInstance.commandsTableView = table;
            FRACommandsController.sharedInstance.commandsArrayController = controller;
            [table reloadData];
            [window makeKeyAndOrderFront:nil];
            [window.contentView layoutSubtreeIfNeeded];
            assert(table.numberOfRows == 2 && table.selectedRow == 0);
            FRADocumentsListCell *cell = [table viewAtColumn:0 row:0 makeIfNecessary:YES];
            assert([cell isKindOfClass:FRADocumentsListCell.class] && cell.objectValue == first);
            [cell viewWillDraw]; [cell layout];
            assert([cell.textField.stringValue isEqual:@"Alpha"]);
            if (cell.textField.editable) {
                [table editColumn:0 row:0 withEvent:nil select:YES];
                NSTextView *editor = (id)cell.textField.currentEditor;
                assert(editor && table.editingColumn == 0);
                [editor insertText:@"Renamed" replacementRange:editor.selectedRange];
                [editor insertNewline:nil];
                assert([first[@"name"] isEqual:@"Renamed"] && window.firstResponder == table);
                [table editColumn:0 row:0 withEvent:nil select:YES];
                editor = (id)cell.textField.currentEditor;
                [editor insertText:@"Cancelled" replacementRange:editor.selectedRange];
                [editor doCommandBySelector:@selector(cancelOperation:)];
                assert(!cell.textField.currentEditor && [first[@"name"] isEqual:@"Renamed"]);
                assert([cell.textField.stringValue isEqual:@"Renamed"]);
                if (table.numberOfColumns > 1) {
                    [table editColumn:0 row:0 withEvent:nil select:YES];
                    editor = (id)cell.textField.currentEditor;
                    [editor insertTab:nil];
                    NSInteger nextColumn = table.editingColumn;
                    if (nextColumn == -1 && [window.firstResponder isKindOfClass:NSView.class]) {
                        nextColumn = [table columnForView:(id)window.firstResponder];
                    }
                    assert(nextColumn > 0);
                    if ([window.firstResponder isKindOfClass:NSTextView.class]) {
                        [(NSTextView *)window.firstResponder insertBacktab:nil];
                    } else {
                        [window selectPreviousKeyView:window.firstResponder];
                    }
                    assert(table.editingColumn == 0);
                    [window makeFirstResponder:table];
                }
            } else {
                assert([cell.toolTip isEqual:@"/tmp/Alpha"]);
                assert(cell.imageView.image == first[@"icon"]);
                first[@"isEdited"] = @YES;
                [cell viewWillDraw];
                assert(cell.imageView.image == first[@"unsavedIcon"]);
                [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:
                    @{@"SizeOfDocumentsListTextPopUp": @1, @"ShowFullPathInDocumentsList": @YES}];
                [cell viewWillDraw]; [cell layout];
                assert([cell.textField.stringValue isEqual:@"/tmp/Alpha"] && cell.textField.font.pointSize == 13);
                table.rowHeight = 48;
                [table reloadData];
                cell = [table viewAtColumn:0 row:0 makeIfNecessary:YES];
                [cell viewWillDraw]; [cell layout];
                assert(NSWidth(cell.imageView.frame) > 16);
            }
            [window makeFirstResponder:table];
            [table keyDown:Key(window, NSDownArrowFunctionKey, 125)];
            assert(table.selectedRow == 1 && controller.selectionIndex == 1);
            [table keyDown:Key(window, NSUpArrowFunctionKey, 126)];
            assert(table.selectedRow == 0 && controller.selectionIndex == 0);
            for (NSInteger column = 0; column < table.numberOfColumns; column++) {
                NSTableCellView *view = [table viewAtColumn:column row:0 makeIfNecessary:YES];
                if ([table.tableColumns[column].identifier isEqual:@"inline"]) {
                    NSButton *button = view.subviews[0];
                    [button performClick:nil];
                    assert([first[@"inline"] boolValue]);
                }
                if ([table.tableColumns[column].identifier isEqual:@"shortcut"]) {
                    [table editColumn:column row:0 withEvent:nil select:YES];
                    assert(table.editingColumn == column);
                    [window makeFirstResponder:table];
                }
            }
            [table keyDown:Key(window, NSDeleteCharacter, 51)];
            assert([controller.arrangedObjects count] == 1);
            [window orderOut:nil];
            [table unbind:NSContentBinding]; [table unbind:NSSelectionIndexesBinding]; [table unbind:NSSortDescriptorsBinding];
            tested++;
        }
        assert(tested == 5);
        puts("Five production tables: bindings, editing, Escape, arrows, Tab/Shift-Tab, checkboxes, icons, and shortcut focus passed.");
    }
    return 0;
}
