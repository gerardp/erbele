/*
 Erbele - Based on Fraise 3.7.3 based on Smultron by Peter Borg
 
 Current Maintainer (since 2016): 
 Andreas Bentele: abentele.github@icloud.com (https://github.com/abentele/Erbele)
 
 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */


#import "FRAAdvancedFindController.h"

#import "FRAExtraInterfaceController.h"
#import "FRAProjectsController.h"
#import "FRABasicPerformer.h"
#import "FRAApplicationDelegate.h"
#import "FRAInterfacePerformer.h"
#import "FRALineNumbers.h"
#import "FRAProject.h"
#import "FRATextPerformer.h"
#import "FRAOpenSavePerformer.h"

@implementation FRAAdvancedFindController

@synthesize advancedFindWindow, findResultsOutlineView;

static id sharedInstance = nil;

+ (FRAAdvancedFindController *)sharedInstance
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
    }
    return sharedInstance;
}


- (NSRegularExpression *)regularExpressionForSearchString:(NSString *)searchString
{
	NSRegularExpressionOptions options = NSRegularExpressionAnchorsMatchLines;
	if ([[FRADefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
		options |= NSRegularExpressionCaseInsensitive;
	}
	
	NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:searchString options:options error:NULL];
	if (regularExpression == nil) {
		[self alertThatThisIsNotAValidRegularExpression:searchString];
	}
	
	return regularExpression;
}


- (IBAction)findAction:(id)sender
{
	FRAAdvancedFindScope searchScope = [[FRADefaults valueForKey:@"AdvancedFindScope"] integerValue];
	NSArray *originalDocuments = nil;
	
	if (searchScope == FRAParentDirectoryScope) {
		 originalDocuments = [NSArray arrayWithArray:[[FRACurrentProject documentsArrayController] arrangedObjects]];
	}
	
	NSString *searchString = [findSearchField stringValue];
	
	[findResultsOutlineView setDelegate:nil];
	
	[self.findResultsTreeController setContent:nil];
	[self.findResultsTreeController setContent:[NSMutableArray array]];
	
	NSMutableArray *recentSearches = [[NSMutableArray alloc] initWithArray:[findSearchField recentSearches]];
	if ([recentSearches indexOfObject:searchString] != NSNotFound) {
		[recentSearches removeObject:searchString];
	}
	[recentSearches insertObject:searchString atIndex:0];
	if ([recentSearches count] > 15) {
		[recentSearches removeLastObject];
	}
	[findSearchField setRecentSearches:recentSearches];
	
	NSInteger searchStringLength = [searchString length];
	if (!(searchStringLength > 0) || FRACurrentDocument == nil || FRACurrentProject == nil) {
		NSBeep();
		return;
	}
	
	NSString *completeString;
	NSInteger completeStringLength; 
	NSInteger startLocation;
	NSInteger resultsInThisDocument = 0;
	NSInteger lineNumber;
	NSInteger index;
	NSInteger numberOfResults = 0;
	NSRange foundRange;
	NSRange searchRange;
	NSIndexPath *folderIndexPath;
	NSMutableDictionary *node;
	
	NSEnumerator *enumerator = [self scopeEnumerator];

	NSInteger documentIndex = 0;
	for (id document in enumerator) {
		node = [NSMutableDictionary dictionary];
		if ([[FRADefaults valueForKey:@"ShowFullPathInWindowTitle"] boolValue] == YES) {
			node[@"displayString"] = [document valueForKey:@"nameWithPath"];
		} else {
			node[@"displayString"] = [document valueForKey:@"name"];
		}
		node[@"isLeaf"] = @NO;
		node[@"document"] = [FRABasic uriFromObject:document];
		folderIndexPath = [[NSIndexPath alloc] initWithIndex:documentIndex];
		[self.findResultsTreeController insertObject:node atArrangedObjectIndexPath:folderIndexPath];
		
		documentIndex++;
		
		completeString = [[document valueForKey:@"firstTextView"] string];
		searchRange = [[document valueForKey:@"firstTextView"] selectedRange];
		completeStringLength = [completeString length];
		if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
			searchRange = NSMakeRange(0, completeStringLength);
		}
		startLocation = searchRange.location;
		resultsInThisDocument = 0;
		
		if ([[FRADefaults valueForKey:@"UseRegularExpressionsAdvancedFind"] boolValue] == YES) {
			NSRegularExpression *regularExpression = [self regularExpressionForSearchString:searchString];
			if (regularExpression == nil) {
				return;
			}
			
			if ([completeString length] > 0) { // An empty document would only ever yield an empty match
				NSString *stringToSearch;
				if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
					stringToSearch = completeString;
				} else {
					stringToSearch = [completeString substringWithRange:searchRange];
				}
				
				NSInteger indexTemp;
				for (NSTextCheckingResult *match in [regularExpression matchesInString:stringToSearch options:0 range:NSMakeRange(0, [stringToSearch length])]) {
					NSInteger foundLocation = [match range].location + startLocation;
					for (index = 0, lineNumber = 0; index <= foundLocation; lineNumber++) {
						indexTemp = index;
						index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
						if (indexTemp == index) {
							index++; // Make sure it moves forward if it is stuck when searching e.g. for [ \t\n]*
						}
					}
					
					@autoreleasepool {
						NSRange rangeMatch = NSMakeRange([match range].location + searchRange.location, [match range].length);
						[self.findResultsTreeController insertObject:[self preparedResultDictionaryFromString:completeString searchStringLength:searchStringLength range:rangeMatch lineNumber:lineNumber document:document] atArrangedObjectIndexPath:[folderIndexPath indexPathByAddingIndex:resultsInThisDocument]];
					}
					
					resultsInThisDocument++;
				}
			}
			
		} else {			
			while (startLocation < completeStringLength) {
				if ([[FRADefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					foundRange = [completeString rangeOfString:searchString options:NSCaseInsensitiveSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				} else {
					foundRange = [completeString rangeOfString:searchString options:NSLiteralSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				}

				if (foundRange.location == NSNotFound) {
					break;
				}
				for (index = 0, lineNumber = 0; index <= foundRange.location; lineNumber++) {
					index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);	
				}
			
				@autoreleasepool {
					[self.findResultsTreeController insertObject:[self preparedResultDictionaryFromString:completeString searchStringLength:searchStringLength range:foundRange lineNumber:lineNumber document:document] atArrangedObjectIndexPath:[folderIndexPath indexPathByAddingIndex:resultsInThisDocument]];
				}
				
				resultsInThisDocument++;
				startLocation = NSMaxRange(foundRange);
			}
		}
		
		if (resultsInThisDocument == 0) {
			[self.findResultsTreeController removeObjectAtArrangedObjectIndexPath:folderIndexPath];
			documentIndex--;
			
			// Remove document if no results have been found into it and the document was not loaded before.
			if ((searchScope == FRAParentDirectoryScope) && (originalDocuments != nil)) {
				BOOL closing = YES;
				
				NSEnumerator *originalDocumentsEnumerator = [originalDocuments objectEnumerator];
				for (id originalDocument in originalDocumentsEnumerator) {
					if (originalDocument == document) {
						closing = NO;
						break;
					}
				}
				
				if (closing)
					[FRACurrentProject performCloseDocument:document];
			}
		} else {
			numberOfResults += resultsInThisDocument;
		}
			
	}
	
	NSString *searchResultString;
	if (numberOfResults == 0) {
		searchResultString = [NSString stringWithFormat:NSLocalizedString(@"Could not find a match for search-string %@", @"Could not find a match for search-string %@ in Advanced Find"), searchString];
	} else if (numberOfResults == 1) {
		searchResultString = [NSString stringWithFormat:NSLocalizedString(@"Found one match for search-string %@", @"Found one match for search-string %@ in Advanced Find"), searchString];
	} else {
		searchResultString = [NSString stringWithFormat:NSLocalizedString(@"Found %ld matches for search-string %@", @"Found %ld matches for search-string %@ in Advanced Find"), (long)numberOfResults, searchString];
	}
	
	[findResultTextField setStringValue:searchResultString];
	
	NSArray *nodes = [[self.findResultsTreeController arrangedObjects] childNodes];
	for (id item in nodes) {
		[findResultsOutlineView expandItem:item expandChildren:NO];
	}
	
	[findResultsOutlineView setDelegate:self];
}


- (IBAction)replaceAction:(id)sender
{	
	FRAAdvancedFindScope searchScope = [[FRADefaults valueForKey:@"AdvancedFindScope"] integerValue];
	NSArray *originalDocuments = nil;
	
	if (searchScope == FRAParentDirectoryScope) {
		originalDocuments = [NSArray arrayWithArray:[[FRACurrentProject documentsArrayController] arrangedObjects]];
	}
	
	NSString *searchString = [findSearchField stringValue];
	NSString *replaceString = [replaceSearchField stringValue];
	
	NSMutableArray *recentSearches = [[NSMutableArray alloc] initWithArray:[findSearchField recentSearches]];
	if ([recentSearches indexOfObject:searchString] != NSNotFound) {
		[recentSearches removeObject:searchString];
	}
	[recentSearches insertObject:searchString atIndex:0];
	if ([recentSearches count] > 15) {
		[recentSearches removeLastObject];
	}
	[findSearchField setRecentSearches:recentSearches];
	
	NSMutableArray *recentReplaces = [[NSMutableArray alloc] initWithArray:[replaceSearchField recentSearches]];
	if ([recentReplaces indexOfObject:replaceString] != NSNotFound) {
		[recentReplaces removeObject:replaceString];
	}
	[recentReplaces insertObject:replaceString atIndex:0];
	if ([recentReplaces count] > 15) {
		[recentReplaces removeLastObject];
	}
	[replaceSearchField setRecentSearches:recentReplaces];
	
	NSInteger searchStringLength = [searchString length];
	if (!(searchStringLength > 0) || FRACurrentDocument == nil || FRACurrentProject == nil) {
		NSBeep();
		return;
	}
	
	NSString *completeString;
	NSInteger completeStringLength; 
	NSInteger startLocation;
	NSInteger resultsInThisDocument = 0;
	NSInteger numberOfResults = 0;
	NSRange foundRange;
	NSRange searchRange;
	
	NSEnumerator *enumerator = [self scopeEnumerator];
	for (id document in enumerator) {
		completeString = [[[document valueForKey:@"firstTextScrollView"] documentView] string];
		searchRange = [[[document valueForKey:@"firstTextScrollView"] documentView] selectedRange];
		completeStringLength = [completeString length];
		if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
			searchRange = NSMakeRange(0, completeStringLength);
		}
		
		startLocation = searchRange.location;
		resultsInThisDocument = 0;
		
		if ([[FRADefaults valueForKey:@"UseRegularExpressionsAdvancedFind"] boolValue] == YES) {
			NSRegularExpression *regularExpression = [self regularExpressionForSearchString:searchString];
			if (regularExpression == nil) {
				return;
			}
			
			NSString *stringToSearch;
			if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
				stringToSearch = completeString;
			} else {
				stringToSearch = [completeString substringWithRange:searchRange];
			}
			
			resultsInThisDocument = [regularExpression numberOfMatchesInString:stringToSearch options:0 range:NSMakeRange(0, [stringToSearch length])];
	
			
		} else {
			NSInteger searchLength;
			if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
				searchLength = completeStringLength;
			} else {
				searchLength = NSMaxRange(searchRange);
			}
			while (startLocation < searchLength) {
				if ([[FRADefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
					foundRange = [completeString rangeOfString:searchString options:NSCaseInsensitiveSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				} else {
					foundRange = [completeString rangeOfString:searchString options:NSLiteralSearch range:NSMakeRange(startLocation, NSMaxRange(searchRange) - startLocation)];
				}
				
				if (foundRange.location == NSNotFound) {
					break;
				}
				resultsInThisDocument++;
				startLocation = NSMaxRange(foundRange);
			}
		}
		
		if (resultsInThisDocument == 0) {
			// Remove document if no results have been found into it and the document was not loaded before.
			if ((searchScope == FRAParentDirectoryScope) && (originalDocuments != nil)) {
				BOOL closing = YES;
				
				NSEnumerator *originalDocumentsEnumerator = [originalDocuments objectEnumerator];
				for (id originalDocument in originalDocumentsEnumerator) {
					if ([[originalDocument valueForKey:@"nameWithPath"] isEqualToString:[document valueForKey:@"nameWithPath"]]) {
						closing = NO;
						break;
					}
				}
				
				if (closing)
					[FRACurrentProject performCloseDocument:document];
			}
		}
		else {
			numberOfResults += resultsInThisDocument;
		}
	}
	
	if (numberOfResults == 0) {
		[findResultTextField setObjectValue:[NSString stringWithFormat:NSLocalizedString(@"Could not find a match for search-string %@", @"Could not find a match for search-string %@ in Advanced Find"), searchString]];
		NSBeep();
		return;
	}
	
	if ([[FRADefaults valueForKey:@"SuppressReplaceWarning"] boolValue] == YES) {
		[self performNumberOfReplaces:numberOfResults];
	} else {
		NSString *title;
		NSString *defaultButton;
		if ([replaceString length] > 0) {
			if (numberOfResults != 1) {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to replace %ld occurrences of %@ with %@?", @"Ask if you are sure that you want to replace %ld occurrences of %@ with %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), (long) numberOfResults, searchString, replaceString];
			} else {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to replace one occurrence of %@ with %@?", @"Ask if you are sure that you want to replace one occurrence of %@ with %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), searchString, replaceString];
			}
			defaultButton = NSLocalizedString(@"Replace", @"Replace-button in ask-if-sure-you-want-to-replace-in-advanced-find-sheet");
		} else {
			if (numberOfResults != 1) {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to delete %ld occurrences of %@?", @"Ask if you are sure that you want to delete %ld occurrences of %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), (long) numberOfResults, searchString];
			} else {
				title = [NSString stringWithFormat:NSLocalizedString(@"Are you sure that you want to delete the one occurrence of %@?", @"Ask if you are sure that you want to delete the one occurrence of %@ in ask-if-sure-you-want-to-replace-in-advanced-find-sheet"), searchString];
			}
			defaultButton = DELETE_BUTTON;
		}
        
        NSAlert* alert = [[NSAlert alloc] init];
        [alert setMessageText:title];
        [alert setInformativeText:NSLocalizedString(@"Remember that you can always Undo any changes", @"Remember that you can always Undo any changes in ask-if-sure-you-want-to-replace-in-advanced-find-sheet")];
        [alert addButtonWithTitle:defaultButton];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel-button")];
        [alert setAlertStyle:NSAlertStyleWarning];
        
        [alert beginSheetModalForWindow:advancedFindWindow completionHandler:^(NSInteger result) {
            if (result == NSAlertFirstButtonReturn) {
                [self performNumberOfReplaces:numberOfResults];
            }
        }];
	}
}


- (void)performNumberOfReplaces:(NSInteger)numberOfReplaces
{
	NSString *searchString = [findSearchField stringValue];
	NSString *replaceString = [replaceSearchField stringValue];
	NSRange searchRange;
	
	NSEnumerator *enumerator = [self scopeEnumerator];
	for (id document in enumerator) {
		NSTextView *textView = [[document valueForKey:@"firstTextScrollView"] documentView];
		NSString *originalString = [NSString stringWithString:[textView string]];
		NSMutableString *completeString = [NSMutableString stringWithString:[textView string]];
		searchRange = [[[document valueForKey:@"firstTextScrollView"] documentView] selectedRange];
		if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO || searchRange.length == 0) {
			searchRange = NSMakeRange(0, [[[[document valueForKey:@"firstTextScrollView"] documentView] string] length]);
		}
		
		if ([[FRADefaults valueForKey:@"UseRegularExpressionsAdvancedFind"] boolValue] == YES) {		
			NSRegularExpression *regularExpression = [self regularExpressionForSearchString:searchString];
			if (regularExpression == nil) {
				return;
			}
			NSString *stringToSearch;
			if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO) {
				stringToSearch = completeString;
			} else {
				stringToSearch = [completeString substringWithRange:searchRange];
			}

			NSMutableString *regularExpressionReplaceString = [NSMutableString stringWithString:replaceString];
			[regularExpressionReplaceString replaceOccurrencesOfString:@"\\n" withString:[NSString stringWithFormat:@"%C", 0x000A] options:NSLiteralSearch range:NSMakeRange(0, [regularExpressionReplaceString length])]; // It doesn't seem to work without this workaround
			[regularExpressionReplaceString replaceOccurrencesOfString:@"\\r" withString:[NSString stringWithFormat:@"%C", 0x000D] options:NSLiteralSearch range:NSMakeRange(0, [regularExpressionReplaceString length])];
			[regularExpressionReplaceString replaceOccurrencesOfString:@"\\t" withString:[NSString stringWithFormat:@"%C", 0x0009] options:NSLiteralSearch range:NSMakeRange(0, [regularExpressionReplaceString length])];
			
			NSString *replaced = [regularExpression stringByReplacingMatchesInString:stringToSearch options:0 range:NSMakeRange(0, [stringToSearch length]) withTemplate:regularExpressionReplaceString];
			if ([[FRADefaults valueForKey:@"OnlyInSelectionAdvancedFind"] boolValue] == NO) {
				[completeString setString:replaced];
			} else {
				[completeString replaceCharactersInRange:searchRange withString:replaced];
			}
			

		} else {
			
			if ([[FRADefaults valueForKey:@"IgnoreCaseAdvancedFind"] boolValue] == YES) {
				[completeString replaceOccurrencesOfString:searchString withString:replaceString options:NSCaseInsensitiveSearch range:searchRange];
			} else {
				[completeString replaceOccurrencesOfString:searchString withString:replaceString options:NSLiteralSearch range:searchRange];
			}
		}
		
		NSRange selectedRange = [textView selectedRange];
		if (![originalString isEqualToString:completeString] && [originalString length] != 0) {
			if ([textView shouldChangeTextInRange:NSMakeRange(0, [[textView string] length]) replacementString:completeString]) { // Do it this way to mark it as an Undo
				[textView replaceCharactersInRange:NSMakeRange(0, [[textView string] length]) withString:completeString];
				[textView didChangeText];
				[document setValue:@YES forKey:@"isEdited"];
			}
		}		
		
		if (selectedRange.location <= [[textView string] length]) {
			[textView setSelectedRange:NSMakeRange(selectedRange.location, 0)];
		}
	}
	
	if (numberOfReplaces != 1) {
		[findResultTextField setObjectValue:[NSString stringWithFormat:NSLocalizedString(@"Replaced %ld occurrences of %@ with %@", @"Indicate that we replaced %ld occurrences of %@ with %@ in update-search-textField-after-replace"), (long)numberOfReplaces, searchString, replaceString]];
	} else {
		[findResultTextField setObjectValue:[NSString stringWithFormat:NSLocalizedString(@"Replaced one occurrence of %@ with %@", @"Indicate that we replaced one occurrence of %@ with %@ in update-search-textField-after-replace"), searchString, replaceString]];
	}
	
	[self.findResultsTreeController setContent:nil];
	[self.findResultsTreeController setContent:@[]];
	[self removeCurrentlyDisplayedDocumentInAdvancedFind];
	[advancedFindWindow makeKeyAndOrderFront:self];
}


- (void)showAdvancedFindWindow
{
	if (advancedFindWindow == nil) {
		[[NSBundle mainBundle] loadNibNamed:@"FRAAdvancedFind" owner:self topLevelObjects:nil];
	
		[[findResultTextField cell] setBackgroundStyle:NSBackgroundStyleRaised];
				
		[findResultsOutlineView setBackgroundColor:[NSColor alternatingContentBackgroundColors][1]];
		
		[findResultsOutlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
		
		FRAAdvancedFindScope searchScope = [[FRADefaults valueForKey:@"AdvancedFindScope"] integerValue];
		
		if (searchScope == FRACurrentDocumentScope) {
			[currentDocumentScope setState:NSControlStateValueOn];
		} else if (searchScope == FRACurrentProjectScope) {
			[currentProjectScope setState:NSControlStateValueOn];
		} else if (searchScope == FRAAllDocumentsScope) {
			[allDocumentsScope setState:NSControlStateValueOn];
		} else if (searchScope == FRAParentDirectoryScope) {
			[parentDirectoryScope setState:NSControlStateValueOn];
		}
		
		[self.findResultsTreeController setContent:nil];
		[self.findResultsTreeController setContent:@[]];
	}
	
	[advancedFindWindow makeKeyAndOrderFront:self];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([[[self.findResultsTreeController arrangedObjects] childNodes] count] == 0) {
		return;
	}
	
	id object = [self.findResultsTreeController selectedObjects][0];
	if ([[object valueForKey:@"isLeaf"] boolValue] == NO) {
		return;
	}
	
	id document = [FRABasic objectFromURI:[object valueForKey:@"document"]];
	
	if (document == nil) {
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"The document %@ is no longer open", @"Indicate that the document %@ is no longer open in Document-is-no-longer-opened-after-selection-in-advanced-find-sheet"), [document valueForKey:@"name"]];
        
        
        NSAlert* alert = [[NSAlert alloc] init];
        [alert setMessageText:title];
        [alert addButtonWithTitle:OK_BUTTON];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert beginSheetModalForWindow:advancedFindWindow completionHandler:^(NSInteger result) {
        }];
        
		return;
	}
	
	_currentlyDisplayedDocumentInAdvancedFind = document;
	
	if ([document valueForKey:@"fourthTextView"] == nil) {
		[FRAInterface insertDocumentIntoFourthContentView:document];
	}
	
	[self removeCurrentlyDisplayedDocumentInAdvancedFind];
	[resultDocumentContentView addSubview:[document valueForKey:@"fourthTextScrollView"]];
	if ([[document valueForKey:@"showLineNumberGutter"] boolValue] == YES) {
		[resultDocumentContentView addSubview:[document valueForKey:@"fourthGutterScrollView"]];
	}

	[[document valueForKey:@"lineNumbers"] updateLineNumbersForClipView:[[document valueForKey:@"fourthTextScrollView"] contentView] checkWidth:YES recolour:YES]; // If the window has changed since the view was last visible
		
	NSRange selectRange = NSRangeFromString([[self.findResultsTreeController selectedObjects][0] valueForKey:@"range"]);
	NSString *completeString = [[document valueForKey:@"fourthTextView"] string];
	if (NSMaxRange(selectRange) > [completeString length]) {
		NSBeep();
		return;
	}
	
	[[document valueForKey:@"fourthTextView"] setSelectedRange:selectRange];
	[[document valueForKey:@"fourthTextView"] scrollRangeToVisible:selectRange];
	[[document valueForKey:@"fourthTextView"] showFindIndicatorForRange:selectRange];
	[findResultsOutlineView setNextKeyView:[document valueForKey:@"fourthTextView"]];
	
	if ([[FRADefaults valueForKey:@"FocusOnTextInAdvancedFind"] boolValue] == YES) {
		[advancedFindWindow makeFirstResponder:[document valueForKey:@"fourthTextView"]];
	}
}


/*
 * This method returns an enumerator on all documents we are going to search into.
 */
- (NSEnumerator *)scopeEnumerator
{
	FRAAdvancedFindScope searchScope = [[FRADefaults valueForKey:@"AdvancedFindScope"] integerValue];
	
	NSEnumerator *enumerator;
	if (searchScope == FRACurrentProjectScope) {
		enumerator = [[[FRACurrentProject documentsArrayController] arrangedObjects] reverseObjectEnumerator];
	} else if (searchScope == FRAAllDocumentsScope) {
		enumerator = [[FRABasic fetchAll:@"DocumentSortKeyName"] reverseObjectEnumerator];
	} else if (searchScope == FRAParentDirectoryScope){
		enumerator = [self documentsInFolderEnumerator];
	} else {
		enumerator = [@[FRACurrentDocument] objectEnumerator];
	}
	
	return enumerator;
}

/**
 * Return an enumerator of documents based on files located in the same directory
 * as the current document.
 */
-(NSEnumerator *)documentsInFolderEnumerator
{
	NSEnumerator *enumerator;
	
	NSString *parentDirectory = [[FRACurrentDocument path] stringByDeletingLastPathComponent];
	NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
	
    if (parentDirectory && ([fileManager fileExistsAtPath:parentDirectory isDirectory:&isDir] && isDir))
    {
        if (![parentDirectory hasSuffix:@"/"]) 
        {
            parentDirectory = [parentDirectory stringByAppendingString:@"/"];
        }
		
        // this walks the |dir| recurisively and adds the paths to the |contents| set
        NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtPath:parentDirectory];
        NSString *file;
        NSString *fullyQualifiedName;
        while ((file = [directoryEnumerator nextObject]))
        {
            // make the filename |f| a fully qualifed filename
            fullyQualifiedName = [parentDirectory stringByAppendingString:file];
            if ([fileManager fileExistsAtPath:fullyQualifiedName isDirectory:&isDir] && !isDir && ([fileManager isReadableFileAtPath:fullyQualifiedName]))
            {
                // it's a file, create document and add it
				[FRAOpenSave shouldOpen:fullyQualifiedName withEncoding:0];
            }
			else {
				// no search in subdirectories
				[directoryEnumerator skipDescendents];
			}
        }
		enumerator = [[[FRACurrentProject documentsArrayController] arrangedObjects] reverseObjectEnumerator];
    }
    else
    {
		// Log the failure and return an enumerator for the current document.
        NSLog(@"%@ must be directory and must exist.\n", parentDirectory);
		enumerator = [@[FRACurrentDocument] objectEnumerator];;
    }
	
	return enumerator;
}

- (void)removeCurrentlyDisplayedDocumentInAdvancedFind
{
	[FRAInterface removeAllSubviewsFromView:resultDocumentContentView];
}


- (NSView *)resultDocumentContentView
{
	return resultDocumentContentView;
}


- (NSManagedObjectContext *)managedObjectContext
{
	return FRAManagedObjectContext;
}


- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[FRADefaults valueForKey:@"SizeOfDocumentsListTextPopUp"] integerValue] == 0) {
		[cell setFont:[NSFont systemFontOfSize:11.0]];
	} else {
		[cell setFont:[NSFont systemFontOfSize:13.0]];
	}
}	


- (NSMutableDictionary *)preparedResultDictionaryFromString:(NSString *)completeString searchStringLength:(NSInteger)searchStringLength range:(NSRange)foundRange lineNumber:(NSInteger)lineNumber document:(id)document
{
	NSMutableString *displayString = [[NSMutableString alloc] init];
	NSString *lineNumberString = [NSString stringWithFormat:@"%ld\t", (long)lineNumber];
	[displayString appendString:lineNumberString];
	NSRange linesRange = [completeString lineRangeForRange:foundRange];
	[displayString appendString:[FRAText replaceAllNewLineCharactersWithSymbolInString:[completeString substringWithRange:linesRange]]];
	
	NSMutableDictionary *node = [NSMutableDictionary dictionary];
	[node setValue:@YES forKey:@"isLeaf"];
	[node setValue:NSStringFromRange(foundRange) forKey:@"range"];
	[node setValue:[FRABasic uriFromObject:document] forKey:@"document"];
	NSInteger fontSize;
	if ([[FRADefaults valueForKey:@"SizeOfDocumentsListTextPopUp"] integerValue] == 0) {
		fontSize = 11;
	} else {
		fontSize = 13;
	}
	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:displayString attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:fontSize]}];
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[attributedString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [displayString length])];
	[attributedString applyFontTraits:NSBoldFontMask range:NSMakeRange(foundRange.location - linesRange.location + [lineNumberString length], foundRange.length)];
	[node setValue:attributedString forKey:@"displayString"];
	
	return node;
}


- (void)alertThatThisIsNotAValidRegularExpression:(NSString *)string
{
	NSString *title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ is not a valid regular expression", @"Localizable3", @"%@ is not a valid regular expression"), string];
    
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:title];
    [alert addButtonWithTitle:OK_BUTTON];
    [alert setAlertStyle:NSAlertStyleInformational];
    
    [alert beginSheetModalForWindow:advancedFindWindow completionHandler:^(NSInteger result) {
        [self.findResultsTreeController setContent:nil];
        [self.findResultsTreeController setContent:@[]];
        [self.advancedFindWindow makeKeyAndOrderFront:nil];
    }];

}


- (IBAction)searchScopeChanged:(id)sender
{
	FRAAdvancedFindScope searchScope = [sender tag];

	if (searchScope == FRACurrentDocumentScope) {
		[currentProjectScope setState:NSControlStateValueOff];
		[allDocumentsScope setState:NSControlStateValueOff];
		[currentDocumentScope setState:NSControlStateValueOn]; // If the user has clicked an already clicked button make sure it is on and not turned off
		[parentDirectoryScope setState:NSControlStateValueOff];
	} else if (searchScope == FRACurrentProjectScope) {
		[currentDocumentScope setState:NSControlStateValueOff];
		[allDocumentsScope setState:NSControlStateValueOff];
		[currentProjectScope setState:NSControlStateValueOn];
		[parentDirectoryScope setState:NSControlStateValueOff];
	} else if (searchScope == FRAAllDocumentsScope) {
		[currentDocumentScope setState:NSControlStateValueOff];
		[currentProjectScope setState:NSControlStateValueOff];
		[allDocumentsScope setState:NSControlStateValueOn];
		[parentDirectoryScope setState:NSControlStateValueOff];
	} else if (searchScope == FRAParentDirectoryScope) {
		[currentDocumentScope setState:NSControlStateValueOff];
		[currentProjectScope setState:NSControlStateValueOff];
		[allDocumentsScope setState:NSControlStateValueOff];
		[parentDirectoryScope setState:NSControlStateValueOn];
	}
	
	[FRADefaults setValue:[NSNumber numberWithInteger:searchScope] forKey:@"AdvancedFindScope"];
	
	if (![[findSearchField stringValue] isEqualToString:@""]) {
		[self findAction:nil];
	}	
}


- (IBAction)showRegularExpressionsHelpPanelAction:(id)sender
{
	[[FRAExtraInterfaceController sharedInstance] showRegularExpressionsHelpPanel];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	if ([item isLeaf] == NO) {
		return YES;
	} else {
		return NO;
	}
}

@end
