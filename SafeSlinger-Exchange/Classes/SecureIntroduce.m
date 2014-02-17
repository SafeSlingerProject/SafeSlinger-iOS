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

#import "SecureIntroduce.h"
#import "KeySlingerAppDelegate.h"
#import "SSContactSelector.h"
#import "VCardParser.h"
#import "iToast.h"
#import "Utility.h"
#import "VersionCheckMarco.h"
#import "sha3.h"
#import "SSEngine.h"
#import "ErrorLogger.h"

@interface SecureIntroduce ()

@end

@implementation SecureIntroduce

@synthesize delegate;
@synthesize USelector, User1Btn, User2Btn, User1Photo, User2Photo, IntroduceBtn, HintLabel;
@synthesize messageForU1, messageForU2;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.delegate = [[UIApplication sharedApplication]delegate];
        USelector = [[SSContactSelector alloc] initWithNibName:@"GeneralTableView" bundle:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction");
    // _U1Picked = _U2Picked = NO;
    _UserTag = -1;
    
    [HintLabel setText:NSLocalizedString(@"label_InstSendInvite", @"Pick recipients to introduce securely:")];
    [IntroduceBtn setTitle:NSLocalizedString(@"btn_Introduce", @"Introduce") forState:UIControlStateNormal];
    [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    
    // ? button
    UIButton * infoButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0, 30.0f)];
    [infoButton setImage:[UIImage imageNamed:@"help.png"] forState:UIControlStateNormal];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HomeButton];
    [HomeButton release];
    HomeButton = nil;
    [infoButton release];
    infoButton = nil;
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction")
                                                      message:NSLocalizedString(@"help_SecureIntroduction", @"This screen allows you to select two people you have slung keys with before to securely send their keys to each other. Simply press 'Introduce' when ready.")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    [message release];
    message = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [IntroduceBtn setEnabled:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc
{
    [self.USelector release];
    [super dealloc];
}

-(IBAction) pickUser:(id)sender
{
    switch([(UIButton*)sender tag])
    {
        case User1Tag:
            [_pickU1 release]; _pickU1 = nil;
            messageForU2 = nil;
            // reset User Button 1
            [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
            [User1Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
            break;
        case User2Tag:
            [_pickU2 release]; _pickU2 = nil;
            messageForU1 = nil;
            [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
            [User2Btn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
            break;
    }
    _UserTag = [(UIButton*)sender tag];
    // switch to SSContactSelector
    [delegate.navController pushViewController: USelector animated: YES];
}

-(void)setRecipient: (SSContactEntry*)GivenUser
{
    if(_UserTag==User1Btn.tag){
        // check valid users
        if(_pickU2&&[GivenUser.pushtoken isEqualToString: _pickU2.pushtoken])
        {
            // show dialog
            [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            [_pickU1 release]; _pickU1 = nil;
        }else{
            _pickU1 = [GivenUser retain];
            // UI
            self.messageForU2 = [NSString stringWithFormat:NSLocalizedString(@"label_messageIntroduceNameToYou", @"I would like to introduce %@ to you."), [NSString composite_name:_pickU1.fname withLastName:_pickU1.lname]];
            
            if([_pickU1.photo length]>0) [User1Photo setImage:[UIImage imageWithData:_pickU1.photo]];
            else [User1Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
            
            [User1Btn setTitle:[NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString composite_name:_pickU1.fname withLastName:_pickU1.lname], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:_pickU1.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]] forState:UIControlStateNormal];
        }
    }
    else if(_UserTag==User2Btn.tag) {
        // check valid users
        if(_pickU1&&[GivenUser.pushtoken isEqualToString: _pickU1.pushtoken])
        {
            // show dialog
            [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            [_pickU2 release]; _pickU2 = nil;
            return;
        }else{
            _pickU2 = [GivenUser retain];
            // UI
            self.messageForU1 = [NSString stringWithFormat:NSLocalizedString(@"label_messageIntroduceNameToYou", @"I would like to introduce %@ to you."), [NSString composite_name:_pickU2.fname withLastName:_pickU2.lname]];
            
            if([_pickU2.photo length]>0) [User2Photo setImage:[UIImage imageWithData:_pickU2.photo]];
            else [User2Photo setImage: [UIImage imageNamed: @"blank_contact.png"]];
            
            [User2Btn setTitle:[NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString composite_name:_pickU2.fname withLastName:_pickU2.lname], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:_pickU2.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]] forState:UIControlStateNormal];
        }
    }
}

- (void)SendIntroduceMessages
{
    [delegate.activityView EnableProgress:NSLocalizedString(@"prog_encrypting", @"encrypting...") SecondMeesage:@"" ProgessBar:NO];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    [IntroduceBtn setEnabled:NO];
    _U1Sent = _U2Sent = NO;
    
    NSData* VCardForU2 = [[self GetVCard:_pickU1]dataUsingEncoding:NSUTF8StringEncoding];
    NSData* VCardForU1 = [[self GetVCard:_pickU2]dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData* pktdata1 = [[NSMutableData alloc]initWithCapacity:0];
    NSMutableData* pktdata2 = [[NSMutableData alloc]initWithCapacity:0];
    
    _nonce1 = [[SSEngine BuildCipher:[NSString composite_name:_pickU1.fname withLastName:_pickU1.lname]  Token:_pickU1.pushtoken Message:messageForU1 Attach:@"introduction.vcf" RawFile:VCardForU1 MIMETYPE:@"SafeSlinger/SecureIntroduce" Cipher:pktdata1]retain];
    
    _nonce2 = [[SSEngine BuildCipher:[NSString composite_name:_pickU2.fname withLastName:_pickU2.lname]  Token:_pickU2.pushtoken Message:messageForU2 Attach:@"introduction.vcf" RawFile:VCardForU2 MIMETYPE:@"SafeSlinger/SecureIntroduce" Cipher:pktdata2]retain];
    
    // Send out U1 data
    NSURL *url1 = nil;
    switch (_pickU1.devType) {
        case Android:
            url1 = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTANDROIDMSG]];
            break;
        case iOS:
            url1 = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTIOSMSG]];
            break;
        default:
            break;
    }
    if(!url1)return;
    
    // Send out U2 data
    NSURL *url2 = nil;
    switch (_pickU2.devType) {
        case Android:
            url2 = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTANDROIDMSG]];
            break;
        case iOS:
            url2 = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTIOSMSG]];
            break;
        default:
            break;
    }
    if(!url2)return;
    
    NSMutableURLRequest *request1 = [NSMutableURLRequest requestWithURL:url1 cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request1 setURL: url1];
	[request1 setHTTPMethod: @"POST"];
	[request1 setHTTPBody: pktdata1];
    
    NSMutableURLRequest *request2 = [NSMutableURLRequest requestWithURL:url2 cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request2 setURL: url2];
	[request2 setHTTPMethod: @"POST"];
	[request2 setHTTPBody: pktdata2];
    
    [delegate.activityView UpdateProgessMsg:NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...")];
    
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
                     [self PrintErrorOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self PrintErrorOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
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
                         [self PrintErrorOnUI:error_msg];
                     });
                 }
             }
         }
        [pktdata1 release];
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
                     [self PrintErrorOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.") ];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self PrintErrorOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
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
                         [self PrintErrorOnUI:error_msg];
                     });
                 }
                 
             }
         }
         [pktdata2 release];
     }];
}

- (void)PrintErrorOnUI:(NSString*)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [delegate.activityView DisableProgress];
    [IntroduceBtn setEnabled:YES];
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

-(void) SaveMessages
{
    // save messages together
    MsgEntry *NewMsg1 = [[MsgEntry alloc]
                        initPlainTextMessage:_nonce1
                        UserName:[NSString composite_name:_pickU1.fname withLastName:_pickU1.lname]
                        Token:_pickU1.pushtoken
                        Message:messageForU1
                        Photo:nil
                        FileName:nil
                        FileType:nil
                        FIleData:nil];
    
    MsgEntry *NewMsg2 = [[MsgEntry alloc]
                         initPlainTextMessage:_nonce2
                         UserName:[NSString composite_name:_pickU2.fname withLastName:_pickU2.lname]
                         Token:_pickU2.pushtoken
                         Message:messageForU2
                         Photo:nil
                         FileName:nil
                         FileType:nil
                         FIleData:nil];
    
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
    [NewMsg1 release];
    [NewMsg2 release];
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [delegate.activityView DisableProgress];
    _U1Sent = _U2Sent = NO;
    [IntroduceBtn setEnabled:YES];
    [delegate.navController popViewControllerAnimated:YES];
}

-(NSString*) GetVCard: (SSContactEntry*)contact
{
    NSMutableString *vCard = [[NSMutableString alloc] init];
	[vCard appendString: @"BEGIN:VCARD\n"];
	[vCard appendString: @"VERSION:3.0\n"];
    [vCard appendString: [NSString vcardnstring:contact.fname withLastName:contact.lname]];
    [vCard appendString: @"\n"];
    
    if(contact.photo) [vCard appendFormat: @"PHOTO;TYPE=JPEG;ENCODING=b:%@\n",[Base64 encode:contact.photo]];

    NSString* pk = [NSString stringWithFormat:@"%@\n%@\n%@", contact.keyid, contact.keygenDate, [delegate.DbInstance GetRawKeyByToken: contact.pushtoken]];
    NSString* base64 = [Base64 encode:[pk dataUsingEncoding:NSASCIIStringEncoding]];
    [vCard appendFormat: @"IMPP;SafeSlinger-PubKey:%@\n", base64];
    
    // push token format: Base64EncodeByteArray(type | lentok | token)
    NSMutableData *encode = [NSMutableData dataWithLength:0];
    int devtype = htonl(contact.devType);
    int len = htonl([contact.pushtoken length]);
    [encode appendData:[NSData dataWithBytes: &devtype length: 4]];
    [encode appendData:[NSData dataWithBytes: &len length: 4]];
    [encode appendData:[contact.pushtoken dataUsingEncoding:NSASCIIStringEncoding]];
    
    base64 = [Base64 encode: encode];
    [vCard appendFormat: @"IMPP;SafeSlinger-Push:%@\n", base64];
	[vCard appendString: @"END:VCARD"];
	
    NSString* vcardstr = [vCard retain];
    [vCard release];
    vCard = nil;
    
	return vcardstr;
}

-(IBAction)StartIntoduce:(id)sender
{
    if(_pickU1&&_pickU2)
    {
        [self SendIntroduceMessages];
    }else {
        // show dialog
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }
}


@end

