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

#import "SetupView.h"
#import "SSEngine.h"
#import "AppDelegate.h"
#import "Utility.h"
#import <safeslingerexchange/iToast.h>

@interface SetupView ()

@end

@implementation SetupView

@synthesize DoneBtn;
@synthesize Lnamefield, Fnamefield, backinfo, instruction, nameLabel, delegate;
@synthesize keygenIndicator, keygenProgress, newkeycreated;
@synthesize PassField, RepassField, passphraseLabel, Scrollview;
@synthesize LicenseBtn, PrivacyBtn;

- (void)viewDidLoad
{
    [super viewDidLoad];
     
    // Do any additional setup after loading the view from its nib.
    [instruction setText:NSLocalizedString(@"label_FindInstruct", "Choose the data you wish to represent you. Your data can only be sent to other contacts, securely, at the time of your choosing.")];
    [nameLabel setText:NSLocalizedString(@"label_ContactName", @"Your Name")];
    [passphraseLabel setText: NSLocalizedString(@"title_passphrase", @"Passphrase")];
    
    [Fnamefield setPlaceholder:NSLocalizedString(@"label_FirstName", @"First Name")];
    [Lnamefield setPlaceholder:NSLocalizedString(@"label_LastName", @"Last Name")];
    [PassField setText:@""];
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintCreate", @"Create Passphrase")];
    [RepassField setText:@""];
    [RepassField setPlaceholder:NSLocalizedString(@"label_PassHintRepeat", @"Repeat Passphrase")];
    [LicenseBtn setTitle:NSLocalizedString(@"menu_License", @"License") forState:UIControlStateNormal];
    [PrivacyBtn setTitle:NSLocalizedString(@"menu_PrivacyPolicy", @"Privacy Policy") forState:UIControlStateNormal];
    
    // ? button
    self.navigationItem.title = NSLocalizedString(@"title_find", @"Setup");
    _originalFrame = self.view.frame;
    
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    _bg_queue = dispatch_queue_create("safeslinger.background.queue", NULL);
    
    [delegate.BackupSys RecheckCapability];
    if(delegate.BackupSys.CloudEnabled){
        [backinfo setText:NSLocalizedString(@"label_iCloudEnable", @"SafeSlinger iCloud is enabled. Tap the Done button when finished.")];
    }else {
        [backinfo setText:NSLocalizedString(@"label_TouchToConfigureBackupSettings", @"You may optionally enable SafeSlinger iCloud backup in iOS Settings. Tap the 'Done' button when finished.")];
    }
}

-(IBAction)ClickPrivacy:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: kPrivacyURL]];
}

-(IBAction)ClickLicense:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: kLicenseURL]];
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

- (void)NotifyRestoreResult: (BOOL)result
{
    [self SetComponentsLocked:NO];
    // delegate to handle backup recovery...
    if(result) {
        [delegate checkIdentity];
        [self performSegueWithIdentifier:@"FinishSetup" sender:self];
    } else {
        [[[[iToast makeText: NSLocalizedString(@"error_BackupNotFound", @"No backup to restore.")]setGravity:iToastGravityCenter] setDuration:iToastDurationLong] show];
        backinfo.text = NSLocalizedString(@"label_iCloudEnable", @"SafeSlinger iCloud is enabled. Tap the 'Done' button when finished.");
        [self TriggerNotificationRequire];
    }
}

- (void)TriggerNotificationRequire
{
    if(![[NSUserDefaults standardUserDefaults] boolForKey: kRequirePushNotification]) {
        // case PushNotificationConfirm
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                                       message:NSLocalizedString(@"iOS_RequestPermissionNotifications", @"SafeSlinger is an encrypted messaging application and cannot function without allowing incoming messages from Notifications. To enable incoming messages, you must allow SafeSlinger to send you Notifications when asked.")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Continue", @"Continue")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action){
                                                             [[NSUserDefaults standardUserDefaults] setBool:YES forKey: kRequirePushNotification];
                                                             [delegate registerPushToken];
                                                         }];
        
        [alert addAction:okAction];
        UIAlertAction* exitAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Exit", @"Exit")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action){
                                                            exit(EXIT_SUCCESS);
                                                        }];
        
        [alert addAction:exitAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    if(!newkeycreated) {
        // first setup, try to fecth backup
        
        [delegate.BackupSys RecheckCapability];
        
        if(delegate.BackupSys.CloudEnabled) {
            delegate.BackupSys.Responder = self;
            // genkey first, locked all components
            [self SetComponentsLocked: YES];
            [backinfo setText:NSLocalizedString(@"prog_SearchingForBackup", @"searching for backup...")];
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self.navigationItem setHidesBackButton:YES];
                [self updateprogress];
                [delegate.BackupSys PerformRecovery];
            });
        } else {
            [self.navigationItem setHidesBackButton:YES];
            [self TriggerNotificationRequire];
        }
    }
    
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
    
    // get height of the keyboard
    CGFloat offset = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size.height+_textfieldOffset-_originalFrame.size.height+60.0f;
    if(offset > 0) {
        // covered by keyboard, left the view and scroll it
        [Scrollview setContentOffset:CGPointMake(0.0, offset) animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    Scrollview.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height);
}

- (void)BackupDatabase
{
    [delegate.DbInstance CloseDB];
    
    NSArray *keyarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY];
    NSMutableArray *arr = [NSMutableArray arrayWithArray:keyarr];
    NSString *keyloc = [NSString stringWithFormat:@"%@-%lu", DATABASE_NAME, (unsigned long)[arr count]];
    [arr addObject:keyloc];
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_KEY];
    
    // Create a new database
    [delegate.DbInstance LoadDBFromStorage:keyloc];
}

-(void) EncryptPrivateKeys: (NSString*) passphrase
{
    // Setup case
    int PRIKEY_STORE_SIZE = [SSEngine getSelfPrivateKeySize:ENC_PRI];
    [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)] withTag:@"PRIKEY_STORE_SIZE"];
    // PRIKEY_STORE_FORSIGN_SIZE
    int PRIKEY_STORE_FORSIGN_SIZE = [SSEngine getSelfPrivateKeySize:SIGN_PRI];
    [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes:&PRIKEY_STORE_FORSIGN_SIZE length:sizeof(PRIKEY_STORE_FORSIGN_SIZE)] withTag:@"PRIKEY_STORE_FORSIGN_SIZE"];
    NSString* enc = @"ENC";
    [delegate.DbInstance InsertOrUpdateConfig:[enc dataUsingEncoding:NSUTF8StringEncoding] withTag:@"PRIKEY_STATUS"];
    
    NSData* encp = [SSEngine getPrivateKey: ENC_PRI];
    NSData* signp = [SSEngine getPrivateKey: SIGN_PRI];
    
    [SSEngine LockPrivateKeys:passphrase RawData:encp Type:ENC_PRI];
    [SSEngine LockPrivateKeys:passphrase RawData:signp Type:SIGN_PRI];
    
    // Try to backup
    [delegate.BackupSys RecheckCapability];
    [delegate.BackupSys PerformBackup];
    
    [delegate checkIdentity];
}

- (void)SetComponentsLocked:(BOOL)lock
{
    if(lock) [self.navigationItem setHidesBackButton:YES];
    else [self.navigationItem setHidesBackButton:NO];
    
    DoneBtn.enabled = Fnamefield.enabled = Lnamefield.enabled = PassField.enabled = RepassField.enabled = !lock;
    keygenProgress.hidden = keygenIndicator.hidden = !lock;
    if(lock) {
        [keygenIndicator startAnimating];
        [keygenProgress setProgress:0.0f];
    } else {
        [keygenIndicator stopAnimating];
        [keygenProgress setProgress:1.0f];
    }
}

- (IBAction) DisplayHelp: (id)sender
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                                   message:NSLocalizedString(@"help_find", @"Use this screen to set your name, phone, and email to exchange with others. Tap the 'Done' button when finished.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* closeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action){
                                                         
                                                     }];
    
    [alert addAction:closeAction];
    UIAlertAction* feedbackAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action){
                                                             // feedback
                                                             [UtilityFunc SendOpts:self];
                                                         }];
    
    [alert addAction:feedbackAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)CreateProfile: (id)sender
{
    [self profileCreation];
}

- (void)profileCreation
{
    [Fnamefield resignFirstResponder];
    [Lnamefield resignFirstResponder];
    [PassField resignFirstResponder];
    [RepassField resignFirstResponder];
    
    NSString* passtext = PassField.text;
    NSString* repeatpasstext = RepassField.text;
    
    // error check
    if([Fnamefield.text length]==0 && [Lnamefield.text length]==0) {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        
    } else if((passtext.length<MIN_PINCODE_LENGTH) || (repeatpasstext.length<MIN_PINCODE_LENGTH)) {
        NSString *warn = [NSString stringWithFormat:NSLocalizedString(@"error_minPassphraseRequire", @"Passphrases require at least %d characters."), MIN_PINCODE_LENGTH];
        [[[[iToast makeText: warn]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        PassField.text = RepassField.text = nil;
    } else if(![passtext isEqualToString:repeatpasstext]) {
        [[[[iToast makeText: NSLocalizedString(@"error_passPhrasesDoNotMatch", @"Pass phrases do not match.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        PassField.text = RepassField.text = nil;
        
    } else {
        
        [[[[iToast makeText: NSLocalizedString(@"state_PassphraseUpdated", @"Passphrase updated.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        
        if(newkeycreated) [self BackupDatabase];
        
        // check key file existing
        if(![SSEngine checkCredentialExist]) {
            // genkey first, locked all components
            [self SetComponentsLocked: YES];
            [self.backinfo setText:NSLocalizedString(@"prog_GeneratingKey", @"generating key, this can take a while...")];
            
            dispatch_async(_bg_queue, ^(void) {
                [self GenKeyBackground];
            });
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self updateprogress];
            });
            
        } else {
            // goto genkeydone
            [self buildProfile];
        }
    }
}

- (void) updateprogress {
     float actual = [keygenProgress progress];
     if (actual < 0.94) {
         [keygenProgress setProgress: actual + 0.06];
         [NSTimer scheduledTimerWithTimeInterval:4.0f target:self selector:@selector(updateprogress) userInfo:nil repeats:NO];
     }
}

- (void)GenKeyBackground
{
    if([SSEngine GenKeyPairForENC]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [keygenProgress setProgress: 0.79f];
        });
    }
    if([SSEngine GenKeyPairForSIGN]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [keygenProgress setProgress:0.99f];
        });
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self SetComponentsLocked:NO];
        [self buildProfile];
    });
}

- (void)buildProfile
{
    // save profile
    [self EncryptPrivateKeys:PassField.text];
    
    if(!newkeycreated) {
        NSArray *arr = [NSArray arrayWithObjects: DATABASE_NAME, nil];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_KEY];
        NSString *keyinfo = [NSString stringWithFormat:@"%@\n%@ %@", [NSString compositeName:Fnamefield.text withLastName:Lnamefield.text], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat: @"yyyy-MM-dd HH:mm:ss"]];
        arr = [NSArray arrayWithObjects: keyinfo, nil];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_LIST];
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey: kDEFAULT_DB_KEY];
        
    } else {
        NSArray *infoarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_LIST];
        NSMutableArray *arr = [NSMutableArray arrayWithArray:infoarr];
        NSString *keyinfo = [NSString stringWithFormat:@"%@\n%@ %@", [NSString compositeName:Fnamefield.text withLastName:Lnamefield.text], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat: @"yyyy-MM-dd HH:mm:ss"]];
        [arr addObject: keyinfo];
        [[NSUserDefaults standardUserDefaults] setObject:arr forKey: kDB_LIST];
        // Set key index to the newest profile
        [[NSUserDefaults standardUserDefaults] setInteger:[arr count]-1 forKey: kDEFAULT_DB_KEY];
    }
    
    [delegate saveConactData:NonLink Firstname:Fnamefield.text Lastname:Lnamefield.text];
    [delegate checkIdentity];
    [self performSegueWithIdentifier:@"FinishSetup" sender:self];
}

#pragma mark UITextFieldDelegate Methods

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    _textfieldOffset = textField.frame.size.height + textField.frame.origin.y;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if([textField isEqual:Fnamefield]) {
        [Lnamefield becomeFirstResponder];
    } else if([textField isEqual:Lnamefield]) {
        [PassField becomeFirstResponder];
    } else if([textField isEqual:PassField]) {
        [RepassField becomeFirstResponder];
    } else if([textField isEqual:RepassField]) {
        [self profileCreation];
    }
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

@end
