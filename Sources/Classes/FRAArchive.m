#import "FRAArchive.h"

static BOOL FRAArchiveContainsAllowedClasses(id object, NSSet<Class> *classes, NSUInteger depth)
{
    // Saved preferences and project dictionaries are shallow; reject cycles and excessive nesting.
    if (depth > 64) return NO;
    BOOL allowed = NO;
    for (Class cls in classes) {
        if ([object isKindOfClass:cls]) {
            allowed = YES;
            break;
        }
    }
    if (!allowed) return NO;
    if ([object isKindOfClass:[NSArray class]]) {
        for (id value in object) {
            if (!FRAArchiveContainsAllowedClasses(value, classes, depth + 1)) return NO;
        }
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        for (id key in object) {
            if (!FRAArchiveContainsAllowedClasses(key, classes, depth + 1) ||
                !FRAArchiveContainsAllowedClasses(object[key], classes, depth + 1)) return NO;
        }
    }
    return YES;
}

static id FRAReadArchive(NSData *data, NSSet<Class> *classes, NSError **error)
{
    if (error) *error = nil;
    @try {
        if ([data isKindOfClass:[NSData class]] && data.length > 0) {
            id object = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:error];
            if (FRAArchiveContainsAllowedClasses(object, classes, 0)) return object;
        }
    } @catch (NSException *exception) {
        // Report malformed archives through the same error path as keyed decoding.
    }
    if (error && !*error) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
    }
    return nil;
}

static BOOL FRAArchiveFieldsHaveClass(NSDictionary *record, NSArray<NSString *> *keys, Class cls)
{
    for (NSString *key in keys) {
        if (record[key] && ![record[key] isKindOfClass:cls]) return NO;
    }
    return YES;
}

NSArray<NSDictionary *> *FRAReadCollectionArchive(NSData *data, NSError **error)
{
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSDictionary class], [NSString class], [NSNumber class], nil];
    id records = FRAReadArchive(data, classes, error);
    BOOL valid = [records isKindOfClass:[NSArray class]];
    if (valid) {
        for (id record in records) {
            if (![record isKindOfClass:[NSDictionary class]] ||
                ![record[@"name"] isKindOfClass:[NSString class]] ||
                ![record[@"text"] isKindOfClass:[NSString class]] ||
                ![record[@"collectionName"] isKindOfClass:[NSString class]] ||
                !FRAArchiveFieldsHaveClass(record, @[@"shortcutDisplayString", @"shortcutMenuItemKeyString", @"interpreter"], [NSString class]) ||
                !FRAArchiveFieldsHaveClass(record, @[@"shortcutModifier", @"sortOrder", @"version", @"inline"], [NSNumber class])) {
                valid = NO;
                break;
            }
        }
    }
    if (valid) return records;
    if (error && !*error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
    return nil;
}

id FRAReadProjectArchive(NSData *data, NSError **error)
{
    NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSDictionary class], [NSString class], [NSNumber class], nil];
    id project = FRAReadArchive(data, classes, error);
    id documents = project;
    if ([project isKindOfClass:[NSDictionary class]]) {
        documents = project[@"documentsArray"];
        if (!FRAArchiveFieldsHaveClass(project, @[@"windowFrame", @"selectedDocumentName"], [NSString class]) ||
            !FRAArchiveFieldsHaveClass(project, @[@"view", @"viewSize", @"dividerPosition", @"version"], [NSNumber class])) documents = nil;
    }
    BOOL valid = [documents isKindOfClass:[NSArray class]];
    if (valid) {
        for (id document in documents) {
            if (![document isKindOfClass:[NSDictionary class]] ||
                ![document[@"path"] isKindOfClass:[NSString class]] ||
                !FRAArchiveFieldsHaveClass(document, @[@"selectedRange"], [NSString class]) ||
                !FRAArchiveFieldsHaveClass(document, @[@"encoding", @"sortOrder"], [NSNumber class])) {
                valid = NO;
                break;
            }
        }
    }
    if (valid) return project;
    if (error && !*error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
    return nil;
}

@implementation FRAPreferenceArchiveTransformer

+ (NSArray<Class> *)allowedTopLevelClasses
{
    return @[[NSFont class], [NSColor class]];
}

+ (id)unarchiveObjectWithData:(NSData *)data
{
    return FRAReadArchive(data, [NSSet setWithArray:self.allowedTopLevelClasses], nil);
}

+ (void)resetUnsupportedPreferencesInController:(NSUserDefaultsController *)controller
{
    for (NSString *key in controller.initialValues) {
        id initialData = controller.initialValues[key];
        if (![initialData isKindOfClass:[NSData class]]) continue;
        id initialValue = [self unarchiveObjectWithData:initialData];
        if (!initialValue) continue;
        Class expectedClass = [initialValue isKindOfClass:[NSFont class]] ? [NSFont class] : [NSColor class];
        id value = [self unarchiveObjectWithData:[controller.values valueForKey:key]];
        if (![value isKindOfClass:expectedClass]) {
            [controller.values setValue:initialData forKey:key];
        }
    }
}

- (id)transformedValue:(id)value
{
    return [[self class] unarchiveObjectWithData:value];
}

@end
