#import <Cocoa/Cocoa.h>

NSArray<NSDictionary *> *FRAReadCollectionArchive(NSData *data, NSError **error);
id FRAReadProjectArchive(NSData *data, NSError **error);

@interface FRAPreferenceArchiveTransformer : NSSecureUnarchiveFromDataTransformer
+ (id)unarchiveObjectWithData:(NSData *)data;
+ (void)resetUnsupportedPreferencesInController:(NSUserDefaultsController *)controller;
@end
