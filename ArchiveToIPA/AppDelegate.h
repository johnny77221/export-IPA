//
//  AppDelegate.h
//  ArchiveToIPA
//
//  Created by John Hsu on 2015/1/19.
//  Copyright (c) 2015年 com.test. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSBrowserDelegate>
{
    NSArray *dataSourceArray;

    // for first column
    NSArray *appNameArray;
    
    // for second column
    NSArray *appDateArray;
    
    // for third column
    NSArray *appProvisionArray;
    
    IBOutlet NSBrowser *archiveBrowser;
    IBOutlet NSImageView *appImageView;
    IBOutlet NSTextView *appTextView;
    
    IBOutlet NSTextView *exportTextView;

    NSMutableArray *provisionArray;
    NSMutableArray *matchedProvisionArray;
    IBOutlet NSButton *exportButton;

    NSString *exportPath;
    NSString *exportBundleID;
    NSString *exportBundleVersion;


    IBOutlet NSButton *enableOTAButton;
    IBOutlet NSButton *enterpriseButton;

    
    IBOutlet NSPathControl *crashFileControl;

    NSString *archiveTeamID;
    BOOL isDistribution;
    NSString *archiveName;
    NSString *archiveTime;
}

@end

