//
//  AppDelegate.m
//  ArchiveToIPA
//
//  Created by John Hsu on 2015/1/19.
//  Copyright (c) 2015年 com.test. All rights reserved.
//

#import "AppDelegate.h"
#import "AFNetworking.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    NSURL *downloadFolder = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"]];
    if (downloadFolder) {
        [crashFileControl setURL:downloadFolder];
    }
    
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
            if (dict) {
                [dataArray addObject:dict];
            }
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
    exportBundleID = bundleIdentifier;
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

    exportPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@.ipa",[selectedArchive objectForKey:@"Name"],[outputFileFormatter stringFromDate:[NSDate date]]]];
    NSLog(@"==\n archive %@ with %@ output to %@",selectedArchivePath, selectedProvisionName,exportPath);
    NSString *commandLine = [NSString stringWithFormat:@"xcodebuild -exportArchive -archivePath \"%@\" -exportPath \"%@\" -exportFormat ipa -exportProvisioningProfile '%@'",selectedArchivePath,exportPath, selectedProvisionName];
    
    if (enterpriseButton.state != NSOffState) {
        commandLine = [NSString stringWithFormat:@"xcrun -sdk iphoneos PackageApplication -v \"%@\" -o \"%@\"",[[selectedArchivePath stringByAppendingPathComponent:@"Products"] stringByAppendingPathComponent:selectedArchive[@"ApplicationProperties"][@"ApplicationPath"]],exportPath];
    }
    
    
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
    
    if (enableOTAButton.state == NSOffState) {
        [exportButton setEnabled:YES];
    }
    else {
        if (![[NSFileManager defaultManager] fileExistsAtPath:exportPath]) {
            [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload failed:ipa file not found (maybe export failed)"] runModal];
            [exportButton setEnabled:YES];
            return;
        }
#pragma mark upload to ota server
        
        NSDictionary *otaSettings = [NSDictionary dictionaryWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"server.plist"]];
        //    NSURL *serviceURL = [NSURL URLWithString:otaSettings[@"addr"]];
        if (!otaSettings) {
            [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload failed:ota server config file not found"] runModal];
            [exportButton setEnabled:YES];
            return;
        }
        NSString *postURLString = otaSettings[@"api"];
        NSString *ipaFileStorage = otaSettings[@"storage"];
        
        NSString *ipaFileName = [[exportPath lastPathComponent] stringByDeletingPathExtension];
        
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        NSDictionary *parameters = @{};
        NSURL *filePath = [NSURL fileURLWithPath:exportPath];
#pragma mark generate download link html
        NSString *htmlDataString = [NSString stringWithFormat:@"<a href=\"itms-services://?action=download-manifest&url=%@\"><font size=\"10\">(Click this link on your device)<br>Install %@</font></a><hr>or<a href=\"%@\"><font size=\"10\">directly download ipa file</font></a>",[ipaFileStorage stringByAppendingFormat:@"/%@.plist",ipaFileName],ipaFileName,[ipaFileStorage stringByAppendingFormat:@"/%@.ipa",ipaFileName]];
        
#pragma mark generate download info plist
        NSString *infoDataString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ipa" ofType:@"plist"] encoding:NSUTF8StringEncoding error:nil];
        infoDataString = [infoDataString stringByReplacingOccurrencesOfString:@"__URL__" withString:[ipaFileStorage stringByAppendingFormat:@"/%@.ipa",ipaFileName]];
        infoDataString = [infoDataString stringByReplacingOccurrencesOfString:@"__BID__" withString:exportBundleID];
        infoDataString = [infoDataString stringByReplacingOccurrencesOfString:@"__TITLE__" withString:ipaFileName];

#pragma mark generate NSMutableURLRequest with multipart post
        NSError *serializationError = nil;
        NSMutableURLRequest *request = [manager.requestSerializer multipartFormRequestWithMethod:@"POST" URLString:[[NSURL URLWithString:postURLString] absoluteString] parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            [formData appendPartWithFileURL:filePath name:@"file" error:nil];
            [formData appendPartWithFileData:[htmlDataString dataUsingEncoding:NSUTF8StringEncoding] name:@"html" fileName:[ipaFileName stringByAppendingPathExtension:@"html"] mimeType:@"text/html"];
            [formData appendPartWithFileData:[infoDataString dataUsingEncoding:NSUTF8StringEncoding] name:@"plist" fileName:[ipaFileName stringByAppendingPathExtension:@"plist"] mimeType:@"application/xml"];

        } error:&serializationError];
        if (serializationError) {
            [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload failed:unable to upload file"] runModal];
            [exportButton setEnabled:YES];
            return;
        }
        [request setValue:otaSettings[@"auth"] forHTTPHeaderField:@"Authorization"];
        
        AFHTTPRequestOperation *operation = [manager HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, NSArray * responseObject) {
            [exportButton setEnabled:YES];
            if (![responseObject isKindOfClass:[NSArray class]]) {
                [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload failed: unexpected response"] runModal];
                return ;
            }
            if ([responseObject count] != 3) {
                [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload failed: unexpected response array count"] runModal];
                return;
            }
            
            [[NSAlert alertWithMessageText:@"Finished " defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload success:\n%@",[ipaFileStorage stringByAppendingFormat:@"/%@.html",ipaFileName]] runModal];
            NSLog(@"Success: %@", responseObject);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [exportButton setEnabled:YES];
            [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"upload failed"] runModal];
            NSLog(@"Error: %@", error);
        }];
        
        [manager.operationQueue addOperation:operation];
#pragma mark end of upload to ota server

    }
    
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


#pragma mark Symbolize crash file
-(IBAction)symbolizeCrashFileAction:(id)sender
{
//    NSInteger selectedProfileIndex = [archiveBrowser selectedRowInColumn:2];
//    if (selectedProfileIndex >= [matchedProvisionArray count]) {
//        return;
//    }
    NSInteger selectedArchiveIndex = [archiveBrowser selectedRowInColumn:1];
    if (selectedArchiveIndex >= [appDateArray count]) {
        [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please specify an archive"] runModal];
        return;
    }
    NSDictionary *selectedArchive = [appDateArray objectAtIndex:selectedArchiveIndex];
    
    NSString *selectedArchivePath = [[[selectedArchive objectForKey:@"PListURL"] URLByDeletingLastPathComponent] path];

    
    
    NSURL *url = [crashFileControl URL];
    if (![[[[url lastPathComponent] pathExtension] lowercaseString] isEqualToString:@"crash"]) {
        [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please select a correct .crash file"] runModal];
        return;
    }
    NSString *crashFilePath = [url path];
    NSString *toolPath = @"/Applications/Xcode.app/Contents/SharedFrameworks/DTDeviceKitBase.framework/Versions/A/Resources/symbolicatecrash";
    if (![[NSFileManager defaultManager] fileExistsAtPath:toolPath]) {
        [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Symbolize tool not found, please install new version of XCode"] runModal];
        return;
    }
    NSString *preCommand = @"export DEVELOPER_DIR=\"/Applications/XCode.app/Contents/Developer\"";
    NSString *dsymPath = nil;
    
    NSString *dsymSearchPath = [selectedArchivePath stringByAppendingPathComponent:@"dSYMs"];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dsymSearchPath];
    NSString *scanPath = nil;
    while (scanPath = [enumerator nextObject]) {
        if ([[[[scanPath lastPathComponent] pathExtension] lowercaseString] isEqualToString:@"dsym"]) {
            dsymPath = [dsymSearchPath stringByAppendingPathComponent:scanPath];
            break;
        }
    }
    // find dsym file
    
    if (!dsymPath) {
        [[NSAlert alertWithMessageText:@"Error" defaultButton:@"Close" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Unable to find a dsym file in selected archive"] runModal];
        return;
    }
    
    
    NSDateFormatter *outputFileFormatter = [[NSDateFormatter alloc] init];
    [outputFileFormatter setDateFormat:@"MMddahhmm"];
    [outputFileFormatter setAMSymbol:@"AM"];
    [outputFileFormatter setPMSymbol:@"PM"];
    
    exportPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"] stringByAppendingPathComponent:[NSString stringWithFormat:@"crash_symbolized_%@_%@.crash",[selectedArchive objectForKey:@"Name"],[outputFileFormatter stringFromDate:[NSDate date]]]];
    
    NSString *commandLine = [preCommand stringByAppendingFormat:@"; %@ \"%@\" \"%@\" > \"%@\"; open %@",toolPath,crashFilePath,dsymPath,exportPath,exportPath];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:@[ @"-c", commandLine ]];
    [task launch];

}
@end
