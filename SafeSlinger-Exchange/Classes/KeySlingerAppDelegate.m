/*
 * The MIT License (MIT)
 * 
 * Copyright (c) 2010-2014 Carnegie Mellon University
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "KeySlingerAppDelegate.h"
#import "VersionCheckMarco.h"
#import <Crashlytics/Crashlytics.h>
#import "Utility.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAAnalytics.h"
#import "UAConfig.h"
#import "ErrorLogger.h"
#import "SSEngine.h"

@implementation KeySlingerAppDelegate

@synthesize window, documentsPath, myID, vCardString;
@synthesize contactView, exchangeView, activityView, passView;
@synthesize navController;
@synthesize tempralPINCode, myName;
@synthesize msgList;
@synthesize hasAccess, hasContactPrivacy;
@synthesize mainView, setupView, systemView;
@synthesize backtool, icloud_timer;
@synthesize DbInstance, firstSetup;
@synthesize msgDetail;
@synthesize SelfPhotoCache;

#pragma mark -
#pragma mark Application lifecycle

-(NSString*) getVersionNumber
{
#ifdef BETA
    return [NSString stringWithFormat:@"%@-beta", [[[NSBundle mainBundle] infoDictionary]objectForKey: @"CFBundleVersion"]];
#else
    return [[[NSBundle mainBundle] infoDictionary]objectForKey: @"CFBundleVersion"];
#endif
}

-(int) getVersionNumberByInt
{
    NSArray *versionArray = [[[[NSBundle mainBundle] infoDictionary]objectForKey: @"CFBundleVersion"] componentsSeparatedByString:@"."];
    
    int version = 0;
    for(int i=0;i<[versionArray count];i++)
    {
        NSString* tmp = [versionArray objectAtIndex:i];
        version = version | ([tmp intValue] << (8*(3-i)));
    }
    return version;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Crashlytics startWithAPIKey:@"a9f2629c171299fa2ff44a07abafb7652f4e1d5c"];
    [[Crashlytics sharedInstance]setDebugMode:YES];
    
    // used to trigger contact book access right dialog..
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if(!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        }
    });
    if(aBook)CFRelease(aBook);
    
    // get document path
	NSArray *arr = [[NSArray alloc] initWithArray: NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)];
	self.documentsPath = [arr objectAtIndex: 0];
	[arr release];
    
    // Prepare Database Object
    DbInstance = [[SafeSlingerDB alloc]init];
    [DbInstance LoadDBFromStorage: nil];
    
    // Override point for customization after application launch.
    self.hasAccess = NO;
    self.hasContactPrivacy = YES;
    self.firstSetup = NO;
    self.backtool = [[BackupCloudUtility alloc]init];
    
    [self.window setFrame:[[UIScreen mainScreen] bounds]];
    self.activityView = [[ActivityWindow alloc] initWithNibName: @"ActivityWindow" bundle: nil];
    
    // UI initializations
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if(IS_4InchScreen)
        {
            self.passView = [[Passphase alloc] initWithNibName: @"Passphase_4in" bundle: nil];
            self.contactView = [[ContactViewController alloc] initWithNibName:@"ContactViewController_4in" bundle:nil];
            self.setupView = [[SetupPanelViewController alloc] initWithNibName:@"SetupPanelViewController_4in" bundle:nil];
            self.exchangeView = [[ExchangeViewController alloc] initWithNibName: @"ExchangeViewController_4in" bundle: nil];
        }else{
            self.passView = [[Passphase alloc] initWithNibName: @"Passphase" bundle: nil];
            self.contactView = [[ContactViewController alloc] initWithNibName:@"ContactViewController" bundle:nil];
            self.setupView = [[SetupPanelViewController alloc] initWithNibName:@"SetupPanelViewController" bundle:nil];
            self.exchangeView = [[ExchangeViewController alloc] initWithNibName: @"ExchangeViewController" bundle: nil];
        }
        
    }else{
        self.passView = [[Passphase alloc] initWithNibName: @"Passphase_ip5" bundle: nil];
        self.contactView = [[ContactViewController alloc] initWithNibName:@"ContactViewController_ip5" bundle:nil];
        self.setupView = [[SetupPanelViewController alloc] initWithNibName:@"SetupPanelViewController_ip5" bundle:nil];
        self.exchangeView = [[ExchangeViewController alloc] initWithNibName: @"ExchangeViewController_ip5" bundle: nil];
    }
    
    self.msgList = [[MessageListViewController alloc]initWithNibName:@"GeneralTableView" bundle:nil];
    self.msgDetail = [[MessageEntryViewViewController alloc] initWithNibName:@"GeneralTableView" bundle:nil];
    
    self.systemView = [[SystemSetting alloc]initWithStyle:UITableViewStyleGrouped];
    self.mainView = [navController.viewControllers objectAtIndex: 0];
    self.mainView.delegate = [[UIApplication sharedApplication]delegate];
    
    // Local Notificaiton Registration for iCloud
    if (floor(NSFoundationVersionNumber) >= NSFoundationVersionNumber_iOS_6_0)
    {
        [[NSNotificationCenter defaultCenter]
         addObserver: self
         selector: @selector (iCloudAccountAvailabilityChanged:)
         name: NSUbiquityIdentityDidChangeNotification
         object: nil];
    }
    
    // Init Airship launch options
    // Set log level for debugging config loading (optional)
    // It will be set to the value in the loaded config upon takeOff
    [UAirship setLogLevel:UALogLevelTrace];
    
    // Populate AirshipConfig.plist with your app's info from https://go.urbanairship.com
    // or set runtime properties here.
    UAConfig *config = [UAConfig defaultConfig];
    
    // Call takeOff (which creates the UAirship singleton)
    [UAirship takeOff:config];
    [UAirship setLogLevel:UALogLevelError];
    [[UAPush shared]setAutobadgeEnabled:YES];
    [UAPush shared].notificationTypes = (UIRemoteNotificationTypeBadge |
                                         UIRemoteNotificationTypeSound |
                                         UIRemoteNotificationTypeAlert);
    
    [window makeKeyAndVisible];
    return YES;
}

#pragma mark Handle Push Notifications
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    // iOS6 and before
    if(application.applicationState==UIApplicationStateActive)
    {
        // foreground
        NSString* nonce = [[[userInfo objectForKey:@"aps"]objectForKey:@"nonce"]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // Grep a specific message
        [self.msgList FetchSingleMessage:nonce];
    }else{
        // inactive or background, switch from other apps or become active
        [self.msgList FetchMessageNonces];
    }
}

/*
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    // iOS7 and up
    if(application.applicationState==UIApplicationStateActive)
    {
        // foreground
        NSString* nonce = [[[userInfo objectForKey:@"aps"]objectForKey:@"nonce"]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // Grep a specific message
        [self.msgList FetchSingleMessage:nonce];
    }else{
        // inactive or background, switch from other apps or become active
        [self.msgList FetchMessageNonces];
    }
    
    completionHandler(UIBackgroundFetchResultNoData);
}
*/


- (void)Login
{
    if(!self.hasAccess)
    {
        self.passView.view.autoresizesSubviews = NO;
        [self.passView InitializePanel];
        [self.passView.view setFrame:[[UIScreen mainScreen]bounds]];
        [window addSubview: self.passView.view];
        [window DisableTimer];
    }else{
        // still valid
        [mainView checkSystemStatus];
    }
    [window makeKeyAndVisible];
    
    //iCloud backup timer, 1 hour
    if([icloud_timer isValid])
    {
        [icloud_timer invalidate];
        icloud_timer = nil;
    }
    icloud_timer = [NSTimer scheduledTimerWithTimeInterval:BACKUP_PERIOD
                                             target:self
                                           selector:@selector(BackUpByTimer:)
                                           userInfo:nil
                                            repeats:YES];
}

-(void)Logout
{
    DEBUGMSG(@"Logout!");
    if(self.hasAccess)
    {
        self.hasAccess = NO;
        NSData* status = [DbInstance GetConfig:@"PRIKEY_STATUS"];
        NSString* status_str = [NSString stringWithCString:[status bytes] encoding:NSUTF8StringEncoding];
        DEBUGMSG(@"status = %@", status_str);
        if([status_str isEqualToString:@"DEC"])
        {
            DEBUGMSG(@"old verison of code...");
            // for old devices
            status_str = @"ENC";
            [DbInstance InsertOrUpdateConfig:[status_str dataUsingEncoding:NSUTF8StringEncoding] withTag:@"PRIKEY_STATUS"];
            DEBUGMSG(@"tempralPINCode = %@", tempralPINCode);
            [self.passView EncryptPrivateKeys:tempralPINCode];
        }
        // erase the cache password
        tempralPINCode = nil;
        [self Login];
    }
}

-(void)BackUpByTimer:(NSTimer*)theTimer
{
    [backtool RecheckCapability];
    [backtool PerformBackup];
}

-(void) GainAccess
{
    // start backup if necessary
    self.hasAccess = YES;
    [passView.view removeFromSuperview];
    
    // enable timers
    int limit = 0;
    [[DbInstance GetConfig:@"label_passPhraseCacheTtl"]getBytes:&limit length:sizeof(limit)];
    [window ResetTimer:(NSTimeInterval)limit];
    
    [window setRootViewController: self.navController];
    [window makeKeyAndVisible];
}

- (BOOL) application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    return YES;
}

-(BOOL) application: (UIApplication *)application handleOpenURL: (NSURL *)url
{
    return [self application:application openURL:url sourceApplication:nil annotation:nil];
}

- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    return UIInterfaceOrientationMaskPortrait;
}

-(void) saveConactData
{
	if(self.myID == -1) return;
	char buf[12];
	*(int *)(buf + 8) = self.myID;
	NSData *data = [[NSData alloc] initWithBytes: buf length: 12];
	[data writeToFile: [NSString stringWithFormat: @"%@/contact", documentsPath] atomically: YES];
	[data release];
}

-(void)iCloudAccountAvailabilityChanged: (id)app
{
    [backtool RecheckCapability];
}

-(BOOL)CheckIdentity
{
    // contact check
	NSString *contactsFile = [NSString stringWithFormat: @"%@/contact", documentsPath];
	if ([[NSFileManager defaultManager] fileExistsAtPath: contactsFile])
	{
		NSData *data = [[NSFileManager defaultManager] contentsAtPath: contactsFile];
		const char *bytes = [data bytes];
		bytes += 8;
		myID = *(int *)bytes;
        
        // get self photo first, cached.
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if (!granted) {
                [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            }
        });
        ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, myID);
        // set self photo
        CFDataRef imgData = ABPersonCopyImageData(aRecord);
        if(imgData)
        {
            SelfPhotoCache = [UIImageJPEGRepresentation([[UIImage imageWithData:(NSData *)imgData]scaleToSize:CGSizeMake(45.0f, 45.0f)], 0.9)retain];
            CFRelease(imgData);
        }
        myName = (NSString*)ABRecordCopyCompositeName(aRecord);
        if(aBook)CFRelease(aBook);
        return YES;
	}
	else
    {
        myID = -1;
        return NO;
    }
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Record TimeStamp
    NSTimeInterval stamp = [[NSDate date]timeIntervalSince1970];
    [DbInstance InsertOrUpdateConfig: [NSData dataWithBytes: &stamp length: sizeof(stamp)] withTag:@"time_track"];
}

- (void)backgroundHandler
{
    DEBUGMSG(@"### -->backgroundHandler callback for backup.");
    [backtool RecheckCapability];
    [backtool PerformBackup];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // popup all pushed container
    DEBUGMSG(@"applicationDidEnterBackground");
    // Record TimeStamp
    NSTimeInterval stamp = [[NSDate date]timeIntervalSince1970];
    [DbInstance InsertOrUpdateConfig: [NSData dataWithBytes: &stamp length: sizeof(stamp)] withTag:@"time_track"];
    
    if(hasContactPrivacy&&(myID!=-1))
    {
        NSAssert(self->bgTask == UIBackgroundTaskInvalid, nil);
    
        bgTask = [application beginBackgroundTaskWithExpirationHandler: ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [application endBackgroundTask:self->bgTask];
                self->bgTask = UIBackgroundTaskInvalid;
            });
        }];
    
        dispatch_async(dispatch_get_main_queue(), ^{
            [self backgroundHandler];
            [application endBackgroundTask:self->bgTask];
            self->bgTask = UIBackgroundTaskInvalid;
        });
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
    DEBUGMSG(@"applicationWillEnterForeground");
	[activityView.indicator stopAnimating];
	[activityView.indicator startAnimating];
}


- (void)applicationDidBecomeActive:(UIApplication *)application 
{
    DEBUGMSG(@"applicationDidBecomeActive");
    DEBUGMSG(@"BadgeNumber = %d", [UIApplication sharedApplication].applicationIconBadgeNumber);
    
    if(![self CheckIdentity])
    {
        // New Setup
        [self ResetIdentity];
    }else{
        // check record is exiting or not
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = NULL;
        aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if (!granted) {
                [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
                return;
            }
        });
        
        ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, myID);
        if(aRecord==nil)
        {
            // contact is missing, or probably access control is disabled.
            myID = -1;
            hasAccess = NO;
            [self saveConactData];
            [self ResetIdentity];
        }else{
            // check time track
            NSTimeInterval last_seen = 0.0f;
            [[DbInstance GetConfig:@"time_track"]getBytes:&last_seen length:sizeof(last_seen)];
            NSTimeInterval period = [[NSDate date]timeIntervalSince1970] - last_seen;
            int limit = 0;
            [[DbInstance GetConfig:@"label_passPhraseCacheTtl"]getBytes:&limit length:sizeof(limit)];
            
            DEBUGMSG(@"period = %f, limit = %d", period, limit);
            if((limit>0)&&hasAccess) hasAccess = (period>=limit) ? NO : YES;
            [self Login];
            
            if ([UIApplication sharedApplication].applicationIconBadgeNumber>0) {
                [self.msgList FetchMessageNonces];
            }
        }
        if(aBook)CFRelease(aBook);
    }
}

- (void)ResetIdentity
{
    firstSetup = YES;
    [window setRootViewController:self.navController];
    if(![[self.navController topViewController]isEqual:setupView])
    {
        [self.navController pushViewController:setupView animated:YES];
    }
    [window makeKeyAndVisible];
    setupView.recoverytry = 0;
    [setupView GrebCopyFromCloud];
}

- (void)applicationWillTerminate:(UIApplication *)application
{    
    DEBUGMSG(@"applicationWillTerminate");
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
    self.hasAccess = NO;
	[self saveConactData];
}


- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    UALOG(@"APN device token: %@", deviceToken);
    // Updates the device token and registers the token with UA
    [[UAPush shared] registerDeviceToken:deviceToken];
    // Sets the alias. It will be sent to the server on registration.
    [UAPush shared].alias = [UIDevice currentDevice].name;
    // Add AppVer tag
    [[UAPush shared]addTagToCurrentDevice:[NSString stringWithFormat:@"AppVer = %@", [self getVersionNumber]]];
    [[UAPush shared]updateRegistration];
    
    
    //Do something when notifications are disabled altogther
    if ([app enabledRemoteNotificationTypes] == UIRemoteNotificationTypeNone) {
        UALOG(@"iOS Registered a device token, but nothing is enabled!");
        
        //only alert if this is the first registration, or if push has just been
        //re-enabled
        if ([UAirship shared].deviceToken != nil) { //already been set this session
            
            [ErrorLogger ERRORDEBUG: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")];
            [[[[iToast makeText: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
        //Do something when some notification types are disabled
    } else if ([app enabledRemoteNotificationTypes] != [UAPush shared].notificationTypes) {
        
        UALOG(@"Failed to register a device token with the requested services. Your notifications may be turned off.");
        //only alert if this is the first registration, or if push has just been
        //re-enabled
        if ([UAirship shared].deviceToken != nil) { //already been set this session
            UIRemoteNotificationType disabledTypes = [app enabledRemoteNotificationTypes] ^ [UAPush shared].notificationTypes;
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"NOTIFICATION ERROR TYPE: %d", disabledTypes]];
            [[[[iToast makeText: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
    }
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
    UALOG(@"Failed To Register For Remote Notifications With Error: %@", err);
}


#pragma mark -
#pragma mark Memory management
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[[[iToast makeText: NSLocalizedString(@"error_OutOfMemoryError", @"Memory is too low to complete this operation.")]
       setGravity:iToastGravityCenter] setDuration:iToastDurationLong] show];
}

- (void)dealloc {
    
    // relase all view objects
    [mainView release];
	[contactView release];
	[exchangeView release];
	[activityView release];
    [passView release];
    [msgList release];
	[documentsPath release];
	[navController release];
    [window release];
    [setupView release];
    [backtool release];
    [msgDetail release];
    [systemView release];
    [vCardString release];
    [DbInstance SaveDBToStorage];
    [DbInstance release];
    DbInstance = nil;
    [icloud_timer release];
    icloud_timer = nil;
    if(SelfPhotoCache)[SelfPhotoCache release];
    [super dealloc];
}

@end
