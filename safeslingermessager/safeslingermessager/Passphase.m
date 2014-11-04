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

- (BOOL)CheckPassphase:(NSString *)passphrase {
    NSString* status_str = [delegate.DbInstance GetStringConfig:@"PRIKEY_STATUS"];
	
    if([status_str isEqualToString:@"ENC"]) {
        // unlock
        int PRIKEY_STORE_SIZE = 0;
        [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
        int PRIKEY_STORE_FORSIGN_SIZE = 0;
        [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_FORSIGN_SIZE"] getBytes:&PRIKEY_STORE_FORSIGN_SIZE length:sizeof(PRIKEY_STORE_FORSIGN_SIZE)];
		
        if([SSEngine TestPassPhase:passphrase KeySize1:PRIKEY_STORE_SIZE KeySize2:PRIKEY_STORE_FORSIGN_SIZE]) {
            delegate.tempralPINCode = passphrase;
            return YES;
        } else {
            return NO;
        }
	} else {
        return NO;
	}
}

- (IBAction)CreateNewKey:(id)sender {
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_passphrase", @"Passphrase")
                                                      message:NSLocalizedString(@"label_WarnForgotPassphrase", @"To protect your data, SafeSlinger does not store your passphrase anywhere for recovery. You may only access recipients and messages created under the same passphrase login. However, you may generate a new key and passphrase, then repeat Sling Keys with your recipients.")
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                            otherButtonTitles:NSLocalizedString(@"btn_CreateNewKey", @"Create New Key"), nil];
    
    [message show];
    message = nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex!=alertView.cancelButtonIndex) {
        // Create New Key
        [self performSegueWithIdentifier:@"CreateNewKey" sender:self];
    }
}

- (void)StartRetryTimer {
    tout_bound++;
    if(tout_bound>=PENALTY_TIME) {
        [self StopRetryTimer];
    } else {
        [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(UpdateRetryTimer) userInfo:nil repeats:NO];
    }
}

- (void)UpdateRetryTimer {
    PassField.placeholder = [NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"label_PassHintBackoff", @"Retry"), [NSString stringWithFormat: NSLocalizedString(@"label_seconds", @"%d sec"), PENALTY_TIME-tout_bound]];
    [self StartRetryTimer];
}

- (void)StopRetryTimer {
    DoneBtn.enabled = YES;
    PassField.enabled = YES;
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintEnter", @"Passphrase")];
    tout_bound = error_t = 0;
}

- (IBAction)Login:(id)sender {
    if([self CheckPassphase: PassField.text]) {
        error_t = 0;
        // [delegate GainAccess];
        [self performSegueWithIdentifier: @"SwitchToMain" sender:self];
        
    } else {
        [[[[iToast makeText: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        PassField.text = nil;
        error_t++;
    }
    
    if(error_t>=MAX_PINCODE_RETRY) {
        PassField.text = @"";
        PassField.enabled = NO;
        DoneBtn.enabled = NO;
        [self StartRetryTimer];
    }
}

-(IBAction)PressHelp:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: nil
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_Help", @"Help"),
                                  NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"),
                                  NSLocalizedString(@"menu_License", @"License"),
                                  NSLocalizedString(@"menu_PrivacyPolicy", @"Privacy Policy"),
                                  nil];
    
    [actionSheet showInView: self.view];
    actionSheet = nil;
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case Help: {
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_passphrase", @"Passphrase")
                                                              message:NSLocalizedString(@"help_passphrase", @"Use this screen to login to the application with your passphrase. If you have forgotten your passphrase, you may generate a new key protected by a new passphrase by tapping the Forgot Passphrase? button. Tap the user name to switch between multiple keys.")
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                    otherButtonTitles:nil];
            
            [message show];
            message = nil;
        }
            break;
        case Feedback:
            [UtilityFunc SendOpts:self];
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

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    switch (result) {
        case MFMailComposeResultCancelled:
        case MFMailComposeResultSaved:
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
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

- (void)viewDidLoad {
    [super viewDidLoad];
    // Set delegate and get version number
    delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    VersionLabel.text = [delegate getVersionNumber];
    [DoneBtn setTitle:NSLocalizedString(@"btn_OK", @"OK") forState: UIControlStateNormal];
    [NewKeyBtn setTitle: NSLocalizedString(@"menu_ForgotPassphrase", @"Forgot Passphrase?")];
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintEnter", @"Passphrase")];
    
    error_t = 0;
    tout_bound = 0;
    _originalFrame = self.view.frame;
    self.navigationItem.hidesBackButton = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    PassField.text = nil;
    [KeySelectBtn setTitle:delegate.IdentityName forState:UIControlStateNormal];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [PassField resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
	NSDictionary* info = [notification userInfo];
	CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
 
	UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
	Scrollview.contentInset = contentInsets;
	Scrollview.scrollIndicatorInsets = contentInsets;
 
	// If active text field is hidden by keyboard, scroll it so it's visible
	CGRect rect = self.view.frame;
	rect.size.height -= kbSize.height;
	
	CGPoint scrollPoint = PassField.frame.origin;
	
	if (!CGRectContainsPoint(rect, scrollPoint) ) {
		[self.Scrollview scrollRectToVisible:PassField.frame animated:YES];
	}
}

- (void)keyboardWillHide:(NSNotification *)notification {
	UIEdgeInsets contentInsets = UIEdgeInsetsZero;
	Scrollview.contentInset = contentInsets;
	Scrollview.scrollIndicatorInsets = contentInsets;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

-(void)SelectDifferentKey {
    [delegate.DbInstance CloseDB];
    [delegate.DbInstance LoadDBFromStorage:[[[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY] objectAtIndex:[[NSUserDefaults standardUserDefaults] integerForKey:kDEFAULT_DB_KEY]]];
    [delegate checkIdentity];
    [KeySelectBtn setTitle:delegate.IdentityName forState:UIControlStateNormal];
    [self.view setNeedsDisplay];
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if([[segue identifier]isEqualToString:@"CreateNewKey"]) {
        SetupView *setup = (SetupView*)[segue destinationViewController];
        setup.newkeycreated = YES;
    } else if([[segue identifier]isEqualToString:@"KeySelection"]) {
        KeySelectionView *keySelect = (KeySelectionView*)[segue destinationViewController];
        keySelect.parent = self;
    }
}

@end
