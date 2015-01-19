//
//  AppDelegate.m
//  ArchiveToIPA
//
//  Created by John Hsu on 2015/1/19.
//  Copyright (c) 2015年 com.test. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pipeCompleted:) name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
    [self refreshAction:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

#pragma mark NSBrowser
-(IBAction)refreshAction:(id)sender
{
    NSString *archivePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Xcode/Archives"];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:archivePath] includingPropertiesForKeys:@[ NSURLNameKey, NSURLIsDirectoryKey ] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
    NSMutableArray *dataArray = [NSMutableArray array];
    for (NSURL *dateDirURL in enumerator) {
        NSDirectoryEnumerator *archiveEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:dateDirURL includingPropertiesForKeys:@[ NSURLNameKey, NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
        
        for (NSURL *xcodeArchiveURL in archiveEnumerator) {
            if ([[xcodeArchiveURL absoluteString] rangeOfString:@".DS_Store"].length > 0) {
                continue;
            }
            
            NSURL *infoPListFileURL = [xcodeArchiveURL URLByAppendingPathComponent:@"Info.plist"];
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfURL:infoPListFileURL];
            [dict setObject:infoPListFileURL forKey:@"PListURL"];
            [dataArray addObject:dict];
//            [archiveInfoFileArray addObject:infoPListFileURL];
        }
    }
    dataSourceArray = dataArray;
    NSArray *allNameArray = [dataSourceArray valueForKeyPath:@"Name"];
    NSSet *allNameSet = [NSSet setWithArray:allNameArray];
    appNameArray = [allNameSet allObjects];
    appDateArray = nil;
    appProvisionArray = nil;
    [archiveBrowser reloadColumn:0];
    
    provisionArray = [NSMutableArray array];
    NSString *provisionSearchPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/MobileDevice/Provisioning Profiles"];
    for (NSString *profilePath in [[NSFileManager defaultManager] enumeratorAtPath:provisionSearchPath]) {
        NSDictionary *profileContent = [self provisioningProfileAtPath:[provisionSearchPath stringByAppendingPathComponent:profilePath]];
        if (profileContent) {
            [provisionArray addObject:profileContent];
        }
    }
    
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column
{
    if (column == 0) {
        return [appNameArray count];
    }
    else if (column == 1) {
        return [appDateArray count];
    }
    else if (column == 2) {
        return [matchedProvisionArray count];
    }
    return 0;
}

-(void)browser:(NSBrowser *)sender willDisplayCell:(NSBrowserCell *)cell atRow:(NSInteger)row column:(NSInteger)column
{
    if (column == 0) {
        [cell setTitle:appNameArray[row]];
        [cell setLeaf:NO];
    }
    else if (column == 1) {
        NSDictionary *currentItem = [appDateArray objectAtIndex:row];
        static NSDateFormatter *dateFormatter = nil;
        if (!dateFormatter) {
            dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy'年'MM'月'dd'日' HH:mm:ss"];
        }
        NSString *text = [dateFormatter stringFromDate:[currentItem objectForKey:@"CreationDate"]];
        if ([[currentItem objectForKey:@"Comment"] length] > 0) {
            text = [text stringByAppendingFormat:@" (%@)",[currentItem objectForKey:@"Comment"]];
        }
        [cell setTitle:text];
        [cell setLeaf:NO];
    }
    else if (column == 2) {
        NSDictionary *currentProvision = [matchedProvisionArray objectAtIndex:row];
        [cell setTitle:[NSString stringWithFormat:@"%@ (%@)",currentProvision[@"Name"], currentProvision[@"Entitlements"][@"application-identifier"]]];
        [cell setLeaf:YES];
    }
}

-(IBAction)broswerSelectionChanged:(NSBrowser *)sender
{
//    NSLog(@"broswerSelectionChanged");
#pragma mark selected app name, reload archives with date sorted
    NSBrowserCell *cell = [sender selectedCellInColumn:0];
    appDateArray = [[dataSourceArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"Name == %@",cell.title]] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSComparisonResult result = [[obj1 objectForKey:@"CreationDate"] compare:[obj2 objectForKey:@"CreationDate"]];
        return -result;
    }];
    [archiveBrowser reloadColumn:1];
    
#pragma mark selected app archive, display app info and icon
    NSInteger selectedArchiveIndex = [sender selectedRowInColumn:1];
    if (selectedArchiveIndex >= [appDateArray count]) {
        [appTextView setString:@""];
        appImageView.image = nil;
        matchedProvisionArray = nil;
        [sender reloadColumn:2];
        return;
    }
    NSDictionary *selectedArchive = [appDateArray objectAtIndex:selectedArchiveIndex];
    [appTextView setString:[selectedArchive description]];
    NSArray *icons = [[selectedArchive objectForKey:@"ApplicationProperties"] objectForKey:@"IconPaths"];
    unsigned long long maxImageFileSize = 0;
    NSImage *maxResolutionImage = nil;
    for (NSString *iconPath in icons) {
        NSURL *iconFileURL = [[[[selectedArchive objectForKey:@"PListURL"] URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"Products"] URLByAppendingPathComponent:iconPath];
        unsigned long long imageFileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[iconFileURL path] error:nil] fileSize];
        if (imageFileSize > maxImageFileSize) {
            maxImageFileSize = imageFileSize;
            maxResolutionImage = [[NSImage alloc] initWithContentsOfURL:iconFileURL];
        }
    }
    appImageView.image = maxResolutionImage;
    NSString *bundleIdentifier = [[selectedArchive objectForKey:@"ApplicationProperties"] objectForKey:@"CFBundleIdentifier"];
#pragma mark selected app archive, find appropriate provision profile
    NSArray *archiveIdentifierComponents = [bundleIdentifier componentsSeparatedByString:@"."];
//    NSLog(@"bundle id:%@",bundleIdentifier);
    matchedProvisionArray = [NSMutableArray array];
    for (NSDictionary *provisionContent in provisionArray) {
        NSString *provisionBundleIdentifier = provisionContent[@"Entitlements"][@"application-identifier"];
        NSMutableArray *provisionIdentifierComponents = [[provisionBundleIdentifier componentsSeparatedByString:@"."] mutableCopy];
        // remove first team id component
        [provisionIdentifierComponents removeObjectAtIndex:0];
        BOOL bundleIDMatch = YES;
//        NSLog(@"testing with %@", provisionBundleIdentifier);
        for (int i=0; i<[archiveIdentifierComponents count] && i<[provisionIdentifierComponents count]; i++) {
            if (![archiveIdentifierComponents[i] isEqualToString:provisionIdentifierComponents[i]] && ![provisionIdentifierComponents[i] hasPrefix:@"*"]) {
                bundleIDMatch &= NO;
            }
        }
        
        if (bundleIDMatch) {
//            NSLog(@"found match:%@",provisionBundleIdentifier);
            [matchedProvisionArray addObject:provisionContent];
        }
    }
    [sender reloadColumn:2];
}


-(IBAction)exportAction:(id)sender
{
    NSInteger selectedProfileIndex = [archiveBrowser selectedRowInColumn:2];
    if (selectedProfileIndex >= [matchedProvisionArray count]) {
        return;
    }
    NSInteger selectedArchiveIndex = [archiveBrowser selectedRowInColumn:1];
    NSDictionary *selectedArchive = [appDateArray objectAtIndex:selectedArchiveIndex];

    NSString *selectedArchivePath = [[[selectedArchive objectForKey:@"PListURL"] URLByDeletingLastPathComponent] path];
    NSString *selectedProvisionName = [[matchedProvisionArray objectAtIndex:selectedProfileIndex] objectForKey:@"Name"];
    
    NSDateFormatter *outputFileFormatter = [[NSDateFormatter alloc] init];
    [outputFileFormatter setDateFormat:@"MMddahhmm"];
    [outputFileFormatter setAMSymbol:@"AM"];
    [outputFileFormatter setPMSymbol:@"PM"];

    NSString *downloadPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.ipa",[selectedArchive objectForKey:@"Name"],[outputFileFormatter stringFromDate:[NSDate date]]]];
    NSLog(@"==\n archive %@ with %@ output to %@",selectedArchivePath, selectedProvisionName,downloadPath);
    NSString *commandLine = [NSString stringWithFormat:@"xcodebuild -exportArchive -archivePath \"%@\" -exportPath \"%@\" -exportFormat ipa -exportProvisioningProfile '%@'",selectedArchivePath,downloadPath, selectedProvisionName];
    
    [exportTextView setString:@""];
    [exportButton setEnabled:NO];
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[ @"-c", commandLine ]];
    NSPipe *pipe = [[NSPipe alloc] init];
    [task setStandardOutput:pipe];
    NSFileHandle *readingFileHandle = [pipe fileHandleForReading];
    [readingFileHandle readToEndOfFileInBackgroundAndNotify];
    

    [task launch];
    
}

-(void)pipeCompleted:(NSNotification *)notif
{
    NSData *data = [[notif userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *wholeString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [exportTextView setString:wholeString];
    [exportTextView scrollRangeToVisible:NSMakeRange(wholeString.length - 2, 1)];
    [exportButton setEnabled:YES];

}

#pragma mark provision profile reading
- (NSDictionary *)provisioningProfileAtPath:(NSString *)path
{
    CMSDecoderRef decoder = NULL;
    CFDataRef dataRef = NULL;
    NSString *plistString = nil;
    NSDictionary *plist = nil;
    
    @try {
        CMSDecoderCreate(&decoder);
        NSData *fileData = [NSData dataWithContentsOfFile:path];
        CMSDecoderUpdateMessage(decoder, fileData.bytes, fileData.length);
        CMSDecoderFinalizeMessage(decoder);
        CMSDecoderCopyContent(decoder, &dataRef);
        plistString = [[NSString alloc] initWithData:(__bridge NSData *)dataRef encoding:NSUTF8StringEncoding];
        NSData *plistData = [plistString dataUsingEncoding:NSUTF8StringEncoding];
        plist = [NSPropertyListSerialization propertyListFromData:plistData mutabilityOption:NSPropertyListImmutable format:nil errorDescription:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"Could not decode file.\n");
    }
    @finally {
        if (decoder) CFRelease(decoder);
        if (dataRef) CFRelease(dataRef);
    }
    
    return plist;
}

@end
