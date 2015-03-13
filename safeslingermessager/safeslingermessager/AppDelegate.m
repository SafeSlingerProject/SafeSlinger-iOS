/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2010-2015 Carnegie Mellon University
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
#import "SSEngine.h"
#import "IdleHandler.h"
#import "UniversalDB.h"
#import "ErrorLogger.h"
#import "FunctionView.h"
#import "MessageSender.h"
#import "MessageReceiver.h"

#import <AddressBook/AddressBook.h>
#import <Crashlytics/Crashlytics.h>

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
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
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
	
	int versionNumber = [self getVersionNumberByInt];
    [[NSUserDefaults standardUserDefaults] setInteger:versionNumber forKey: kAPPVERSION];
    
    // message receiver
    MessageInBox = [[MessageReceiver alloc]init:DbInstance UniveralTable:UDbInstance Version:versionNumber];
	// message sender
	_messageSender = [MessageSender new];
	
    // backup system
    BackupSys = [[BackupCloudUtility alloc]init];
    
    return YES;
}

- (void)registerPushToken
{
    // database entry does not exist, try to do registraiton again..
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        [[UIApplication sharedApplication]registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound)];
    } else {
        // iOS8
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:(UIRemoteNotificationTypeBadge|UIRemoteNotificationTypeAlert|UIRemoteNotificationTypeSound) categories:nil];
        [[UIApplication sharedApplication]registerUserNotificationSettings: settings];
        [[UIApplication sharedApplication]registerForRemoteNotifications];
    }
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
    DEBUGMSG(@"call didReceiveRemoteNotification...");
    DEBUGMSG(@"userInfo = %@", userInfo);
    NSString* badge = [[userInfo objectForKey:@"aps"]objectForKey:@"badge"];
    DEBUGMSG(@"received badge = %@", badge);
    
    if(badge && [self checkIdentity]) {
        DEBUGMSG(@"fetch %d messages...", [badge intValue]);
        [MessageInBox FetchMessageNonces: [badge intValue]];
    }
}

// for background
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    DEBUGMSG(@"call didReceiveRemoteNotification...");
    DEBUGMSG(@"userInfo = %@", userInfo);
    NSString* badge = [[userInfo objectForKey:@"aps"]objectForKey:@"badge"];
    DEBUGMSG(@"received badge = %@", badge);
    
    if(badge && [self checkIdentity]) {
        DEBUGMSG(@"fetch %d messages...", [badge intValue]);
        [MessageInBox FetchMessageNonces: [badge intValue]];
        completionHandler(UIBackgroundFetchResultNewData);
    } else {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    DEBUGMSG(@"didRegisterUserNotificationSettings");
}

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    DEBUGMSG(@"didRegisterForRemoteNotificationsWithDeviceToken");
    
    // TODO: will replace device token resgitration by our own
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        int flag = [app enabledRemoteNotificationTypes] & (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert);
        if(flag == (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
            //re-enabled
            NSString *hex_device_token = [[[deviceToken description]
                                           stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]]
                                          stringByReplacingOccurrencesOfString:@" "
                                          withString:@""];
            DEBUGMSG(@"APNS registered token = %@", hex_device_token);
            if(hex_device_token) [[NSUserDefaults standardUserDefaults] setObject:hex_device_token forKey:kPUSH_TOKEN];
        } else {
            //Do something when some notification types are disabled
            [ErrorLogger ERRORDEBUG: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPUSH_TOKEN];
        }
    } else {
        //Do something when notifications are disabled altogther
        int flag = [UIApplication sharedApplication].currentUserNotificationSettings.types & (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert);
        
        if ([[UIApplication sharedApplication] isRegisteredForRemoteNotifications] && flag == (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert)) {
            //re-enabled
            NSString *hex_device_token = [[[deviceToken description]
                                           stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]]
                                          stringByReplacingOccurrencesOfString:@" "
                                          withString:@""];
            DEBUGMSG(@"APNS registered token = %@", hex_device_token);
            if(hex_device_token) [[NSUserDefaults standardUserDefaults] setObject:hex_device_token forKey:kPUSH_TOKEN];
        } else {
            //Do something when some notification types are disabled
            [ErrorLogger ERRORDEBUG: NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the \"Settings\" app to enable notifications.")];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPUSH_TOKEN];
        }
    }
    
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    DEBUGMSG(@"didFailToRegisterForRemoteNotificationsWithError: %@", [err debugDescription]);
    [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Failed To Register For Remote Notifications With Error: %@", err]];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if([self checkIdentity]) {
        // update push notification status
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidTimeout:) name:KSDIdlingWindowTimeoutNotification object:nil];
        
        DEBUGMSG(@"check to see if MessageInBox is budy..");
        long badge = [UIApplication sharedApplication].applicationIconBadgeNumber;
        
        if(![MessageInBox IsBusy] && badge > 0) {
            [MessageInBox FetchMessageNonces:(int)badge];
        } else {
            DEBUGMSG(@"thread is busy or badge is zero.");
        }
        
        // Try to backup
        [BackupSys RecheckCapability];
        [BackupSys PerformBackup];
        
        // update push notificaiton registration if necessary
        [self registerPushToken];
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
