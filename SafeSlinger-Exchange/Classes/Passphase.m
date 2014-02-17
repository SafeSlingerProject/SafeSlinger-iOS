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

#import "iToast.h"
#import "Passphase.h"
#import "ActivityWindow.h"
#import "KeySlingerAppDelegate.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "Utility.h"
#import <CommonCrypto/CommonDigest.h>

@interface Passphase ()

@end

@implementation Passphase

@synthesize VersionLabel, PassField, RepassField, mode, error_t;
@synthesize delegate, LoginBtn, KeySelectBtn, CancelBtn, errTimer, tout_bound;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        delegate = [[UIApplication sharedApplication] delegate];
        // check file is existing.., it not
        if([delegate.DbInstance GetConfig:@"PRIKEY_STATUS"])
            mode = NormalLogin;
        else
            mode = UnsetPass;
        error_t = 0;
        tout_bound = 0;
        _originalFrame = self.view.frame;
    }
    return self;
}

-(BOOL) CheckPassphase: (NSString*) passphrase
{
    NSString* status_str = [NSString stringWithCString:[[delegate.DbInstance GetConfig:@"PRIKEY_STATUS"] bytes] encoding:NSUTF8StringEncoding];
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
    }else if([status_str isEqualToString:@"DEC"]) // old version, still compare with hash
    {
        // old verison of code, will only perform once after upgrade
        BOOL ret;
        uint8_t digest[CC_SHA1_DIGEST_LENGTH];
        NSData* passdata = [passphrase dataUsingEncoding:NSASCIIStringEncoding];
        CC_SHA1([passdata bytes], [passdata length], digest);
        NSData *in_sha1 = [[NSData alloc] initWithBytes: digest length: CC_SHA1_DIGEST_LENGTH];
        // Compare with file
        NSData *st_sha1 = [[NSFileManager defaultManager] contentsAtPath: [NSString stringWithFormat: @"%@/passwd", delegate.documentsPath]];
        if([in_sha1 isEqualToData: st_sha1])
        {
            ret = YES;
            // store PINCode for unlock private key
            delegate.tempralPINCode = passphrase;
        }
        else {
            ret = NO;
        }
        [in_sha1 release];
        [st_sha1 release];
        return ret;
    }
    else
        return NO;
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
    
    NSData* encp = [NSData dataWithContentsOfFile:[SSEngine getSelfPrivateKeyPath: ENC_PRI]];
    NSData* signp = [NSData dataWithContentsOfFile:[SSEngine getSelfPrivateKeyPath: SIGN_PRI]];
    
    [SSEngine LockPrivateKeys:passphrase RawData:encp Type:ENC_PRI];
    [SSEngine LockPrivateKeys:passphrase RawData:signp Type:SIGN_PRI];
}

-(void) ReEncryptPrivetKeys: (NSString*) newpassphrase
{
    // unlock
    int PRIKEY_STORE_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
    DEBUGMSG(@"PRIKEY_STORE_SIZE = %d", PRIKEY_STORE_SIZE);
    int PRIKEY_STORE_FORSIGN_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_FORSIGN_SIZE"] getBytes:&PRIKEY_STORE_FORSIGN_SIZE length:sizeof(PRIKEY_STORE_FORSIGN_SIZE)];
    
    NSData* dSignKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_FORSIGN_SIZE Type:SIGN_PRI];
    NSData* dEncKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
    
    [SSEngine LockPrivateKeys:newpassphrase RawData:dEncKey Type:ENC_PRI];
    [SSEngine LockPrivateKeys:newpassphrase RawData:dSignKey Type:SIGN_PRI];
}

-(void)Handler
{
    NSString* passtext = PassField.text;
    NSString* repeatpasstext = RepassField.text;
    
    switch(mode)
    {
        case UnsetPass:
            // setup password
            if((passtext.length<MIN_PINCODE_LENGTH)||(repeatpasstext.length<MIN_PINCODE_LENGTH))
            {
                NSString *warn = [NSString stringWithFormat:NSLocalizedString(@"error_minPassphraseRequire", @"Passphrases require at least %d characters."), MIN_PINCODE_LENGTH];
                [[[[iToast makeText: warn]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                PassField.text = RepassField.text = nil;
            }
            else if(![passtext isEqualToString:repeatpasstext])
            {
                [[[[iToast makeText: NSLocalizedString(@"error_passPhrasesDoNotMatch", @"Pass phrases do not match.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                PassField.text = RepassField.text = nil;
            }
            else {
                [[[[iToast makeText: NSLocalizedString(@"state_PassphraseUpdated", @"Passphrase updated.")]
                   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                [self EncryptPrivateKeys:passtext];
                // allow user to login again using setup password
                mode = NormalLogin;
                [self InitializePanel];
            }
            break;
        case NormalLogin:
            // normal login
            if([self CheckPassphase: PassField.text])
            {
                error_t = 0;
                [delegate GainAccess];
            } else {
                [[[[iToast makeText: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")]
                    setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                PassField.text = RepassField.text = nil;
                error_t++;
            }
            break;
        case ChangePass:
            // change password
            if((passtext.length<MIN_PINCODE_LENGTH)||(repeatpasstext.length<MIN_PINCODE_LENGTH))
            {
                NSString *warn = [NSString stringWithFormat:NSLocalizedString(@"error_minPassphraseRequire", @"Passphrases require at least %d characters."), MIN_PINCODE_LENGTH];
                [[[[iToast makeText: warn]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                PassField.text = RepassField.text = nil;
            }
            else if(![passtext isEqualToString:repeatpasstext])
            {
                [[[[iToast makeText: NSLocalizedString(@"error_passPhrasesDoNotMatch", @"Pass phrases do not match.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                PassField.text = RepassField.text = nil;
            }
            else {
                [[[[iToast makeText: NSLocalizedString(@"state_PassphraseUpdated", @"Passphrase updated.")]
                   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                [self ReEncryptPrivetKeys:passtext];
                mode = NormalLogin;
                [self InitializePanel];
            }
            break;
        default:
            break;
    }
    
    if(error_t>=MAX_RETRY)
    {
        PassField.text = nil;
        PassField.enabled = NO;
        LoginBtn.enabled = NO;
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self StartRetryTimer];
        });
    }
}

- (void) StartRetryTimer
{
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
    PassField.placeholder = [NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"label_PassHintBackoff", @"Retry"), [NSString stringWithFormat: NSLocalizedString(@"label_seconds", @"%d sec"), PENALTY_TIME-tout_bound]];
    [self StartRetryTimer];
}

-(void) StopRetryTimer
{
    LoginBtn.enabled = YES;
    PassField.enabled = YES;
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintEnter", @"Passphrase")];
    tout_bound = error_t = 0;
}

-(IBAction)clickAction:(id)sender
{
    switch ([(UIButton*)sender tag]) {
        case SelectKey:
            [self SelectKeys];
            break;
        case AskHelp:
            [self PressHelp];
            break;
        case LoginSubmit:
            // setup password or login
            [PassField resignFirstResponder];
            break;
        case CancelPassChange:
            [self.view removeFromSuperview];
            break;
        default:
            break;
    }
}

-(void)SelectKeys
{
    KeyChooser *chooser = [[KeyChooser alloc] initWithNibName: @"GeneralTableView" bundle:nil parent:self];
    [self presentViewController:chooser animated:YES completion:NULL];
    [chooser release];
    chooser = nil;
}

-(void)PressHelp
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: nil
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_Help", @"Help"),
                                  NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"),
                                  nil];
    [actionSheet showInView: self.view];
    [actionSheet release];
    actionSheet = nil;
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(buttonIndex==Help)
    {
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_passphrase", @"Passphrase")
                                                          message:NSLocalizedString(@"help_passphrase", @"Use this screen to login to the application with your passphrase.")
                                                         delegate:nil
                                                cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                otherButtonTitles:nil];
        
        [message show];
        [message release];
        message = nil;
    }else if(buttonIndex==Feedback)
    {
        [self SendOpts];
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

- (void) InitializePanel
{
	switch(mode)
    {
        case UnsetPass:
            // first time setup
            [KeySelectBtn setHidden:YES];
            [CancelBtn setHidden:YES];
            [PassField setText:@""];
            [PassField setPlaceholder:NSLocalizedString(@"label_PassHintCreate", @"Create Passphrase")];
            [PassField setHidden:NO];
            [RepassField setText:@""];
            [RepassField setPlaceholder:NSLocalizedString(@"label_PassHintRepeat", @"Repeat Passphrase")];
            [RepassField setHidden:NO];
            break;
        case NormalLogin:
            // normal login
            [KeySelectBtn setHidden:NO];
            [CancelBtn setHidden:YES];
            [KeySelectBtn setTitle:delegate.myName forState:UIControlStateNormal];
            [RepassField setText:@""];
            [RepassField setHidden:YES];
            [PassField setText:@""];
            [PassField setPlaceholder:NSLocalizedString(@"label_PassHintEnter", @"Passphrase")];
            [LoginBtn setEnabled:YES];
            break;
        case ChangePass:
            // change password
            [KeySelectBtn setHidden:YES];
            [CancelBtn setHidden:NO];
            [PassField setText:@""];
            [PassField setHidden:NO];
            [PassField setPlaceholder:NSLocalizedString(@"label_PassHintChange", @"Updated Passphrase")];
            [RepassField setPlaceholder:NSLocalizedString(@"label_PassHintRepeat", @"Repeat Passphrase")];
            [RepassField setText:@""];
            [RepassField setHidden:NO];
            break;
        default:
            break;
	}
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Set delegate and get version number
    VersionLabel.text = [delegate getVersionNumber];
    [CancelBtn setTitle:NSLocalizedString(@"btn_Cancel", @"Cancel") forState: UIControlStateNormal];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self InitializePanel];
    
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
    [RepassField resignFirstResponder];
    
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
    UIScrollView *tempScrollView=(UIScrollView *)self.view;
    tempScrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height*1.5);
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    UIScrollView *tempScrollView=(UIScrollView *)self.view;
    tempScrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height);
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
    switch(mode)
    {
        case UnsetPass:
            // first time setup
            if(textField.tag==Pass) [RepassField becomeFirstResponder];
            else if(textField.tag==RePass) [self Handler];
            break;
        case NormalLogin:
            // normal login
            [self Handler];
            break;
        case ChangePass:
            // change password
            if(textField.tag==Pass) [RepassField becomeFirstResponder];
            else if(textField.tag==RePass) [self Handler];
            break;
        default:
            break;
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

@implementation KeyChooser

@synthesize keylist, keyitem, delegate, parent;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil parent:(Passphase*)parentpanel
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.keylist = [[NSMutableArray alloc]init];
        self.keyitem = [[NSMutableArray alloc]init];
        self.parent = parentpanel;
        self.delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // local possible key here, current only allow one key
    [keyitem addObject:delegate.myName];
    ;
    NSString *info = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_Key", @"Key:"),
                       [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat:@"MMM dd,yyyy HH:mm:ss"]];
    DEBUGMSG(@"info = %@", info);
    [keylist addObject:info];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(void) dealloc
{
    parent = nil;
    if(keylist)[keylist release];
    if(keyitem)[keyitem release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // load all files in Share folder
}

- (void)viewWillDisappear:(BOOL)animated
{
    [keylist removeAllObjects];
    [keyitem removeAllObjects];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [keyitem count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    // Configure the cell...
    cell.textLabel.text = (NSString*)[self.keyitem objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = (NSString*)[self.keylist objectAtIndex:indexPath.row];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // [parent SetField: indexPath.row];
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    // Navigation logic may go here. Create and push another view controller.
    [self dismissViewControllerAnimated:YES completion:NULL];
}

@end
