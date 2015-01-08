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

#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "BackupCloud.h"
#import "ContactCellView.h"
#import "MessageReceiver.h"
#import "SSEngine.h"
#import "IdleHandler.h"
#import "UniversalDB.h"
#import "ErrorLogger.h"
#import "FunctionView.h"

#import <AddressBook/AddressBook.h>
#import <Crashlytics/Crashlytics.h>
#import <UAirship.h>
#import <UAAnalytics.h>
#import <UAConfig.h>

@implementation AppDelegate

@synthesize DbInstance, UDbInstance, tempralPINCode;
@synthesize IdentityName, IdentityNum, RootPath, IdentityImage;
@synthesize BackupSys, SelectContact, MessageInBox, bgTask;

- (NSString *)getVersionNumber {
#ifdef BETA
    return [NSString stringWithFormat:@"%@-beta", [[[NSBundle mainBundle] infoDictionary]objectForKey: @"CFBundleShortVersionString"]];
#else
    return [[[NSBundle mainBundle] infoDictionary]objectForKey: @"CFBundleVersion"];
#endif
}

- (int)getVersionNumberByInt {
    NSArray *versionArray = [[[[NSBundle mainBundle] infoDictionary]objectForKey: @"CFBundleVersion"] componentsSeparatedByString:@"."];
    
    int version = 0;
    for(int i=0;i<[versionArray count];i++) {
        NSString* tmp = [versionArray objectAtIndex:i];
        version = version | ([tmp intValue] << (8*(3-i)));
    }
    return version;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Preloads keyboard so there's no lag on initial keyboard appearance.
	UITextField *lagFreeField = [[UITextField alloc] init];
	[self.window addSubview:lagFreeField];
	[lagFreeField becomeFirstResponder];
	[lagFreeField resignFirstResponder];
	[lagFreeField removeFromSuperview];
	
	
    [Crashlytics startWithAPIKey:@"a9f2629c171299fa2ff44a07abafb7652f4e1d5c"];
    [[Crashlytics sharedInstance]setDebugMode:YES];
    
    // get root path
	NSArray *arr = [[NSArray alloc] initWithArray: NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)];
	RootPath = [arr objectAtIndex: 0];
    
    // Prepare Database Object
    DbInstance = [[SafeSlingerDB alloc]init];
    
    NSInteger DB_KEY_INDEX = [[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY];
    if(DB_KEY_INDEX > 0) {
        [DbInstance LoadDBFromStorage:[NSString stringWithFormat:@"%@-%ld", DATABASE_NAME, (long)DB_KEY_INDEX]];
    } else {
        [DbInstance LoadDBFromStorage:nil];
    }
    
    UDbInstance = [[UniversalDB alloc] init];
    [UDbInstance LoadDBFromStorage];
	
	[self updateDatabase];
    
    [[NSUserDefaults standardUserDefaults] setInteger:[self getVersionNumberByInt] forKey: kAPPVERSION];
    
    BOOL PushIsRegistered = NO;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        if ([[UIApplication sharedApplication] enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone)
            PushIsRegistered = YES;
    } else {
        PushIsRegistered = [[UIApplication sharedApplication]isRegisteredForRemoteNotifications];
    }
    
    if(PushIsRegistered) {
        [UAirship setLogLevel:UALogLevelTrace];
        UAConfig *config = [UAConfig defaultConfig];
        // Call takeOff (which creates the UAirship singleton)
        [UAirship takeOff: config];
        [UAirship setLogLevel:UALogLevelError];
        [[UAPush shared]setAutobadgeEnabled:YES];
        [UAPush shared].userNotificationTypes = (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert);
        [UAPush shared].userPushNotificationsEnabled = YES;
        [UAPush shared].registrationDelegate = self;
    }
    
    // message receiver
    MessageInBox = [[MessageReceiver alloc]init:DbInstance UniveralTable:UDbInstance Version:[self getVersionNumberByInt]];
    
    // backup system
    BackupSys = [[BackupCloudUtility alloc]init];
    
    return YES;
}

- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken {
    // DEBUGMSG(@"channelID = %@, deviceToken = %@", channelID, deviceToken);
}

- (void)registrationFailed {
    DEBUGMSG(@"registrationFailed");
}

- (void)registerPushToken {
    UAConfig *config = [UAConfig defaultConfig];
    // Call takeOff (which creates the UAirship singleton)
    [UAirship takeOff:config];
	
    [UAPush shared].userNotificationTypes = (UIUserNotificationTypeBadge |
											 UIUserNotificationTypeAlert |
											 UIUserNotificationTypeSound);
	UAirship.logLevel = UALogLevelError;
    [UAPush shared].autobadgeEnabled = YES;
    [UAPush shared].userPushNotificationsEnabled = YES;
    [UAPush shared].registrationDelegate = self;
}

- (void)removeContactLink {
    IdentityNum = NonLink;
    NSData *contact = [NSData dataWithBytes:&IdentityNum length:sizeof(IdentityNum)];
    [DbInstance InsertOrUpdateConfig:contact withTag:@"IdentityNum"];
}

- (void)saveConactDataWithoutChaningName:(int)ContactID {
    if(ContactID == NonExist) return;
    self.IdentityNum = ContactID;
    NSData *contact = [NSData dataWithBytes:&ContactID length:sizeof(ContactID)];
    [DbInstance InsertOrUpdateConfig:contact withTag:@"IdentityNum"];
    
    // Try to backup
    [BackupSys RecheckCapability];
    [BackupSys PerformBackup];
}

- (void)saveConactData:(int)ContactID Firstname:(NSString *)FN Lastname:(NSString *)LN {
	if(ContactID == NonExist) return;
 
    NSString* oldValue = [DbInstance GetProfileName];
    if(FN) {
        [DbInstance InsertOrUpdateConfig:[FN dataUsingEncoding:NSUTF8StringEncoding] withTag:@"Profile_FN"];
    } else {
        [DbInstance RemoveConfigTag:@"Profile_FN"];
    }
    
    if(LN) {
        [DbInstance InsertOrUpdateConfig:[LN dataUsingEncoding:NSUTF8StringEncoding] withTag:@"Profile_LN"];
    } else {
        [DbInstance RemoveConfigTag:@"Profile_LN"];
    }
    
    NSString* newValue = [DbInstance GetProfileName];
    if(![oldValue isEqualToString:newValue]) {
        //change information for kDB_LIST
        NSArray *infoarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_LIST];
        NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY];
        
        NSMutableArray *arr = [NSMutableArray arrayWithArray:infoarr];
        
        NSString *keyinfo = [NSString stringWithFormat:@"%@\n%@ %@", [NSString compositeName:FN withLastName:LN], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat: @"yyyy-MM-dd HH:mm:ss"]];
        
        [arr setObject:keyinfo atIndexedSubscript:index];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_LIST];
    }
    
    self.IdentityName = [NSString compositeName:FN withLastName:LN];
	[self saveConactDataWithoutChaningName:ContactID];
}

#pragma mark - Database updates

- (void)updateDatabase {
	int oldVersion = (1 << 24) | (7 << 16); // version 1.7
	if ([DbInstance GetProfileName] && [self getVersionNumberByInt] < oldVersion) {
		// version 1.6.x, apply 1.7 changes...
		[self ApplyChangeForV17];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey: kRequirePushNotification];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey: kRequireMicrophonePrivacy];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey: kRequirePushNotification];
	}
	
	int currentVersion = (int)[[NSUserDefaults standardUserDefaults] integerForKey:kAPPVERSION];
	oldVersion = (1 << 24) | (8 << 16) | 1; // version 1.8.0.1
	if (currentVersion != 0 && currentVersion <= oldVersion) {
		[DbInstance patchForContactsFromAddressBook];
	}
}

- (void)ApplyChangeForV17 {
    if([DbInstance PatchForTokenStoreTable])
        DEBUGMSG(@"Patch done...");
    
    // save contact index to database
    if([DbInstance GetProfileName] && ([DbInstance GetConfig:@"IdentityNum"]==nil)) {
        int contact_id = NonLink;
        NSString *contactsFile = [NSString stringWithFormat: @"%@/contact", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: contactsFile]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: contactsFile];
            const char *bytes = [data bytes];
            bytes += 8;
            contact_id = *(int *)bytes;
        }
        
        NSData *contact = [NSData dataWithBytes:&contact_id length:sizeof(contact_id)];
        [DbInstance InsertOrUpdateConfig:contact withTag:@"IdentityNum"];
    }
    
    // backup keys into database
    if(![DbInstance GetConfig:@"KEYID"]) {
        NSString *floc = [NSString stringWithFormat: @"%@/gendate.dat", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: floc]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: floc];
            [DbInstance InsertOrUpdateConfig:data withTag:@"KEYID"];
        }
    }
    
    if(![DbInstance GetConfig:@"KEYGENDATE"]) {
        NSString *floc = [NSString stringWithFormat: @"%@/gendate.txt", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: floc]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: floc];
            [DbInstance InsertOrUpdateConfig:data withTag:@"KEYGENDATE"];
        }
    }
    
    if(![DbInstance GetConfig:@"ENCPUB"]) {
        NSString *floc = [NSString stringWithFormat: @"%@/pubkey.pem", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: floc]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: floc];
            [DbInstance InsertOrUpdateConfig:data withTag:@"ENCPUB"];
        }
    }
    
    if(![DbInstance GetConfig:@"SIGNPUB"]) {
        NSString *floc = [NSString stringWithFormat: @"%@/spubkey.pem", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: floc]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: floc];
            [DbInstance InsertOrUpdateConfig:data withTag:@"SIGNPUB"];
        }
    }
    
    if(![DbInstance GetConfig:@"ENCPRI"]) {
        NSString *floc = [NSString stringWithFormat: @"%@/prikey.pem", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: floc]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: floc];
            [DbInstance InsertOrUpdateConfig:data withTag:@"ENCPRI"];
        }
    }
    
    if(![DbInstance GetConfig:@"SIGNPRI"]) {
        NSString *floc = [NSString stringWithFormat: @"%@/sprikey.pem", RootPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath: floc]) {
            NSData *data = [[NSFileManager defaultManager] contentsAtPath: floc];
            [DbInstance InsertOrUpdateConfig:data withTag:@"SIGNPRI"];
        }
    }
    
    // Register Default
    if([DbInstance GetProfileName] && ![[NSUserDefaults standardUserDefaults] stringArrayForKey:kDB_KEY]) {
        // Add default setting
        NSArray *arr = [NSArray arrayWithObjects: DATABASE_NAME, nil];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_KEY];
        NSString *keyinfo = [NSString stringWithFormat:@"%@\n%@ %@", [DbInstance GetProfileName], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat: @"yyyy-MM-dd HH:mm:ss"]];
        arr = [NSArray arrayWithObjects: keyinfo, nil];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_LIST];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey: kDEFAULT_DB_KEY];
    }
    
    DEBUGMSG(@"Error log: %@", [ErrorLogger GetLogs]);
}

- (BOOL)checkIdentity {
    BOOL ret = YES;
    
    // Identity checking, check if conact is linked
    NSData* contact_data = [DbInstance GetConfig:@"IdentityNum"];
    if(contact_data) {
        [contact_data getBytes:&IdentityNum];
    } else {
        IdentityNum = NonExist;
    }
    
    switch (IdentityNum) {
        case NonExist:
            ret = NO;
            break;
        case NonLink:
            IdentityName = [DbInstance GetProfileName];
            break;
        default:
            IdentityName = [DbInstance GetProfileName];
            if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
                // get self photo first, cached.
                CFErrorRef error = NULL;
                ABAddressBookRef aBook = ABAddressBookCreateWithOptions(NULL, &error);
                ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
                    if (!granted) {
                    }
                });
        
                ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, IdentityNum);
                // set self photo
                if(ABPersonHasImageData(aRecord)) {
                    CFDataRef imgData = ABPersonCopyImageDataWithFormat(aRecord, kABPersonImageFormatThumbnail);
                    IdentityImage = UIImageJPEGRepresentation([[UIImage imageWithData:(__bridge NSData *)imgData]scaleToSize:CGSizeMake(45.0f, 45.0f)], 0.9);
                    CFRelease(imgData);
                }
                if(aBook)CFRelease(aBook);
            } else {
                // contact privacy might be shut off
                IdentityNum = NonLink;
                [self saveConactDataWithoutChaningName:IdentityNum];
            }
            break;
    }
    
    DEBUGMSG(@"IdentityName = %@, IdentityNum = %d", IdentityName, IdentityNum);
    return ret;
}

#pragma mark Handle Push Notifications

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    if([self checkIdentity]) {
        if ([UIApplication sharedApplication].applicationIconBadgeNumber>0) {
            NSString* nonce = [[[userInfo objectForKey:@"aps"]objectForKey:@"nonce"]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [MessageInBox FetchSingleMessage:nonce];
        }
    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler {
    if([self checkIdentity]) {
        if ([UIApplication sharedApplication].applicationIconBadgeNumber>0) {
            NSString* nonce = [[[userInfo objectForKey:@"aps"]objectForKey:@"nonce"]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [MessageInBox FetchSingleMessage:nonce];
        }
    }
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UALOG(@"APN device token: %@", deviceToken);
    // Updates the device token and registers the token with UA
    [[UAPush shared] appRegisteredForRemoteNotificationsWithDeviceToken:deviceToken];
    // Sets the alias. It will be sent to the server on registration.
    [UAPush shared].alias = [UIDevice currentDevice].name;
    // Add AppVer tag
    [[UAPush shared]addTag:[NSString stringWithFormat:@"AppVer = %@", [self getVersionNumber]]];
    [[UAPush shared]updateRegistration];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        //Do something when notifications are disabled altogther
        if([app enabledRemoteNotificationTypes] != (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
            UALOG(@"iOS Registered a device token, but nothing is enabled!");
            //only alert if this is the first registration, or if push has just been
            //re-enabled
            if ([UAirship shared].deviceToken != nil) { //already been set this session
                [ErrorLogger ERRORDEBUG: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")];
            }
            //Do something when some notification types are disabled
        }
    } else {
        //Do something when notifications are disabled altogther
        if (![[UIApplication sharedApplication] isRegisteredForRemoteNotifications] || [UIApplication sharedApplication].currentUserNotificationSettings.types != (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
            UALOG(@"iOS Registered a device token, but nothing is enabled!");
            //only alert if this is the first registration, or if push has just been
            //re-enabled
            if ([UAirship shared].deviceToken != nil) { //already been set this session
                [ErrorLogger ERRORDEBUG: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")];
            }
            //Do something when some notification types are disabled
        }
    }
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Failed To Register For Remote Notifications With Error: %@", err]];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    DEBUGMSG(@"BadgeNumber = %ld", (long)[UIApplication sharedApplication].applicationIconBadgeNumber);
    
    if([self checkIdentity]) {
        // update push notification status
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidTimeout:) name:KSDIdlingWindowTimeoutNotification object:nil];
        
        if ([UIApplication sharedApplication].applicationIconBadgeNumber>0) {
            DEBUGMSG(@"Fetch %ld messages...", (long)[UIApplication sharedApplication].applicationIconBadgeNumber);
            [MessageInBox FetchMessageNonces: (int)[UIApplication sharedApplication].applicationIconBadgeNumber];
        }
        
        // Try to backup
        [BackupSys RecheckCapability];
        [BackupSys PerformBackup];
        
        // update push notificaiton registration
        DEBUGMSG(@"updateRegistration..");
        [[UAPush shared]updateRegistration];
        
        DEBUGMSG(@"token = %@", [UAPush shared].deviceToken);
        DEBUGMSG(@"currentEnabledNotificationTypes = %lu", [UAPush shared].currentEnabledNotificationTypes);
    }
}

-(void)applicationDidTimeout: (NSNotification *)notification {
    if([self.window.rootViewController isMemberOfClass:[UINavigationController class]]) {
        UINavigationController* nag = (UINavigationController*)self.window.rootViewController;
        if([nag.visibleViewController isMemberOfClass:[FunctionView class]]) {
            // FunctionView* view = (FunctionView*)nag.visibleViewController;
            [nag popViewControllerAnimated:YES];
        }
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [DbInstance CloseDB];
    DbInstance = nil;
    [UDbInstance CloseDB];
    UDbInstance = nil;
}

@end
