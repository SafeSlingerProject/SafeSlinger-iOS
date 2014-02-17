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

#import "MainPanel.h"
#import "MessageComposer.h"
#import "KeySlingerAppDelegate.h"
#import "VersionCheckMarco.h"
#import "Utility.h"

#import "UAirship.h"
#import "UAPush.h"
#import "UAAnalytics.h"
#import "UAConfig.h"

#import "ErrorLogger.h"

@interface MainPanel ()

@end

@implementation MainPanel

@synthesize delegate;
@synthesize composeLabel, msglistLabel, secintroLabel, slingkeyLabel;

-(IBAction) composeMessage
{
    // compose a new message
    MessageComposer *composer = nil;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if(IS_4InchScreen)
            composer = [[MessageComposer alloc] initWithNibName:@"MessageComposer_4in" bundle:nil];
        else
            composer = [[MessageComposer alloc] initWithNibName:@"MessageComposer" bundle:nil];
    }
    else
    {
        composer = [[MessageComposer alloc] initWithNibName:@"MessageComposer_ip5" bundle:nil];
    }
    [delegate.navController pushViewController:composer animated:YES];
    [composer release];
    composer = nil;
}

-(IBAction) viewMessages
{
    // message list
    [delegate.navController pushViewController: delegate.msgList animated: YES];
}

-(IBAction) performIntroduction
{
    SecureIntroduce *introducer = nil;
    // UI initializations
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if(IS_4InchScreen)
        {
            introducer = [[SecureIntroduce alloc] initWithNibName:@"SecureIntroduce_4in" bundle:nil];
        }else{
            introducer = [[SecureIntroduce alloc] initWithNibName:@"SecureIntroduce" bundle:nil];
        }
    }else{
        introducer = [[SecureIntroduce alloc] initWithNibName:@"SecureIntroduce_ip5" bundle:nil];
    }
    [delegate.navController pushViewController:introducer animated:YES];
    [introducer release];
    introducer = nil;
}

-(IBAction) slingKey
{
    // sling keys
    [delegate.navController pushViewController: delegate.contactView animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    int v = 0;
    [[delegate.DbInstance GetConfig:@"label_ShowHintAtLaunch"]getBytes:&v length:sizeof(v)];
    delegate.contactView.isShowAssist = ((v == 1) ? YES: NO);
    // disable progress window if it exists
    [delegate.activityView DisableProgress];
    
    // more button
    UIButton *infoButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0, 30.0f)];
    [infoButton setImage:[UIImage imageNamed:@"gear.png"] forState:UIControlStateNormal];
    [infoButton addTarget:self action:@selector(DisplayMore) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *setupbtn = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:setupbtn];
    [infoButton release];
    [setupbtn release];
    [self.navigationItem setLeftBarButtonItem:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    self.navigationItem.title = NSLocalizedString(@"title_HomePanel", @"Home");
    [self.navigationItem setHidesBackButton:YES];
    [composeLabel setText: NSLocalizedString(@"menu_TagComposeMessage", @"Compose")];
    [msglistLabel setText: NSLocalizedString(@"menu_TagListMessages", @"Messages")];
    [slingkeyLabel setText: NSLocalizedString(@"menu_TagExchange", @"Sling Keys")];
    [secintroLabel setText: NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction")];
}

- (void)checkNetwork
{
    internetReach = [[Reachability reachabilityForInternetConnection] retain];
	[internetReach startNotifier];
	[self updateInterfaceWithReachability: internetReach];
}

- (void) checkNotification
{
    UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
    if (types != [UAPush shared].notificationTypes )
    {
        // display waring message
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_Error", @"Error")
                                                          message:NSLocalizedString(@"iOS_notificationError1", @"Unable to turn on notifications. Use the 'Settings' app to enable notifications.")
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"btn_Exit", @"Exit")
                                                otherButtonTitles:NSLocalizedString(@"menu_Help", @"Help"), nil];
        message.tag = 0;
        [message show];
        [message release];
        message = nil;
    }
}

- (void) checkOldOS
{
    // notifiy user to upgrade the OS
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"5.1.1")) {
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_Warn", @"Warn")
                                                          message:NSLocalizedString(@"iOS_oldOSWarn", @"SafeSlinger is not optimized for iOS 5.x devices. iOS 6 is required for better performance.")
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"btn_OK", @"OK")
                                                otherButtonTitles:nil];
        message.tag = 3;
        [message show];
        [message release];
        message = nil;
    }
}

- (void) checkBackupCapability
{
    [delegate.backtool RecheckCapability];
    int v = 0;
    [[delegate.DbInstance GetConfig:@"label_RemindBackupDelay"]getBytes:&v length:sizeof(v)];
    BOOL show_remind = ((v == 1) ? YES: NO);
    
    if((!delegate.backtool.CloudEnabled)&&show_remind)
    {
        // notifiy user to enable it
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                          message:NSLocalizedString(@"ask_BackupDisabledRemindLater", @"Backup is disabled. Do you want to adjust backup settings and keep this reminder?")
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"btn_Remind", @"Remind")
                                                otherButtonTitles:NSLocalizedString(@"btn_NotRemind", @"Forget"), nil];
        message.tag = 2;
        [message show];
        [message release];
        message = nil;
    }
}

- (BOOL) checkContactPermission
{
    if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
    {
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if(status==kABAuthorizationStatusAuthorized)
        {
            delegate.hasContactPrivacy = YES;
        }else{
            delegate.hasContactPrivacy = NO;
            [ErrorLogger ERRORDEBUG: @"ERROR: kABAuthorization Status Denied."];
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_Error", @"Error")
                                                          message:NSLocalizedString(@"iOS_contactError", @"Contacts permission required. Please go to iOS Settings to enable Contacts permissions.")
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"btn_Exit", @"Exit")
                                                otherButtonTitles:NSLocalizedString(@"menu_Help", @"Help"), nil];
            message.tag = 1;
            [message show];
            [message release];
            message = nil;
        }
    }else {
        // 5.x
        delegate.hasContactPrivacy = YES;
    }
    return delegate.hasContactPrivacy;
}

- (void)checkSystemStatus
{
    // check all status and priviledge uses
    // 1: check Reachability
    [self checkNetwork];
    
    // 2. push notificaiton is no
    [self checkNotification];
    
    // 3. check Contact book priviledge
    [self checkContactPermission];
    
    // 4. check iCloud backup capability
    [self checkBackupCapability];
    
    // 5. check if user's OS is iOS5
    [self checkOldOS];
}

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString* helper = nil;
    switch (alertView.tag) {
        case 0:
            if(buttonIndex!=alertView.cancelButtonIndex)
            {
                helper = @"http://www.cylab.cmu.edu/safeslinger/help/h1.html";
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:helper]];
            }
            exit(0);
            break;
        case 1:
            if(buttonIndex!=alertView.cancelButtonIndex)
            {
                helper = @"http://www.cylab.cmu.edu/safeslinger/help/h2.html";
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:helper]];
            }
            exit(0);
            break;
        case 2:
            if(buttonIndex!=alertView.cancelButtonIndex)
            {
                // change system setting
                DEBUGMSG(@"Change BackUP Setting..");
                int booltmp = 0;
                [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &booltmp length: sizeof(booltmp)] withTag:@"label_RemindBackupDelay"];
            }
            //DisplayWarn=NO;
            break;
        default:
            break;
    }
}

- (void) updateInterfaceWithReachability: (Reachability*) curReach
{
	if(curReach == internetReach)
	{
		NetworkStatus netStatus = [curReach currentReachabilityStatus];
        switch (netStatus)
        {
            case NotReachable:
            {
                [[[[iToast makeText: NSLocalizedString(@"error_CorrectYourInternetConnection", @"Internet not available, check your settings.")]
                   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                break;
            }
            case ReachableViaWWAN:
            {
                break;
            }
            case ReachableViaWiFi:
            {
                break;
            }
        }
	}
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // select self
    if(buttonIndex!=actionSheet.cancelButtonIndex)
    {
        switch(buttonIndex)
        {
            case 0:
                // comments
                [self SendOpts];
                break;
            case 1:
                // Logout
                [delegate Logout];
                break;
            case 2:
                // Settings
                [delegate.navController pushViewController: delegate.systemView animated: YES];
                break;
            default:
                break;
        }
            
    }
}


- (void)SendOpts
{
    // Email Subject
    NSString *emailTitle = [NSString stringWithFormat:@"%@(iOS%@)",
                       NSLocalizedString(@"title_comments", @"Questions/Comments"),
                       [delegate getVersionNumber]];
    NSArray *toRecipents = [NSArray arrayWithObject:@"safeslingerapp@gmail.com"];
    
    if([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        [mc setTitle:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback")];
        mc.mailComposeDelegate = self;
        [mc setSubject:emailTitle];
        [mc setToRecipients:toRecipents];
        
        NSMutableString *debug = [NSMutableString string];
        
        NSString *detail = [ErrorLogger GetLogs];
        if(detail)
        {
            // add attachment for debug
            [debug appendFormat: @"iOS Model: %@\n", [UIDevice currentDevice].model];
            [debug appendFormat: @"SafeSlinger Version: %@\n", [delegate getVersionNumber]];
            [debug appendFormat: @"iOS OS: %@ %@\n", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
            [debug appendFormat: @"localizedModel: %@\n", [UIDevice currentDevice].localizedModel];
            [debug appendString: detail];
            [mc addAttachmentData:[debug dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/txt" fileName:@"feedback.txt"];
            [ErrorLogger CleanLogFile];
        }
        // Present mail view controller on screen
        [self presentViewController:mc animated:YES completion:NULL];
    }else{
        // display error..
        [[[[iToast makeText: NSLocalizedString(@"error_NoEmailAccount", @"Email account is not setup!")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
}

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
        case MFMailComposeResultSaved:
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Mail sent failure, %@", [error localizedDescription]]];
            // toast message
            [[[[iToast makeText: NSLocalizedString(@"error_CorrectYourInternetConnection", @"Internet not available, check your settings.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            break;
        default:
            break;
    }
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)dealloc
{
    [composeLabel release];
    [secintroLabel release];
    [msglistLabel release];
    [slingkeyLabel release];
    [internetReach release];
    internetReach = nil;
    [super dealloc];
}

- (void)DisplayMore
{
    // More System Setting
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: @""
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"),
                                  NSLocalizedString(@"menu_Logout", @"Logout"),
                                  NSLocalizedString(@"menu_Settings", @"Settings"),
                                  nil];
    [actionSheet showInView: [self.navigationController view]];
    [actionSheet release];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
