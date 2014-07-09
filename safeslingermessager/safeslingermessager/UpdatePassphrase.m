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

#import "UpdatePassphrase.h"
#import "SSEngine.h"
#import "AppDelegate.h"
#import "Config.h"
#import <safeslingerexchange/iToast.h>

@interface UpdatePassphrase ()

@end

@implementation UpdatePassphrase

@synthesize ProfileLabel, PassField, RepeatPassField, OldPassField, Scrollview;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    [OldPassField setText:@""];
    [OldPassField setPlaceholder:NSLocalizedString(@"label_PassHintCurrent", @"Current Passphrase")];
    [PassField setText:@""];
    [PassField setPlaceholder:NSLocalizedString(@"label_PassHintChange", @"Updated Passphrase")];
    [RepeatPassField setText:@""];
    [RepeatPassField setPlaceholder:NSLocalizedString(@"label_PassHintRepeat", @"Repeat Passphrase")];
    self.navigationItem.title = NSLocalizedString(@"label_PassHintChange", @"Updated Passphrase");
    _originalFrame = self.view.frame;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSArray *list = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_LIST];
    [ProfileLabel setText:[list objectAtIndex: [[NSUserDefaults standardUserDefaults]integerForKey: kDEFAULT_DB_KEY]]];
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
    [RepeatPassField resignFirstResponder];
    [OldPassField resignFirstResponder];
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) ReEncryptPrivetKeys: (NSString*)newpassphrase OldPassword:(NSString*)oldpassphrase
{
    AppDelegate *delegate = [[UIApplication sharedApplication]delegate];
    
    // unlock
    int PRIKEY_STORE_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
    int PRIKEY_STORE_FORSIGN_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_FORSIGN_SIZE"] getBytes:&PRIKEY_STORE_FORSIGN_SIZE length:sizeof(PRIKEY_STORE_FORSIGN_SIZE)];
    
    if([SSEngine TestPassPhase:oldpassphrase KeySize1:PRIKEY_STORE_SIZE KeySize2:PRIKEY_STORE_FORSIGN_SIZE])
    {
        // Do re-encryption
        NSData* dSignKey = [SSEngine UnlockPrivateKey:oldpassphrase Size:PRIKEY_STORE_FORSIGN_SIZE Type:SIGN_PRI];
        NSData* dEncKey = [SSEngine UnlockPrivateKey:oldpassphrase Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
        
        [SSEngine LockPrivateKeys:newpassphrase RawData:dEncKey Type:ENC_PRI];
        [SSEngine LockPrivateKeys:newpassphrase RawData:dSignKey Type:SIGN_PRI];
        [self performSegueWithIdentifier: @"UpdatePassphraseFinish" sender:self];
    }else{
        [[[[iToast makeText: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
}

- (void)PassphraseChangeHandler
{
    NSString* oldpasstext = OldPassField.text;
    NSString* passtext = PassField.text;
    NSString* repeatpasstext = RepeatPassField.text;
    
    // update password
    if((passtext.length<MIN_PINCODE_LENGTH)||(repeatpasstext.length<MIN_PINCODE_LENGTH))
    {
        NSString *warn = [NSString stringWithFormat:NSLocalizedString(@"error_minPassphraseRequire", @"Passphrases require at least %d characters."), MIN_PINCODE_LENGTH];
        [[[[iToast makeText: warn]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    else if(![passtext isEqualToString:repeatpasstext])
    {
        [[[[iToast makeText: NSLocalizedString(@"error_passPhrasesDoNotMatch", @"Pass phrases do not match.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else {
        [[[[iToast makeText: NSLocalizedString(@"state_PassphraseUpdated", @"Passphrase updated.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [self ReEncryptPrivetKeys:passtext OldPassword:oldpasstext];
    }
}

- (IBAction)UpdateNewPhrase:(id)sender
{
    [self PassphraseChangeHandler];
}

#pragma UITextFieldDelegate Methods
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if([textField isEqual:OldPassField])
    {
        [PassField becomeFirstResponder];
    }else if([textField isEqual:PassField])
    {
        [RepeatPassField becomeFirstResponder];
    }else if([textField isEqual:RepeatPassField])
    {
        [RepeatPassField resignFirstResponder];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
