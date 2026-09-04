/*
 Erbele - Based on Fraise 3.7.3 based on Smultron by Peter Borg
 
 Current Maintainer (since 2016): 
 Andreas Bentele: abentele.github@icloud.com (https://github.com/abentele/Erbele)
 
 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

#import "FRADocumentsListCell.h"

@implementation FRADocumentsListCell

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.textField.delegate = self;
}

- (void)viewWillDraw
{
    self.textField.font = [NSFont systemFontOfSize:[[FRADefaults valueForKey:@"SizeOfDocumentsListTextPopUp"] integerValue] == 0 ? 11 : 13];
    if (self.imageView && self.objectValue) {
        id document = self.objectValue;
        self.imageView.image = [document valueForKey:[[document valueForKey:@"isEdited"] boolValue] ? @"unsavedIcon" : @"icon"];
        self.textField.stringValue = [document valueForKey:[[FRADefaults valueForKey:@"ShowFullPathInDocumentsList"] boolValue] ? @"nameWithPath" : @"name"] ?: @"";
        self.toolTip = [[document valueForKey:@"isNewDocument"] boolValue] ? UNSAVED_STRING :
            [document valueForKey:[[document valueForKey:@"fromExternal"] boolValue] ? @"externalPath" : @"path"];
    }
    [super viewWillDraw];
}

- (void)layout
{
    [super layout];
    CGFloat inset = 2;
    if (self.imageView) {
        CGFloat size = MAX(0, NSHeight(self.bounds) - 1);
        self.imageView.frame = NSMakeRect(0, 0, size, size);
        inset = size + 3;
    }
    CGFloat height = ceil(self.textField.font.ascender - self.textField.font.descender + 3);
    self.textField.frame = NSMakeRect(inset, floor((NSHeight(self.bounds) - height) / 2), MAX(0, NSWidth(self.bounds) - inset - 2), height);
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if ([notification.userInfo[@"NSTextMovement"] integerValue] == NSReturnTextMovement) {
        [self.window makeFirstResponder:self.enclosingScrollView.documentView];
    }
}

@end
