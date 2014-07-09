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

#import <CommonCrypto/CommonDigest.h>
#import <safeslingerexchange/iToast.h>
#import "Passphase.h"
#import "AppDelegate.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "Utility.h"
#import "SetupView.h"
#import "KeySelectionView.h"

@interface Passphase ()

@end

@implementation Passphase

@synthesize VersionLabel, PassField, NewKeyBtn, error_t;
@synthesize delegate, DoneBtn, KeySelectBtn, errTimer, tout_bound, Scrollview;

-(BOOL) CheckPassphase: (NSString*) passphrase
{
    NSString* status_str = [delegate.DbInstance GetStringConfig:@"PRIKEY_STATUS"];
    DEBUGMSG(@"status_str = %@", status_str);
    if([status_str isEqualToString:@"ENC"])
    {
        // unlock
        int PRIKEY_STORE_SIZE = 0;
        [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
        int PRIKEY_STORE_FORSIGN_SIZE = 0;
        [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_FORSIGN_SIZE"] getBytes:&PRIKEY_STORE_FORSIGN_SIZE length:sizeof(PRIKEY_STORE_FORSIGN_SIZE)];
        if([SSEngine TestPassPhase:passphrase KeySize1:PRIKEY_STORE_SIZE KeySize2:PRIKEY_STORE_FORSIGN_SIZE])
        {
            delegate.tempralPINCode = passphrase;
            return YES;
        }else{
            return NO;
        }
    }
    else
        return NO;
}

- (IBAction)CreateNewKey:(id)sender
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_passphrase", @"Passphrase")
                                                      message:NSLocalizedString(@"label_WarnForgotPassphrase", @"To protect your data, SafeSlinger does not store your passphrase anywhere for recovery. You may only access recipients and messages created under the same passphrase login. However, you may generate a new key and passphrase, then repeat Sling Keys with your recipients.")
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                            otherButtonTitles:NSLocalizedString(@"btn_CreateNewKey", @"Create New Key"), nil];
    
    [message show];
    message = nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex)
    {
        // Create New Key
        [self performSegueWithIdentifier:@"CreateNewKey" sender:self];
    }
}

- (void) StartRetryTimer
{
    DEBUGMSG(@"tout_bound = %d", tout_bound);
    tout_bound++;
    if(tout_bound>=PENALTY_TIME)
    {
        [self StopRetryTimer];
    }else{
        [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(UpdateRetryTimer) userInfo:nil repeats:NO];
    }
}

- (void) UpdateRetryTimer
{
    DEBUGMSG(@"UpdateRetryTimer");
    PassField.placeholder = [NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"label_PassHintBackoff", @"Retry"), [NSString stringWithFormat: NSLocalizedString(@"label_seconds", @"%d sec"), PENALTY_TIME-tout_bound]];
    [self StartRetryTimer];
}

-(void) StopRetryTimer
{
    DEBUGMSG(@"StopRetryTimer");
    DoneBtn.enabled = YES;
    PassField.enabled = YES;
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintEnter", @"Passphrase")];
    tout_bound = error_t = 0;
}

-(IBAction)Login:(id)sender
{
    if([self CheckPassphase: PassField.text])
    {
        error_t = 0;
        // [delegate GainAccess];
        [self performSegueWithIdentifier: @"SwitchToMain" sender:self];
        
    } else {
        [[[[iToast makeText: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        PassField.text = nil;
        error_t++;
    }
    
    if(error_t>=MAX_PINCODE_RETRY)
    {
        DEBUGMSG(@"error_t = %d", error_t);
        PassField.text = @"";
        PassField.enabled = NO;
        DoneBtn.enabled = NO;
        [self StartRetryTimer];
    }
}

-(IBAction)PressHelp:(id)sender
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: nil
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_Help", @"Help"),
                                  NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"),
                                  NSLocalizedString(@"menu_License", @"License"),
                                  NSLocalizedString(@"text_KeywordPrivacy", @"Privacy"),
                                  nil];
    
    [actionSheet showInView: self.view];
    actionSheet = nil;
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case Help:
        {
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_passphrase", @"Passphrase")
                                                              message:NSLocalizedString(@"help_passphrase", @"Use this screen to login to the application with your passphrase. If you have forgotten your passphrase, you may generate a new key protected by a new passphrase by tapping the Forgot Passphrase? button. Tap the user name to switch between multiple keys.")
                                                             delegate:nil
                                                    cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                    otherButtonTitles:nil];
            
            [message show];
            message = nil;
        }
            break;
        case Feedback:
            [self SendOpts];
            break;
        case LicenseLink:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString: kLicenseURL]];
            break;
        case PrivacyLink:
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString: kPrivacyURL]];
            break;
        default:
            break;
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Set delegate and get version number
    delegate = [[UIApplication sharedApplication] delegate];
    VersionLabel.text = [delegate getVersionNumber];
    [DoneBtn setTitle:NSLocalizedString(@"btn_OK", @"OK") forState: UIControlStateNormal];
    [NewKeyBtn setTitle: NSLocalizedString(@"menu_ForgotPassphrase", @"Forgot Passphrase?")];
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintEnter", @"Passphrase")];
    
    error_t = 0;
    tout_bound = 0;
    _originalFrame = self.view.frame;
    self.navigationItem.hidesBackButton = YES;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    PassField.text = nil;
    [KeySelectBtn setTitle:delegate.IdentityName forState:UIControlStateNormal];
    DEBUGMSG(@"key index = %d", [[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY]);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShown:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [PassField resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)keyboardWillShown:(NSNotification *)notification
{
    // make it scrollable
    Scrollview.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height*1.3);
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    Scrollview.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma UITextFieldDelegate Methods
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

- (IBAction)unwindToLogin:(UIStoryboardSegue *)unwindSegue
{
    if([[unwindSegue identifier]isEqualToString:@"KeySelectionDone"])
    {
        KeySelectionView *view = (KeySelectionView*)[unwindSegue sourceViewController];
        if(view.keyChanged)
        {
            DEBUGMSG(@"unwindToLogin: KeySelectionDone");
            [delegate.DbInstance CloseDB];
            [delegate.DbInstance LoadDBFromStorage:[[[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY] objectAtIndex:[[NSUserDefaults standardUserDefaults] integerForKey:kDEFAULT_DB_KEY]]];
            [delegate checkIdentity];
            [KeySelectBtn setTitle:delegate.IdentityName forState:UIControlStateNormal];
        }
    }
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if([[segue identifier]isEqualToString:@"CreateNewKey"])
    {
        SetupView *setup = (SetupView*)[segue destinationViewController];
        setup.newkeycreated = YES;
    }
}

@end
