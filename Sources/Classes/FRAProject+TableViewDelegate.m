/*
 Erbele - Based on Fraise 3.7.3 based on Smultron by Peter Borg
 
 Current Maintainer (since 2016): 
 Andreas Bentele: abentele.github@icloud.com (https://github.com/abentele/Erbele)
 
 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
*/

#import "FRAProject+TableViewDelegate.h"
#import "FRAApplicationDelegate.h"
#import "FRAInterfacePerformer.h"
#import "FRAVariousPerformer.h"
#import "FRALineNumbers.h"
#import "FRAProject+DocumentViewsController.h"

@implementation FRAProject (TableViewDelegate)


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSTableView *tableView = [aNotification object];
	if (tableView == [self documentsTableView] || aNotification == nil) {
		if ([[FRAApplicationDelegate sharedInstance] isTerminatingApplication] == YES) {
			return;
		}
		if ([[[self documentsArrayController] arrangedObjects] count] < 1 || [[[self documentsArrayController] selectedObjects] count] < 1) {
			[self updateWindowTitleBarForDocument:nil];
			return;
		}
		
		id document = [[self documentsArrayController] selectedObjects][0];
		
		[self performInsertFirstDocument:document];
	}
	
}


- (void)performInsertFirstDocument:(id)document
{	
	[self setFirstDocument:document];
	
	[FRAInterface removeAllSubviewsFromView:firstContentView];
	[firstContentView addSubview:[document valueForKey:@"firstTextScrollView"]];
	if ([[document valueForKey:@"showLineNumberGutter"] boolValue] == YES) {
		[firstContentView addSubview:[document valueForKey:@"firstGutterScrollView"]];
	}
	
	[self updateWindowTitleBarForDocument:document];
	[self resizeViewsForDocument:document]; // If the window has changed since the view was last visible
	[[self documentsTableView] scrollRowToVisible:[[self documentsTableView] selectedRow]];
	
	[[self window] makeFirstResponder:[document valueForKey:@"firstTextView"]];
	[[document valueForKey:@"lineNumbers"] updateLineNumbersForClipView:[[document valueForKey:@"firstTextScrollView"] contentView] checkWidth:NO recolour:YES]; // If the window has changed since the view was last visible
	[FRAInterface updateStatusBar];
	
}

@end
