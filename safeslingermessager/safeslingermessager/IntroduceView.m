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

#import "IntroduceView.h"
#import "AppDelegate.h"
#import "Utility.h"
#import "ContactSelectView.h"
#import "SafeSlingerDB.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "FunctionView.h"
#import "VCardParser.h"
#import "ContactSelectView.h"

@interface IntroduceView ()

@end

@implementation IntroduceView

@synthesize delegate, User1Btn, User2Btn, User1Photo, User2Photo, IntroduceBtn, HintLabel;
@synthesize messageForU1, messageForU2;
@synthesize pickU1, pickU2, pickUser;
@synthesize ProgressLabel, ProgressIndicator;

- (void)viewDidLoad {
    [super viewDidLoad];
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    [HintLabel setText:NSLocalizedString(@"label_InstSendInvite", @"Pick recipients to introduce securely:")];
    [IntroduceBtn setTitle:NSLocalizedString(@"btn_Introduce", @"Introduce") forState:UIControlStateNormal];
    [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
    [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
}

- (void)viewWillAppear:(BOOL)animated {
    self.parentViewController.navigationItem.title = NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction");
    
    // ? button
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.parentViewController.navigationItem setRightBarButtonItem:HomeButton];
    
    [ProgressLabel setText:nil];
    [ProgressIndicator stopAnimating];
    UserTag = 0;
//    [self CleanSelectContact: User1Tag];
//    [self CleanSelectContact: User2Tag];
}

- (void)DisplayHow {
    
    UIAlertController* actionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
                                                             
                                                         }];
    UIAlertAction* helpAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_Help", @"Help")
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
                                                           [self performSegueWithIdentifier:@"ShowHelp" sender:self];
                                                       }];
    UIAlertAction* feedbackAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback")
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                                                               [UtilityFunc SendOpts:self];
                                                           }];
    // note: you can control the order buttons are shown, unlike UIActionSheet
    [actionSheet addAction:cancelAction];
    [actionSheet addAction:helpAction];
    [actionSheet addAction:feedbackAction];
    [actionSheet setModalPresentationStyle:UIModalPresentationPopover];
    [self presentViewController:actionSheet animated:YES completion:nil];
    
    /*
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: nil
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_Help", @"Help"),
                                  NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"),
                                  nil];
    [actionSheet showFromBarButtonItem:self.parentViewController.navigationItem.rightBarButtonItem animated:YES];
    actionSheet = nil;
    */
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
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

- (BOOL)EvaluateContact: (ContactEntry*)SelectContact {
    BOOL _SafeSelect = YES;
    
    if(SelectContact==nil) return !_SafeSelect;
    
    switch (pickUser) {
        case User1Tag:
            if(pickU2&&[SelectContact.keyId isEqualToString: pickU2.keyId]) _SafeSelect = NO;
            break;
        case User2Tag:
            if(pickU1&&[SelectContact.keyId isEqualToString: pickU1.keyId]) _SafeSelect = NO;
            break;
        default:
            break;
    }
    
    if(!_SafeSelect)
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    
    return _SafeSelect;
}

- (void)SetupContact:(ContactEntry*)SelectContact {
    switch (pickUser) {
		case User1Tag: {
            pickU1 = SelectContact;
            messageForU2 = [NSString stringWithFormat:NSLocalizedString(@"label_messageIntroduceNameToYou", @"I would like to introduce %@ to you."), [NSString compositeName:pickU1.firstName withLastName:pickU1.lastName]];
			
			[User1Photo setImage:pickU1.photo.length > 0 ? [UIImage imageWithData:pickU1.photo] : [UIImage imageNamed:@"blank_contact.png"]];
			
			NSString *buttonTitle = [NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString compositeName:pickU1.firstName withLastName:pickU1.lastName], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:pickU1.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]];
			
            [User1Btn setTitle:buttonTitle forState:UIControlStateNormal];
            break;
		}
		case User2Tag: {
            pickU2 = SelectContact;
            messageForU1 = [NSString stringWithFormat:NSLocalizedString(@"label_messageIntroduceNameToYou", @"I would like to introduce %@ to you."), [NSString compositeName:pickU2.firstName withLastName:pickU2.lastName]];
			
			[User2Photo setImage:pickU2.photo.length > 0 ? [UIImage imageWithData:pickU2.photo] : [UIImage imageNamed:@"blank_contact.png"]];
			
			NSString *buttonTitle = [NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString compositeName:pickU2.firstName withLastName:pickU2.lastName], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:pickU2.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]];
			
            [User2Btn setTitle:buttonTitle forState:UIControlStateNormal];
            break;
		}
    }
}

-(IBAction)StartIntoduce:(id)sender
{
    if(pickU1&&pickU2)
    {
        [self SendIntroduceMessages];
    }else {
        // show dialog
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }
}

- (void)SendIntroduceMessages
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [ProgressLabel setText: NSLocalizedString(@"prog_encrypting", @"encrypting...")];
        [ProgressIndicator startAnimating];
    });
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    [IntroduceBtn setEnabled:NO];
    _U1Sent = _U2Sent = NO;
    
    NSData* VCardForU2 = [VCardParser GetSimpleVCard: pickU1 RawPubkey: [delegate.DbInstance GetRawKey: pickU1.keyId]];
    NSData* VCardForU1 = [VCardParser GetSimpleVCard: pickU2 RawPubkey: [delegate.DbInstance GetRawKey: pickU2.keyId]];
    
    NSMutableData* pktdata1 = [[NSMutableData alloc]initWithCapacity:0];
    NSMutableData* pktdata2 = [[NSMutableData alloc]initWithCapacity:0];
    
    _nonce1 = [SSEngine BuildCipher: pickU1.keyId Message:[messageForU1 dataUsingEncoding:NSUTF8StringEncoding] Attach: @"introduction.vcf" RawFile:VCardForU1 MIMETYPE:@"SafeSlinger/SecureIntroduce" Cipher:pktdata1];
    _nonce2 = [SSEngine BuildCipher: pickU2.keyId Message:[messageForU2 dataUsingEncoding:NSUTF8StringEncoding] Attach: @"introduction.vcf" RawFile:VCardForU2 MIMETYPE:@"SafeSlinger/SecureIntroduce" Cipher:pktdata2];
    
    // Send out U1 data
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTMSG]];
    
    NSMutableURLRequest *request1 = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request1 setURL: url];
	[request1 setHTTPMethod: @"POST"];
	[request1 setHTTPBody: pktdata1];
    
    NSMutableURLRequest *request2 = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request2 setURL: url];
	[request2 setHTTPMethod: @"POST"];
	[request2 setHTTPBody: pktdata2];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [ProgressLabel setText: NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...")];
    });
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request1 queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if(error)
         {
             // inform the user
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             if(error.code==NSURLErrorTimedOut)
             {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [ProgressIndicator stopAnimating];
                     [ProgressLabel setText: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                     UserTag = 0;
                     [self CleanSelectContact: User1Tag];
                     [self CleanSelectContact: User2Tag];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [ProgressLabel setText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     [ProgressIndicator stopAnimating];
                     UserTag = 0;
                     [self CleanSelectContact: User1Tag];
                     [self CleanSelectContact: User2Tag];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // start parsing data
                 DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
                 [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                 if (ntohl(*(int *)msgchar) > 0)
                 {
                     // Send Response
                     DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                     DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                     // Save to Database
                     _U1Sent = YES;
                     if(_U1Sent&&_U2Sent)
                     {
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self SaveMessages];
                         });
                     }
                 }else if(ntohl(*(int *)msgchar) == 0)
                 {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [ProgressLabel setText: error_msg];
                         [ProgressIndicator stopAnimating];
                         UserTag = 0;
                         [self CleanSelectContact: User1Tag];
                         [self CleanSelectContact: User2Tag];
                     });
                 }
             }
         }
     }];
    
    [NSURLConnection sendAsynchronousRequest:request2 queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if(error)
         {
             // inform the user
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             if(error.code==NSURLErrorTimedOut)
             {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [ProgressLabel setText: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                     [ProgressIndicator stopAnimating];
                     UserTag = 0;
                     [self CleanSelectContact: User1Tag];
                     [self CleanSelectContact: User2Tag];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [ProgressLabel setText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     [ProgressIndicator stopAnimating];
                     UserTag = 0;
                     [self CleanSelectContact: User1Tag];
                     [self CleanSelectContact: User2Tag];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // start parsing data
                 DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                 if (ntohl(*(int *)msgchar) > 0)
                 {
                     // Send Response
                     DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                     DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                     // Save to Database
                     _U2Sent = YES;
                     if(_U1Sent&&_U2Sent)
                     {
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self SaveMessages];
                         });
                     }
                 }else if(ntohl(*(int *)msgchar) == 0)
                 {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [ProgressLabel setText: error_msg];
                         [ProgressIndicator stopAnimating];
                         UserTag = 0;
                         [self CleanSelectContact: User1Tag];
                         [self CleanSelectContact: User2Tag];
                     });
                 }
                 
             }
         }
     }];
}

-(void) SaveMessages
{
    // save messages together
    MsgEntry *NewMsg1 = [[MsgEntry alloc]
                         InitOutgoingMsg:_nonce1
                         Recipient:pickU1
                         Message:messageForU1
                         FileName:nil
                         FileType:nil
                         FileData:nil];
    
    MsgEntry *NewMsg2 = [[MsgEntry alloc]
                         InitOutgoingMsg:_nonce2
                         Recipient: pickU2
                         Message:messageForU2
                         FileName:nil
                         FileType:nil
                         FileData:nil];
    
    // get self photo if necessary
    if([delegate.DbInstance InsertMessage: NewMsg1]&&[delegate.DbInstance InsertMessage: NewMsg2]) {
        // reload the view
        [[[[iToast makeText: NSLocalizedString(@"state_FileSent", @"Message sent.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    } else {
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [ProgressIndicator stopAnimating];
    [ProgressLabel setText:nil];
    _U1Sent = _U2Sent = NO;
    [IntroduceBtn setEnabled:YES];
    
    // clear contacts
    UserTag = 0;
    [self CleanSelectContact: User1Tag];
    [self CleanSelectContact: User2Tag];
}

- (IBAction)SelectContact:(id)sender {
    pickUser = [sender tag];
    switch ([sender tag]) {
        case User1Tag:
            [self CleanSelectContact: User1Tag];
            [self performSegueWithIdentifier:@"SelectContact" sender:self];
            break;
        case User2Tag:
            [self CleanSelectContact: User2Tag];
            [self performSegueWithIdentifier:@"SelectContact" sender:self];
            break;
        default:
            break;
    }
}

- (void)CleanSelectContact: (int)index {
    switch (index) {
        case User1Tag:
            messageForU2 = nil;
            pickU1 = nil;
            [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
            [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
            break;
        case User2Tag:
            messageForU1 = nil;
            pickU2 = nil;
            [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
            [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
            break;
        default:
            break;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue identifier]isEqualToString:@"SelectContact"]) {
        ContactSelectView *dest = (ContactSelectView *)segue.destinationViewController;
        dest.delegate = self;
		dest.contactSelectionMode = ContactSelectionModeIntroduce;
    }
}

#pragma mark - ContactSelectViewDelegate methods

- (void)contactSelected:(ContactEntry *)contact {
	if([self EvaluateContact:contact]) {
		[self SetupContact:contact];
	}
}

- (void)contactDeleted:(ContactEntry *)contact {
	if([pickU1.pushToken isEqualToString:contact.pushToken]) {
		[self CleanSelectContact:User1Tag];
	} else if([pickU2.pushToken isEqualToString:contact.pushToken]) {
		[self CleanSelectContact:User2Tag];
	}
}

@end
