/*
 Erbele - Based on Fraise 3.7.3 based on Smultron by Peter Borg

 Current Maintainer (since 2016):
 Andreas Bentele: abentele.github@icloud.com (https://github.com/abentele/Erbele)

 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
*/

#import "FRAPreviewController.h"
#import "FRAProjectsController.h"
#import "FRABasicPerformer.h"
#import "FRAProject.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// A page loaded with -loadHTMLString:baseURL: or -loadData:… is not allowed to read
// file: URLs, so a document previewed from disk is served through this private scheme
// instead: relative style sheets and images then resolve against the document's own
// directory and are read back by -webView:startURLSchemeTask:.
static NSString * const FRAPreviewScheme = @"erbele-preview";

@implementation FRAPreviewController

@synthesize previewWindow;

static id sharedInstance = nil;

+ (FRAPreviewController *)sharedInstance
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


- (void)showPreviewWindow
{
	if (previewWindow != nil) {
		[previewWindow close];
	}

    [[NSBundle mainBundle] loadNibNamed:@"FRAPreview" owner:self topLevelObjects:nil]; // Otherwise the web view is left detached from the window the second time it loads

	[self insertWebView];
	[previewWindow makeKeyAndOrderFront:self];

	[self reload];
}


// The web view is built in code because a scheme handler can only be registered on the
// configuration a WKWebView is created with; the nib holds an empty view in its place.
- (void)insertWebView
{
	WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
	[configuration setURLSchemeHandler:self forURLScheme:FRAPreviewScheme];
	[configuration setWebsiteDataStore:[WKWebsiteDataStore nonPersistentDataStore]]; // Nothing a preview loads should outlive it

	webView = [[WKWebView alloc] initWithFrame:[webViewContainer bounds] configuration:configuration];
	[webView setNavigationDelegate:self];
	[webView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[webViewContainer addSubview:webView];
	[NSLayoutConstraint activateConstraints:@[
		[[webView leadingAnchor] constraintEqualToAnchor:[webViewContainer leadingAnchor]],
		[[webView trailingAnchor] constraintEqualToAnchor:[webViewContainer trailingAnchor]],
		[[webView topAnchor] constraintEqualToAnchor:[webViewContainer topAnchor]],
		[[webView bottomAnchor] constraintEqualToAnchor:[webViewContainer bottomAnchor]]
	]];
}


- (void)reload
{
	if (webView == nil) {
		return;
	}

	// WKWebView reports its scroll offset through JavaScript only, so the page is
	// reloaded from the completion handler, once the offset to restore is known.
	[webView evaluateJavaScript:@"[window.scrollX, window.scrollY]" completionHandler:^(id result, NSError *error) {
		NSArray *offset = [result isKindOfClass:[NSArray class]] ? result : nil;
		if ([offset count] == 2) {
			self->scrollPoint = NSMakePoint([offset[0] doubleValue], [offset[1] doubleValue]);
		} else {
			self->scrollPoint = NSZeroPoint;
		}
		[self loadPreview];
	}];
}


- (void)loadPreview
{
	if ([FRACurrentProject areThereAnyDocuments]) {

		NSURL *baseURL;
		if ([[FRADefaults valueForKey:@"BaseURL"] isEqualToString:@""]) { // If no base URL is supplied use the document path
			if ([[FRACurrentDocument valueForKey:@"isNewDocument"] boolValue] == NO) {
				NSString *path = [NSString stringWithString:[FRACurrentDocument valueForKey:@"path"]];
				baseURL = [NSURL fileURLWithPath:path];
			} else {
				baseURL = nil;
			}
		} else {
			baseURL = [NSURL URLWithString:[[FRADefaults valueForKey:@"BaseURL"] stringByAppendingPathComponent:[FRACurrentDocument valueForKey:@"name"]]];
		}

		if ([FRACurrentDocument valueForKey:@"path"] != nil) {
			NSString *path;
			if ([[FRACurrentDocument valueForKey:@"fromExternal"] boolValue] == NO) {
				path = [FRACurrentDocument valueForKey:@"path"];
			} else {
				path = [FRACurrentDocument valueForKey:@"externalPath"];
			}
			[previewWindow setTitle:[NSString stringWithFormat:@"%@ - %@", path, PREVIEW_STRING]];
		} else {
			[previewWindow setTitle:[NSString stringWithFormat:@"%@ - %@", [FRACurrentDocument valueForKey:@"name"], PREVIEW_STRING]];
		}
        [previewParserSelector selectItemAtIndex:[[FRACurrentDocument valueForKey:@"documentPreviewParser"] integerValue]];
		NSData *data;
        if ([[FRACurrentDocument valueForKey:@"documentPreviewParser"] integerValue] == FRAPreviewHTML) { //for previewParser
			data = [FRACurrentText dataUsingEncoding:NSUTF8StringEncoding];
		} else {
			NSString *temporaryPathMarkdown = [FRABasic genererateTemporaryPath];
			[FRACurrentText writeToFile:temporaryPathMarkdown atomically:YES encoding:[[FRACurrentDocument valueForKey:@"encoding"] integerValue] error:nil];
			NSString *temporaryPathHTML = [FRABasic genererateTemporaryPath];
			NSString *htmlString;
			if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryPathMarkdown]) {
                if ([[FRACurrentDocument valueForKey:@"documentPreviewParser"] integerValue] == FRAPreviewMarkdown) { //for previewParser
					system([[NSString stringWithFormat:@"/usr/bin/perl %@ %@ > %@", [[NSBundle mainBundle] pathForResource:@"Markdown" ofType:@"pl"], temporaryPathMarkdown, temporaryPathHTML] UTF8String]);
				} else {
					system([[NSString stringWithFormat:@"/usr/bin/perl %@ %@ > %@", [[NSBundle mainBundle] pathForResource:@"MultiMarkdown" ofType:@"pl"], temporaryPathMarkdown, temporaryPathHTML] UTF8String]);
				}
				if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryPathMarkdown]) {
					htmlString = [NSString stringWithContentsOfFile:temporaryPathHTML encoding:[[FRACurrentDocument valueForKey:@"encoding"] integerValue] error:nil];
					[[NSFileManager defaultManager] removeItemAtPath:temporaryPathHTML error:nil];
				} else {
					htmlString = FRACurrentText;
				}
				[[NSFileManager defaultManager] removeItemAtPath:temporaryPathMarkdown error:nil];
			} else {
				htmlString = FRACurrentText;
			}
			data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
		}

		if (baseURL == nil || [baseURL isFileURL] || [baseURL scheme] == nil) {
			[self loadPreviewData:data forFileURL:baseURL];
		} else { // A base URL pointing somewhere else, typically a web server, is loaded as it is
			[webView loadData:data MIMEType:@"text/html" characterEncodingName:@"utf-8" baseURL:baseURL];
		}
	} else {
		[webView loadHTMLString:@"" baseURL:nil];
		[previewWindow setTitle:PREVIEW_STRING];
        [previewParserSelector selectItemAtIndex:[[FRADefaults valueForKey:@"PreviewParser"] integerValue]];
        [previewParserSelector setHidden:YES];
	}

}


// Serves the document at its own location so that anything it refers to relatively is
// looked up next to it. A document that was never saved has no directory to resolve
// against, and only the page itself is served.
- (void)loadPreviewData:(NSData *)data forFileURL:(NSURL *)fileURL
{
	previewData = (data != nil) ? data : [NSData data];
	if ([fileURL isFileURL]) {
		previewPath = [fileURL path];
		previewDirectory = [previewPath stringByDeletingLastPathComponent];
	} else {
		previewPath = @"/";
		previewDirectory = nil;
	}
	previewGeneration++;

	NSURLComponents *components = [[NSURLComponents alloc] init];
	[components setScheme:FRAPreviewScheme];
	[components setHost:@""];
	[components setPath:previewPath];
	[components setQuery:[NSString stringWithFormat:@"reload=%lu", (unsigned long)previewGeneration]]; // Keeps a reloaded page from being answered out of the memory cache

	[webView loadRequest:[NSURLRequest requestWithURL:[components URL]]];
}


- (IBAction)reloadAction:(id)sender
{
	[self reload];
}

- (IBAction)parserChanged:(id)sender { //for previewParser
    [FRACurrentDocument setValue:@([previewParserSelector indexOfSelectedItem]) forKey:@"documentPreviewParser"];
    [self reload];
}


- (void)liveUpdate
{
	if (previewWindow != nil && [previewWindow isVisible]) {
		[self reload];
	}
}


- (void)webView:(WKWebView *)sender didFinishNavigation:(WKNavigation *)navigation
{
	if (NSEqualPoints(scrollPoint, NSZeroPoint)) {
		return;
	}

	[webView evaluateJavaScript:[NSString stringWithFormat:@"window.scrollTo(%f, %f);", scrollPoint.x, scrollPoint.y] completionHandler:nil];
}


- (void)webView:(WKWebView *)sender startURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
	NSURL *url = [[urlSchemeTask request] URL];
	NSString *path = [url path];
	NSData *data = nil;
	NSString *mimeType = nil;

	if (previewData != nil && [path isEqualToString:previewPath]) {
		data = previewData;
		mimeType = @"text/html; charset=utf-8";
	} else if ([self isPathInsidePreviewDirectory:path]) {
		data = [NSData dataWithContentsOfFile:path];
		mimeType = [self MIMETypeForPath:path];
	}

	if (data == nil) {
		[urlSchemeTask didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil]];
		return;
	}

	NSDictionary *headerFields = @{@"Content-Type": mimeType,
								   @"Content-Length": [NSString stringWithFormat:@"%lu", (unsigned long)[data length]],
								   @"Cache-Control": @"no-store"}; // A preview always shows what is on disk right now
	NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];

	[urlSchemeTask didReceiveResponse:response];
	[urlSchemeTask didReceiveData:data];
	[urlSchemeTask didFinish];
}


- (void)webView:(WKWebView *)sender stopURLSchemeTask:(id <WKURLSchemeTask>)urlSchemeTask
{
	// Every task is answered before it returns, so there is nothing left to cancel
}


// Everything the preview serves shares one origin, so the page could read back whatever
// it is given: it is confined to the directory the document itself lives in.
- (BOOL)isPathInsidePreviewDirectory:(NSString *)path
{
	if (previewDirectory == nil) {
		return NO;
	}

	NSString *directory = [previewDirectory stringByStandardizingPath];
	if ([directory hasSuffix:@"/"] == NO) {
		directory = [directory stringByAppendingString:@"/"];
	}

	return [[path stringByStandardizingPath] hasPrefix:directory];
}


- (NSString *)MIMETypeForPath:(NSString *)path
{
	NSString *mimeType = [[UTType typeWithFilenameExtension:[path pathExtension]] preferredMIMEType];
	if (mimeType == nil) {
		mimeType = @"application/octet-stream";
	}

	return mimeType;
}
@end
