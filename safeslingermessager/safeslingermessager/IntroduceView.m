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

#import "IntroduceView.h"
#import "AppDelegate.h"
#import "Utility.h"
#import "ContactSelectView.h"
#import "SafeSlingerDB.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "FunctionView.h"
#import "VCardParser.h"

@interface IntroduceView ()

@end

@implementation IntroduceView

@synthesize delegate, User1Btn, User2Btn, User1Photo, User2Photo, IntroduceBtn, HintLabel;
@synthesize messageForU1, messageForU2;
@synthesize pickU1, pickU2, UserTag;
@synthesize ProgressLabel, ProgressIndicator;

- (void)viewDidLoad
{
    DEBUGMSG(@"viewDidLoad");
    [super viewDidLoad];
    
    delegate = [[UIApplication sharedApplication]delegate];
    
    [HintLabel setText:NSLocalizedString(@"label_InstSendInvite", @"Pick recipients to introduce securely:")];
    [IntroduceBtn setTitle:NSLocalizedString(@"btn_Introduce", @"Introduce") forState:UIControlStateNormal];
    
    [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
    
    [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.parentViewController.navigationItem.title = NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction");
    
    // ? button
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.parentViewController.navigationItem setRightBarButtonItem:HomeButton];
    
    [ProgressLabel setText:nil];
    [ProgressIndicator stopAnimating];
    
    messageForU1 = nil;
    [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
    messageForU2 = nil;
    [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction")
                                                      message:NSLocalizedString(@"help_SecureIntroduction", @"This screen allows you to select two people you have slung keys with before to securely send their keys to each other. Simply press 'Introduce' when ready.")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    message = nil;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)unwindToIntroduction:(UIStoryboardSegue *)unwindSegue
{
    DEBUGMSG(@"unwindToIntroduction");
    DEBUGMSG(@"[unwindSegue identifier] = %@", [unwindSegue identifier]);
    DEBUGMSG(@"unwindSegue.sourceViewController = %@", unwindSegue.sourceViewController);
    
    if([[unwindSegue identifier]isEqualToString:@"FinishContactSelect"])
    {
        ContactSelectView *view = [unwindSegue sourceViewController];
        switch (UserTag) {
            case 1:
                pickU1 = view.selectedUser;
                break;
            case 2:
                pickU2 = view.selectedUser;
                break;
            default:
                break;
        }
        
        if(pickU2&&pickU1&&[pickU1.keyid isEqualToString: pickU2.keyid])
        {
            DEBUGMSG(@"Invalid recipient.");
            // show dialog
            [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            // rest the selected one
            switch (UserTag) {
                case 1:
                    DEBUGMSG(@"reset pickU1");
                    pickU1 = nil;
                    messageForU2 = nil;
                    break;
                case 2:
                    DEBUGMSG(@"reset pickU2");
                    pickU2 = nil;
                    messageForU1 = nil;
                    break;
                default:
                    break;
            }
        }
        
        switch (UserTag) {
            case 1:
            {
                if(pickU1)
                {
                    messageForU2 = [NSString stringWithFormat:NSLocalizedString(@"label_messageIntroduceNameToYou", @"I would like to introduce %@ to you."), [NSString composite_name:pickU1.fname withLastName:pickU1.lname]];
                    if([pickU1.photo length]>0) [User1Photo setImage:[UIImage imageWithData:pickU1.photo]];
                    else [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
                    [User1Btn setTitle:[NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString composite_name:pickU1.fname withLastName:pickU1.lname], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:pickU1.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]] forState:UIControlStateNormal];
                }
            }
                break;
            case 2:
            {
                if(pickU2)
                {
                    messageForU1 = [NSString stringWithFormat:NSLocalizedString(@"label_messageIntroduceNameToYou", @"I would like to introduce %@ to you."), [NSString composite_name:pickU2.fname withLastName:pickU2.lname]];
                    
                    if([pickU2.photo length]>0) [User2Photo setImage:[UIImage imageWithData:pickU2.photo]];
                    else [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
                    
                    [User2Btn setTitle:[NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString composite_name:pickU2.fname withLastName:pickU2.lname], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:pickU2.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]] forState:UIControlStateNormal];
                }
            }
                break;
            default:
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
    
    NSData* VCardForU2 = [VCardParser GetSimpleVCard: pickU1 RawPubkey: [delegate.DbInstance GetRawKey: pickU1.keyid]];
    NSData* VCardForU1 = [VCardParser GetSimpleVCard: pickU2 RawPubkey: [delegate.DbInstance GetRawKey: pickU2.keyid]];
    
    NSMutableData* pktdata1 = [[NSMutableData alloc]initWithCapacity:0];
    NSMutableData* pktdata2 = [[NSMutableData alloc]initWithCapacity:0];
    
    _nonce1 = [SSEngine BuildCipher: pickU1.keyid Message:messageForU1 Attach: @"introduction.vcf" RawFile:VCardForU1 MIMETYPE:@"SafeSlinger/SecureIntroduce" Cipher:pktdata1];
    
    _nonce2 = [SSEngine BuildCipher: pickU2.keyid Message:messageForU2 Attach: @"introduction.vcf" RawFile:VCardForU2 MIMETYPE:@"SafeSlinger/SecureIntroduce" Cipher:pktdata2];
    
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
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [ProgressLabel setText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     [ProgressIndicator stopAnimating];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // start parsing data
                 DEBUGMSG(@"Succeeded! Received %d bytes of data",[data length]);
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
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [ProgressLabel setText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     [ProgressIndicator stopAnimating];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // start parsing data
                 DEBUGMSG(@"Succeeded! Received %d bytes of data",[data length]);
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
    if([delegate.DbInstance InsertMessage: NewMsg1]&&[delegate.DbInstance InsertMessage: NewMsg2])
    {
        // reload the view
        [[[[iToast makeText: NSLocalizedString(@"state_FileSent", @"Message sent.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else{
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [ProgressIndicator stopAnimating];
    [ProgressLabel setText:nil];
    _U1Sent = _U2Sent = NO;
    [IntroduceBtn setEnabled:YES];
}

-(IBAction)SelectRecipient:(id)sender
{
    if(sender==User1Btn)
    {
        DEBUGMSG(@"User1Btn");
        UserTag = 1;
        //tabview.SelectEntry1 = pickU1 = nil;
        messageForU2 = nil;
        [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
        [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
        
    }else if(sender==User2Btn)
    {
        DEBUGMSG(@"User2Btn");
        UserTag = 2;
        //tabview.SelectEntry2 = pickU2 = nil;
        messageForU1 = nil;
        [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
        [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    }
    
    [self performSegueWithIdentifier:@"ContactSelectForIntro" sender:self];
}

@end
