/*
 Erbele - Based on Fraise 3.7.3 based on Smultron by Peter Borg
 
 Current Maintainer (since 2016): 
 Andreas Bentele: abentele.github@icloud.com (https://github.com/abentele/Erbele)
 
 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

#import "FRADragAndDropController.h"
#import "FRAPasteboard.h"
#import "FRAOpenSavePerformer.h"
#import "FRAProjectsController.h"
#import "FRATableView.h"
#import "FRATextPerformer.h"
#import "FRACommandsController.h"
#import "FRABasicPerformer.h"
#import "FRASnippetsController.h"
#import "FRAVariousPerformer.h"
#import "FRAProject.h"
#import "FRATextView.h"

@implementation FRADragAndDropController

static id sharedInstance = nil;

+ (FRADragAndDropController *)sharedInstance
{ 
	if (sharedInstance == nil) { 
		sharedInstance = [[self alloc] init];
	}
	
	return sharedInstance;
} 


- (id)init 
{
    if (sharedInstance == nil) {
        sharedInstance = [super init];
		
		movedDocumentType = @"org.erbele.dragged-document";
		movedSnippetType = @"org.erbele.dragged-snippet";
		movedCommandType = @"org.erbele.dragged-command";
    }
    return sharedInstance;
}


- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row
{
    NSArray *objects;
    NSPasteboardType type;
    if (tableView == [FRACurrentProject documentsTableView]) {
        objects = [[FRACurrentProject documentsArrayController] arrangedObjects];
        type = movedDocumentType;
    } else if (tableView == [[FRASnippetsController sharedInstance] snippetsTableView]) {
        objects = [[[FRASnippetsController sharedInstance] snippetsArrayController] arrangedObjects];
        type = movedSnippetType;
    } else if (tableView == [[FRACommandsController sharedInstance] commandsTableView]) {
        objects = [[[FRACommandsController sharedInstance] commandsArrayController] arrangedObjects];
        type = movedCommandType;
    } else {
        return nil;
    }
    if (row < 0 || row >= objects.count) return nil;
    NSURL *uri = [FRABasic uriFromObject:objects[row]];
    if (!uri) return nil;
    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
    [item setPropertyList:@{@"row": @(row), @"uri": uri.absoluteString} forType:type];
    if (![type isEqualToString:movedDocumentType]) {
        NSIndexSet *rows = tableView.selectedRowIndexes;
        if (![rows containsIndex:row]) rows = [NSIndexSet indexSetWithIndex:row];
        if (rows.lastIndex >= objects.count) return nil;
        if (row == rows.firstIndex) {
            // Keep the original concatenation: one text item avoids AppKit adding newlines between snippets.
            NSString *selectedText = [[FRACurrentTextView string] substringWithRange:[FRACurrentTextView selectedRange]] ?: @"";
            NSString *text = [[[objects objectsAtIndexes:rows] valueForKey:@"text"] componentsJoinedByString:@""];
            [item setString:[text stringByReplacingOccurrencesOfString:@"%%s" withString:selectedText] forType:NSPasteboardTypeString];
        }
    }
    return item;
}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	if (aTableView == [FRACurrentProject documentsTableView]) {
		if ([info draggingSource] == [FRACurrentProject documentsTableView]) {
			[aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
			return NSDragOperationMove;
		} else {
			[aTableView setDropRow:[[[FRACurrentProject documentsArrayController] arrangedObjects] count] dropOperation:NSTableViewDropAbove];
			return NSDragOperationCopy;
		}
		
	} else if (aTableView == [[FRASnippetsController sharedInstance] snippetsTableView]) {
		[aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
	 	return NSDragOperationCopy;
		
	} else if (aTableView == [[FRASnippetsController sharedInstance] snippetCollectionsTableView]) {
		if ([info draggingSource] == [[FRASnippetsController sharedInstance] snippetsTableView]) {
			[aTableView setDropRow:row dropOperation:NSTableViewDropOn];
			return NSDragOperationMove;
		} else {
			[aTableView setDropRow:[[[[FRASnippetsController sharedInstance] snippetCollectionsArrayController] arrangedObjects] count] dropOperation:NSTableViewDropAbove];
			return NSDragOperationCopy;
		}
		return NSDragOperationCopy;
		
	} else if (aTableView == [[FRACommandsController sharedInstance] commandsTableView]) {
		[aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
	 	return NSDragOperationCopy;
		
	} else if (aTableView == [[FRACommandsController sharedInstance] commandCollectionsTableView]) {
		if ([info draggingSource] == [[FRACommandsController sharedInstance] commandsTableView]) {
			[aTableView setDropRow:row dropOperation:NSTableViewDropOn];
			return NSDragOperationMove;
		} else {
			[aTableView setDropRow:[[[[FRACommandsController sharedInstance] commandCollectionsArrayController] arrangedObjects] count] dropOperation:NSTableViewDropAbove];
			return NSDragOperationCopy;
		}
		return NSDragOperationCopy;
		
	} else if ([aTableView isKindOfClass:[FRATableView class]]) {		
		[aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
		return NSDragOperationMove;
	}
	
	return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
	if (row < 0) {
		row = 0;
	}

    // Documents list
	if (aTableView == [FRACurrentProject documentsTableView]) {
		if ([info draggingSource] == [FRACurrentProject documentsTableView]) {
			if (![[[info draggingPasteboard] types] containsObject:movedDocumentType]) {
				return NO;
			}
			NSArrayController *arrayController = [FRACurrentProject documentsArrayController];
			
			NSArray *pasteboardData = FRADraggedObjectsFromPasteboard([info draggingPasteboard], movedDocumentType);
			if (!pasteboardData) return NO;
			NSIndexSet *rowIndexes = pasteboardData[0];
			NSArray *uriArray = pasteboardData[1];
			[self moveObjects:uriArray inArrayController:arrayController fromIndexes:rowIndexes toIndex:row];
			
			[FRACurrentProject documentsListHasUpdated];
			
			return YES;
			
		}

		NSArray *filesToImport = FRAFilePathsFromPasteboard([info draggingPasteboard]);
		if (filesToImport.count > 0 && aTableView == [FRACurrentProject documentsTableView]) {
			[FRAOpenSave openAllTheseFiles:filesToImport];
			return YES;
		}
		
		NSString *textToImport = (NSString *)[[info draggingPasteboard] stringForType:NSPasteboardTypeString];
		if (textToImport != nil && aTableView == [FRACurrentProject documentsTableView]) {
			[FRACurrentProject createNewDocumentWithContents:textToImport];
			return YES;
		}
		
	// Snippets
	} else if (aTableView == [[FRASnippetsController sharedInstance] snippetsTableView]) {
		
		NSString *textToImport = (NSString *)[[info draggingPasteboard] stringForType:NSPasteboardTypeString];
		if (textToImport != nil) {
			
			id item = [[FRASnippetsController sharedInstance] performInsertNewSnippet];
			
			[item setValue:textToImport forKey:@"text"];
			if ([textToImport length] > SNIPPET_NAME_LENGTH) {
				[item setValue:[FRAText replaceAllNewLineCharactersWithSymbolInString:[textToImport substringWithRange:NSMakeRange(0, SNIPPET_NAME_LENGTH)]] forKey:@"name"];
			} else {
				[item setValue:textToImport forKey:@"name"];
			}
			
			return YES;
		} else {
			return NO;
		}		
	
	// Snippet collections
	} else if (aTableView == [[FRASnippetsController sharedInstance] snippetCollectionsTableView]) {
		NSArray *filesToImport = FRAFilePathsFromPasteboard([info draggingPasteboard]);
		
		if (filesToImport.count > 0) {
			[FRAOpenSave openAllTheseFiles:filesToImport];
			return YES;
		}
		
		if ([info draggingSource] == [[FRASnippetsController sharedInstance] snippetsTableView]) {
			if (![[[info draggingPasteboard] types] containsObject:movedSnippetType]) {
				return NO;
			}
			
			NSArray *pasteboardData = FRADraggedObjectsFromPasteboard([info draggingPasteboard], movedSnippetType);
			if (!pasteboardData) return NO;
			NSArray *uriArray = pasteboardData[1];
			
			id collection = [[[FRASnippetsController sharedInstance] snippetCollectionsArrayController] arrangedObjects][row];
			
			id item;
			for (item in uriArray) {
				[[collection mutableSetValueForKey:@"snippets"] addObject:[FRABasic objectFromURI:item]];
			}
			
			[[[FRASnippetsController sharedInstance] snippetsArrayController] rearrangeObjects];

			return YES;
		}
		
		
	// Commands
	} else if (aTableView == [[FRACommandsController sharedInstance] commandsTableView]) {
		
		NSString *textToImport = (NSString *)[[info draggingPasteboard] stringForType:NSPasteboardTypeString];
		if (textToImport != nil) {
			
			id item = [[FRACommandsController sharedInstance] performInsertNewCommand];
			
			[item setValue:textToImport forKey:@"text"];
			if ([textToImport length] > SNIPPET_NAME_LENGTH) {
				[item setValue:[FRAText replaceAllNewLineCharactersWithSymbolInString:[textToImport substringWithRange:NSMakeRange(0, SNIPPET_NAME_LENGTH)]] forKey:@"name"];
			} else {
				[item setValue:textToImport forKey:@"name"];
			}
			
			return YES;
		} else {
			return NO;
		}		
		
	// Command collections
	} else if (aTableView == [[FRACommandsController sharedInstance] commandCollectionsTableView]) {

		NSArray *filesToImport = FRAFilePathsFromPasteboard([info draggingPasteboard]);
		
		if (filesToImport.count > 0) {
			[FRAOpenSave openAllTheseFiles:filesToImport];
			return YES;
		}
		
		if ([info draggingSource] == [[FRACommandsController sharedInstance] commandsTableView]) {
			if (![[[info draggingPasteboard] types] containsObject:movedCommandType]) {
				return NO;
			}
			
			NSArray *pasteboardData = FRADraggedObjectsFromPasteboard([info draggingPasteboard], movedCommandType);
			if (!pasteboardData) return NO;
			NSArray *uriArray = pasteboardData[1];
			
			id collection = [[[FRACommandsController sharedInstance] commandCollectionsArrayController] arrangedObjects][row];
			
			id item;
			for (item in uriArray) {
				[[collection mutableSetValueForKey:@"commands"] addObject:[FRABasic objectFromURI:item]];
			}
			
			[[[FRACommandsController sharedInstance] commandsArrayController] rearrangeObjects];
			
			return YES;
		}
		
	// From another project
	} else if ([[info draggingSource] isKindOfClass:[FRATableView class]]) {
		if (![[[info draggingPasteboard] types] containsObject:movedDocumentType]) {
			return NO;
		}
		
		NSArray *array = [[FRAProjectsController sharedDocumentController] documents];
		id destinationProject;
		for (destinationProject in array) {
			if (aTableView == [destinationProject documentsTableView]) {
				break;
			}
		}
		
		if (destinationProject == nil) {
			return NO;
		}
		
		NSArrayController *destinationArrayController = [destinationProject documentsArrayController];
		NSArray *pasteboardData = FRADraggedObjectsFromPasteboard([info draggingPasteboard], movedDocumentType);
		if (!pasteboardData) return NO;
		NSArray *uriArray = pasteboardData[1];
        for (NSURL *uri in uriArray) {
            id document = [FRABasic objectFromURI:uri];
            if (!document) return NO;
            [(NSMutableSet *)[destinationProject documents] addObject:document];
            [document setValue:@(row) forKey:@"sortOrder"];
            [FRAVarious fixSortOrderNumbersForArrayController:destinationArrayController overIndex:row];
            row++;
        }
        [destinationArrayController rearrangeObjects];
        [destinationProject selectDocument:[FRABasic objectFromURI:uriArray[0]]];
		[destinationProject documentsListHasUpdated];
		[FRACurrentProject documentsListHasUpdated];
		
		return YES;	
		
	
	// To a table view which is not active
	} else if ([aTableView isKindOfClass:[FRATableView class]]) {
		
		NSArray *filesToImport = FRAFilePathsFromPasteboard([info draggingPasteboard]);
		
		if (filesToImport.count > 0) {
			[[aTableView window] makeMainWindow];
			NSArray *array = [[FRAProjectsController sharedDocumentController] documents];
			for (id item in array) {
				if (aTableView == [item documentsTableView]) {
					[[FRAProjectsController sharedDocumentController] setCurrentProject:item];
					break;
				}
			}
			
			if (FRACurrentProject != nil) {
				[FRAOpenSave openAllTheseFiles:filesToImport];
				[[FRAProjectsController sharedDocumentController] setCurrentProject:nil];
				return YES;
			}
		}
		
		return NO;
	}
	
	
    return NO;
}


- (void)moveObjects:(NSArray *)objects inArrayController:(NSArrayController *)arrayController fromIndexes:(NSIndexSet *)rowIndexes toIndex:(NSInteger)insertIndex
{
	NSMutableArray *arrangedObjects = [NSMutableArray arrayWithArray:[arrayController arrangedObjects]]; 
	
	if (arrangedObjects == nil || objects == nil) {
		return; 
	} 
	
	NSUInteger currentIndex = [rowIndexes firstIndex];
	while (currentIndex != NSNotFound) {
		arrangedObjects[currentIndex] = [NSNull null]; 
		currentIndex = [rowIndexes indexGreaterThanIndex:currentIndex];
	}
	
	NSEnumerator *enumerator = [objects reverseObjectEnumerator]; 
	id item;
	for (item in enumerator) {
		[arrangedObjects insertObject:[FRABasic objectFromURI:item] atIndex:insertIndex];
	}

	[arrangedObjects removeObject:[NSNull null]];
	
	NSInteger index = 0;
	for (item in arrangedObjects) {
		[item setValue:@(index) forKey:@"sortOrder"];
		index++;
	}
	
	[arrayController setContent:arrangedObjects];
}

@end
