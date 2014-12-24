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

#import "MessageDetailView.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "UniversalDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "VCardParser.h"
#import "InvitationView.h"
#import "MessageView.h"
#import <AudioToolbox/AudioToolbox.h>

@interface MessageDetailView ()

@end

@implementation MessageDetailView

@synthesize messages, delegate, b_img, thread_img, assignedEntry, OperationLock, actWindow, InstanceMessage, InstanceBtn, CancelBtn, BackBtn, InstanceBox;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    BackGroundQueue = dispatch_queue_create("safeslinger.background.queue", NULL);
    b_img = [UIImage imageNamed: @"blank_contact_small.png"];
    actWindow = [[ActivityWindow alloc] initWithNibName: @"ActivityWindow" bundle:[NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"exchangeui" withExtension:@"bundle"]]];
	
    OperationLock = [[NSLock alloc]init];
    
    messages = [[NSMutableArray alloc]init];
    _previewer = [[QLPreviewController alloc] init];
    [_previewer setDataSource:self];
    [_previewer setDelegate:self];
    [_previewer setCurrentPreviewItemIndex:0];
    
    //for unknown thread
    if([assignedEntry.keyid isEqualToString:@"UNDEFINED"]) {
        DEBUGMSG(@"UNDEFINED thread...");
        [InstanceBox setHidden:YES];
    } else if([delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"pid"] == nil) {
        DEBUGMSG(@"UNDEFINED thread...");
        [InstanceBox setHidden:YES];
    } else {
        [InstanceBox setHidden:NO];
    }
    
    // load message
    NSString* faceraw = [delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"note"];
    if([faceraw length]>0) {
        thread_img = [[UIImage imageWithData:[Base64 decode:faceraw]]scaleToSize:CGSizeMake(45.0f, 45.0f)];
    } else {
        thread_img = nil;
    }
    
    BackBtn = self.navigationItem.backBarButtonItem;
    
    CancelBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(DismissKeyboard)];
    
    [InstanceMessage setPlaceholder:NSLocalizedString(@"label_ComposeHint", @"Compose Message")];
    [InstanceBtn setTitle: NSLocalizedString(@"title_SendFile", @"Send") forState: UIControlStateNormal];
}

- (void)DismissKeyboard {
    [InstanceMessage resignFirstResponder];
}

- (void)ReloadTable {
    [messages removeAllObjects];
    [messages setArray:[delegate.DbInstance LoadThreadMessage: assignedEntry.keyid]];
    [messages addObjectsFromArray: [delegate.UDbInstance LoadThreadMessage: assignedEntry.keyid]];
    [self.tableView reloadData];
    
    NSIndexPath * ndxPath= [NSIndexPath indexPathForRow:[messages count]-1 inSection:0];
    @try {
        [self.tableView scrollToRowAtIndexPath:ndxPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    @catch (NSException *exception) {
    }
}

- (void)viewDidUnload {
    [super viewDidLoad];
    [messages removeAllObjects];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	delegate.MessageInBox.notificationDelegate = self;
	
    [messages removeAllObjects];
    [messages setArray:[delegate.DbInstance LoadThreadMessage: assignedEntry.keyid]];
    [messages addObjectsFromArray: [delegate.UDbInstance LoadThreadMessage: assignedEntry.keyid]];
    [self.tableView reloadData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(inputModeDidChange:)
												 name:@"UITextInputCurrentInputModeDidChangeNotification"
											   object:nil];
	
    NSIndexPath * ndxPath= [NSIndexPath indexPathForRow:[messages count]-1 inSection:0];
    @try {
        [self.tableView scrollToRowAtIndexPath:ndxPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    @catch (NSException *exception) {
    }
    @finally {
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"UITextInputCurrentInputModeDidChangeNotification"
												  object:nil];
	
	delegate.MessageInBox.notificationDelegate = nil;
	
    [super viewWillDisappear:animated];
    [actWindow.view removeFromSuperview];
}

- (void)keyboardDidShow:(NSNotification *)notification {
    // adjust view due to keyboard
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        CGFloat keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size.height;
        CGFloat offset = self.tableView.contentSize.height+InstanceMessage.frame.size.height+keyboardSize-self.view.frame.size.height;
        if(offset>0)
        {
            [self.tableView setContentOffset:CGPointMake(0.0, offset) animated:YES];
        }
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    
}

- (void)inputModeDidChange:(NSNotification *)notification {
	// Allows us to block dictation
	UITextInputMode *inputMode = [UITextInputMode currentInputMode];
	NSString *modeIdentifier = [inputMode respondsToSelector:@selector(identifier)] ? (NSString *)[inputMode performSelector:@selector(identifier)] : nil;
	
	if([modeIdentifier isEqualToString:@"dictation"]) {
		[UIView setAnimationsEnabled:NO];
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:UIKeyboardDidShowNotification
													  object:nil];
		
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:UIKeyboardWillHideNotification
													  object:nil];
		
		// hide the keyboard and show again to cancel dictation
		[InstanceMessage resignFirstResponder];
		[InstanceMessage becomeFirstResponder];
		
		[UIView setAnimationsEnabled:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardDidShow:)
													 name:UIKeyboardDidShowNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardWillHide:)
													 name:UIKeyboardWillHideNotification
												   object:nil];
		
		UIAlertView *denyAlert = [[UIAlertView alloc] initWithTitle:nil
															message:NSLocalizedString(@"label_SpeechRecognitionAlert", nil)
														   delegate:nil
												  cancelButtonTitle:NSLocalizedString(@"btn_OK", nil)
												  otherButtonTitles:nil];
		[denyAlert show];
	}
}

- (void)sendSecureText:(NSString *)msgbody {
    if([msgbody length]==0)
    {
        // empty message
        [[[[iToast makeText: NSLocalizedString(@"error_selectDataToSend", @"You need an attachment or a text message to send.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return;
    }
    
    
    NSData* packnonce = nil;
    NSMutableData* pktdata = nil;
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTMSG]];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [InstanceBtn setEnabled:NO];
            [InstanceMessage setEnabled:NO];
            [actWindow DisplayMessage: NSLocalizedString(@"prog_encrypting", @"encrypting...") Detail:nil];
            [self.navigationController.view addSubview: actWindow.view];
        });
    });
    
    pktdata = [[NSMutableData alloc]initWithCapacity:0];
    
    [delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"pid"];
    
    NSString* username = [delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"pid"];
    NSArray* namearray = [[username substringFromIndex:[username rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
    username = [NSString compositeName:[namearray objectAtIndex:1] withLastName:[namearray objectAtIndex:0]];
    
    packnonce = [SSEngine BuildCipher:assignedEntry.keyid Message:msgbody Attach:nil RawFile:nil MIMETYPE:nil Cipher:pktdata];
    
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [actWindow DisplayMessage: NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...") Detail:nil];
            [self.navigationController.view addSubview: actWindow.view];
        });
    });
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if(error)
         {
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             if(error.code==NSURLErrorTimedOut)
             {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [actWindow.view removeFromSuperview];
                     [[[[iToast makeText: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")]
                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                     [InstanceBtn setEnabled:YES];
                     [InstanceMessage setEnabled:YES];
                     InstanceMessage.text = nil;
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [actWindow.view removeFromSuperview];
                     [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]]
                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                     [InstanceBtn setEnabled:YES];
                     [InstanceMessage setEnabled:YES];
                     InstanceMessage.text = nil;
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
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self SaveText:packnonce];
                     });
                 }else if(ntohl(*(int *)msgchar) == 0)
                 {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [actWindow.view removeFromSuperview];
                         [[[[iToast makeText: error_msg]
                            setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                         [InstanceBtn setEnabled:YES];
                         [InstanceMessage setEnabled:YES];
                         InstanceMessage.text = nil;
                     });
                 }
             }
         }
     }];
}

- (void)SaveText:(NSData *)msgid {
    ContactEntry *recipient = [[ContactEntry alloc]init];
    // assign necessary information
    recipient.keyId = assignedEntry.keyid;
    
    NSString* name = [delegate.DbInstance QueryStringInTokenTableByKeyID:assignedEntry.keyid Field:@"pid"];
    NSArray* namearray = [[name substringFromIndex:[name rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
    if([[namearray objectAtIndex:1]length]>0) recipient.firstName = [namearray objectAtIndex:1];
    if([[namearray objectAtIndex:0]length]>0) recipient.lastName = [namearray objectAtIndex:0];
    
    recipient.pushToken = [delegate.DbInstance QueryStringInTokenTableByKeyID:assignedEntry.keyid Field:@"ptoken"];
    
    MsgEntry *NewMsg = [[MsgEntry alloc]
                        InitOutgoingMsg:msgid
                        Recipient:recipient
                        Message:InstanceMessage.text
                        FileName:nil
                        FileType:nil
                        FileData:nil];
    NSString* ret = nil;
    
    if([delegate.DbInstance InsertMessage: NewMsg])
    {
        ret = NSLocalizedString(@"state_FileSent", @"Message sent.");
    }else{
        ret = NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.");
    }
    
    // reload the view
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [actWindow.view removeFromSuperview];
        [[[[iToast makeText: ret]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [self ReloadTable];
        [InstanceBtn setEnabled:YES];
        [InstanceMessage setEnabled:YES];
        InstanceMessage.text = nil;
    });
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    assignedEntry.messagecount = [delegate.DbInstance ThreadMessageCount: assignedEntry.keyid];
    assignedEntry.ciphercount = [delegate.UDbInstance ThreadCipherCount: assignedEntry.keyid];
    
    NSString* displayName = nil;
    if([assignedEntry.keyid isEqualToString:@"UNDEFINED"])
        displayName = NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown");
    else{
        NSString* name = [delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"pid"];
        if(name)
            displayName = [NSString humanreadable: name];
        else
            displayName = assignedEntry.keyid;
    }
    
    if(assignedEntry.ciphercount==0)
        self.navigationItem.title = [NSString stringWithFormat:@"%@ %d", displayName, assignedEntry.messagecount];
    else
        self.navigationItem.title = [NSString stringWithFormat:@"%@ %d (%d)", displayName, assignedEntry.ciphercount+assignedEntry.messagecount, assignedEntry.ciphercount];
    
    return [messages count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if([messages count]==0)
        return NSLocalizedString(@"label_InstNoMessages", @"No messages. You may send a message from tapping the 'Compose Message' Button in Home Menu.");
    else
        return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat totalheight = 0.0f;
    MsgEntry* msg = [messages objectAtIndex:indexPath.row];
    if(msg.smsg)
    {
        totalheight = 60.0f;
    }else{
        totalheight += 62.0f;
        if([msg.msgbody length]>0)
        {
            totalheight += [[NSString stringWithUTF8String: [msg.msgbody bytes]]
                            sizeWithFont:[UIFont systemFontOfSize:12] constrainedToSize:CGSizeMake(300, CGFLOAT_MAX)].height;
        }
        if(msg.attach) totalheight += 56.0f;
    }
    return totalheight;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        MsgEntry* entry = [messages objectAtIndex:indexPath.row];
        BOOL result = NO;
        
        switch (entry.smsg) {
            case Encrypted:
                result = [delegate.UDbInstance DeleteMessage: entry.msgid];
                break;
            case Decrypted:
                result = [delegate.DbInstance DeleteMessage: entry.msgid];
                break;
            default:
                break;
        }
        
        if(result) {
            [messages removeObjectAtIndex:indexPath.row];
            [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_MessagesDeleted", @"%d messages deleted."), 1]]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [self.tableView reloadData];
        } else {
            [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateMessageInDB", @"Unable to update the message database.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
    }
}

#pragma mark - Table view delegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"MessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // multiple line mode
    cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    
    cell.imageView.image = nil;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    cell.textLabel.text = nil;
    
    if([assignedEntry.keyid isEqualToString:@"UNDEFINED"])
    {
        MsgEntry* msg = [messages objectAtIndex:indexPath.row];
        [cell.imageView setImage:b_img];
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.text = NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.");
        cell.detailTextLabel.text = [NSString GetTimeLabelString: msg.cTime];
        
    }else{
        
        MsgEntry* msg = [messages objectAtIndex:indexPath.row];
        
        if(msg.smsg==Encrypted)
        {
            // encrypted message
            cell.textLabel.textColor = [UIColor blueColor];
            cell.textLabel.text = NSLocalizedString(@"label_TapToDecryptMessage", @"Tap to decrypt");
            
        }else{
            
            NSMutableString* msgText = [NSMutableString stringWithCapacity:0];
            // plaintext message
            cell.detailTextLabel.textColor = [UIColor grayColor];
            
            // new thread, show picture
            if(msg.dir==ToMsg){
                // To message
                UIImageView *imageView = nil;
                if([delegate.IdentityImage length]>0)
                    imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithData: delegate.IdentityImage]];
                else
                    imageView = [[UIImageView alloc] initWithImage:b_img];
                cell.accessoryView = imageView;
            }else{
                // From message
                if(thread_img)
                    [cell.imageView setImage:thread_img];
                else
                    [cell.imageView setImage:b_img];
            }
            
            // Display Time
            [msgText appendString:[NSString GetTimeLabelString: msg.cTime]];
            cell.detailTextLabel.text = msgText;
            
            // set as empty string
            [msgText setString:@""];
            NSString* textbody = nil;
            if([msg.msgbody length]>0)
                textbody = [[NSString alloc] initWithData:msg.msgbody encoding:NSUTF8StringEncoding];
            if(textbody)
                [msgText appendString:textbody];
            
            cell.textLabel.textColor = [UIColor blackColor];
            
            if(msg.attach){
                if(msg.sfile) {
                    
                    FileInfo *fio = [delegate.DbInstance GetFileInfo:msg.msgid];
                    // display file date
                    NSString* tm = [NSString GetFileDateLabelString: msg.cTime];
                    
                    if(!tm)
                    {
                        // negative, expired
                        cell.textLabel.textColor = [UIColor redColor];
                        [msgText appendFormat:@"\n%@", NSLocalizedString(@"label_expired", @"expired")];
                    }else{
                        [msgText appendFormat: @"\n%@:\n%@ (%@)", NSLocalizedString(@"label_TapToDownloadFile", @"Tap to download file"), fio.FName, [NSString CalculateMemorySize:fio.FSize]];
                        [msgText appendString:tm];
                    }
                    
                }else {
                    [msgText appendFormat: @"\n%@:\n%@", NSLocalizedString(@"label_TapToOpenFile", @"Tap to open file"), msg.fname];
                }
            }
            cell.textLabel.text = msgText;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if([assignedEntry.keyid isEqualToString:@"UNDEFINED"])
        return;
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: indexPath];
    MsgEntry* entry = [messages objectAtIndex:indexPath.row];
    
    if(entry.smsg == Encrypted)
    {
        if([self.tableView cellForRowAtIndexPath:indexPath].tag!=-1&&[OperationLock tryLock])
        {
            cell.detailTextLabel.text = NSLocalizedString(@"prog_decrypting", @"decrypting...");
            dispatch_async(BackGroundQueue, ^(void) {
                [self DecryptMessage: entry WithIndex: indexPath];
            });
        }
    }
    else if(entry.attach&&(entry.sfile==Encrypted))
    {
        if([self.tableView cellForRowAtIndexPath:indexPath].tag!=-1)
        {
            // check expired time again
            NSString* tm = [NSString GetFileDateLabelString:entry.cTime];
            if(tm&&[OperationLock tryLock])
            {
                // not expired
                [self DownloadFile:entry.msgid WithIndex: indexPath];
                cell.detailTextLabel.text = NSLocalizedString(@"prog_RequestingFile", @"requesting encrypted file...");
            }
        }
    }else if(entry.attach&&(!entry.sfile))
    {
        FileInfo *fio = [delegate.DbInstance GetFileInfo: entry.msgid];
        if([fio.FExt isEqualToString:@"SafeSlinger/SecureIntroduce"])
        {
            // secure introduce capability
            self.tRecord = [VCardParser vCardToContact: [NSString stringWithCString:[[delegate.DbInstance QueryInMsgTableByMsgID:entry.msgid Field:@"fbody"]bytes] encoding:NSUTF8StringEncoding]];
            [self performSegueWithIdentifier:@"ShowInvitation" sender:self];
            
        }else {
            
            // general data, open by preview
            NSData* attchData = [delegate.DbInstance QueryInMsgTableByMsgID:entry.msgid Field:@"fbody"];
            BOOL success;
            NSString* tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:fio.FName];
            if([[NSFileManager defaultManager] fileExistsAtPath: tmpfile])
            {
                success = [attchData writeToFile: tmpfile atomically:YES];
            }else {
                success = [[NSFileManager defaultManager] createFileAtPath: tmpfile contents:attchData attributes:nil];
            }
            
            // start preview
            if(success&&![[self.navigationController topViewController]isEqual:_previewer])
            {
                DEBUGMSG(@"start preview.");
                _preview_cache_page = [NSURL fileURLWithPath: tmpfile];
                [_previewer reloadData];
                [self.navigationController pushViewController: _previewer animated:YES];
            }
        }
    }
}

- (void)DownloadFile: (NSData*)nonce WithIndex:(NSIndexPath*)index {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:index];
    cell.tag = -1;
    
    // save msg nonce
    NSMutableData *pktdata = [[NSMutableData alloc] init];
    //E1: Version (4bytes)
    int version = htonl([delegate getVersionNumberByInt]);
    [pktdata appendBytes: &version length: 4];
    //E2: ID_length (4bytes)
    int len = htonl([nonce length]);
    [pktdata appendBytes: &len length: 4];
    //E3: ID (random nonce), length = FILEID_LEN
    [pktdata appendData:nonce];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETFILE]];
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
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
                     cell.tag = 0;
                     cell.detailTextLabel.text = nil;
                     [ErrorLogger ERRORDEBUG:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                     [[[[iToast makeText: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")]
                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                     [OperationLock unlock];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     cell.tag = 0;
                     cell.detailTextLabel.text = nil;
                     [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]]
                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                     [OperationLock unlock];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // get attachment
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Response Code: %d", ntohl(*(int *)(msgchar+4)));
                 int msglen = ntohl(*(int *)(msgchar+8));
                 DEBUGMSG(@"Received Packet Size: %d", msglen);
                 if(msglen<=0)
                 {
                     [ErrorLogger ERRORDEBUG:@"message length is less than 0"];
                     // display error
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         cell.tag = 0;
                         cell.detailTextLabel.text = nil;
                         [ErrorLogger ERRORDEBUG:NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
                         [[[[iToast makeText: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")]
                            setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                         [OperationLock unlock];
                     });
                     
                 }else{
                     NSData* encryptedfile = [NSData dataWithBytes:(msgchar+12) length:msglen];
                     NSData* filehash = [delegate.DbInstance QueryInMsgTableByMsgID:nonce Field: @"fbody"];
                     NSRange r;r.location = 0;r.length = NONCELEN;
                     filehash = [filehash subdataWithRange:r];
                     
                     // before decrypt we have to check the file hash
                     if(![[sha3 Keccak256Digest:encryptedfile]isEqualToData:filehash])
                     {
                         [ErrorLogger ERRORDEBUG:@"ERROR: Download File Digest Mismatch."];
                         // display error
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             cell.tag = 0;
                             cell.detailTextLabel.text = nil;
                             [ErrorLogger ERRORDEBUG:NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")];
                             [[[[iToast makeText: NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")]
                                setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                             [OperationLock unlock];
                         });
                     }else{
                         // save to database
                         NSString* pubkeySet = [delegate.DbInstance QueryStringInTokenTableByKeyID:[SSEngine ExtractKeyID: encryptedfile] Field:@"pkey"];
                         NSMutableData *cipher = [NSMutableData dataWithCapacity:[encryptedfile length]-LENGTH_KEYID];
                         // remove keyid first
                         [cipher appendBytes:([encryptedfile bytes]+LENGTH_KEYID) length:([encryptedfile length]-LENGTH_KEYID)];
                         // unlock private key
                         int PRIKEY_STORE_SIZE = 0;
                         [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
                         NSData* DecKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
                         NSData* decipher = [SSEngine UnpackMessage: cipher PubKey:pubkeySet Prikey: DecKey];
                         if([decipher length]==0||!decipher)
                         {
                             // display error
                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                 cell.tag = 0;
                                 [ErrorLogger ERRORDEBUG:NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")];
                                 [[[[iToast makeText: NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")]
                                    setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                                 [OperationLock unlock];
                             });
                         }else{
                             [delegate.DbInstance UpdateFileBody:nonce DecryptedData:decipher];
                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                 cell.tag = 0;
                                 [OperationLock unlock];
                                 [self ReloadTable];
                             });
                         }
                     }
                 }
             }
         }
     }];
}

- (void)DecryptMessage: (MsgEntry*)msg WithIndex:(NSIndexPath*)index {
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:index];
    cell.tag = -1;
    BOOL hasfile = NO;
    
    // tap to decrypt
    NSString* pubkeySet = [delegate.DbInstance QueryStringInTokenTableByKeyID:assignedEntry.keyid Field:@"pkey"];
    
    if(pubkeySet==nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[[[iToast makeText: NSLocalizedString(@"error_UnableFindPubKey", @"Unable to match public key to private key in crypto provider.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_UnableFindPubKey", @"Unable to match public key to private key in crypto provider.")];
            [self.tableView cellForRowAtIndexPath:index].tag = 0;
            cell.detailTextLabel.text = nil;
            [OperationLock unlock];
        });
        return;
    }
    
    NSString* username = [NSString humanreadable:[delegate.DbInstance QueryStringInTokenTableByKeyID:assignedEntry.keyid Field:@"pid"]];
    NSString* usertoken = [delegate.DbInstance QueryStringInTokenTableByKeyID:assignedEntry.keyid Field:@"ptoken"];
    
    int PRIKEY_STORE_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
    NSData* DecKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
    
    if(!DecKey)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[[[iToast makeText: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")];
            [self.tableView cellForRowAtIndexPath:index].tag = 0;
            cell.detailTextLabel.text = nil;
            [OperationLock unlock];
        });
        return;
    }
    
    DEBUGMSG(@"cipher size = %lu", (unsigned long)[msg.msgbody length]);
    NSData* decipher = [SSEngine UnpackMessage: msg.msgbody PubKey:pubkeySet Prikey: DecKey];
    
    // parsing
    if([decipher length]==0||!decipher)
    {
        [ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[[[iToast makeText: NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            cell.tag = 0;
            cell.detailTextLabel.text = nil;
            [OperationLock unlock];
        });
        return;
    }
    
    const char * p = [decipher bytes];
    int offset = 0, len = 0;
    unsigned int flen = 0;
    NSString* fname = nil;
    NSString* ftype = nil;
    NSString* peer = nil;
    NSString* text = nil;
    NSString* gmt = nil;
    NSData* filehash = nil;
    
    // parse message format
    DEBUGMSG(@"Version: %02X", ntohl(*(int *)p));
    offset += 4;
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    
    offset = offset+len;
    
    flen = (unsigned int)ntohl(*(int *)(p+offset));
    if(flen>0) hasfile=YES;
    offset += 4;
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        fname = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSUTF8StringEncoding];
        // handle file name
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle file type
        ftype = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSASCIIStringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle text
        text = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSUTF8StringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle Person Name
        peer = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSUTF8StringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle text
        gmt = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSASCIIStringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle text
        filehash = [NSData dataWithBytes:p+offset length:len];
        offset = offset+len;
    }
    
    
    // Chnage content in msg structure
    msg.sender = username;
    msg.token = usertoken;
    msg.smsg = Decrypted;
    msg.msgbody = [text dataUsingEncoding:NSUTF8StringEncoding];
    msg.rTime = gmt;
    
    if(hasfile)
    {
        msg.attach = msg.sfile = Encrypted;
        NSMutableData *finfo = [NSMutableData data];
        [finfo appendData:filehash];
        [finfo appendBytes:&flen length:sizeof(flen)];
        msg.fname =fname;
        msg.fbody = finfo;
        msg.fext = ftype;
    }
    
    // Move message from Universal Database to Individual Database
    [delegate.DbInstance InsertMessage: msg];
    [delegate.UDbInstance DeleteMessage: msg.msgid];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [OperationLock unlock];
        [self.tableView cellForRowAtIndexPath:index].tag = 0;
        [self ReloadTable];
    });
}

- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
	return _preview_cache_page;
}

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller {
	return 1;
}

- (IBAction)sendshortmsg:(id)sender {
    [InstanceMessage resignFirstResponder];
    [self sendSecureText:[InstanceMessage text]];
}

#pragma UITextFieldDelegate Methods
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.navigationItem.leftBarButtonItem = CancelBtn;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.navigationItem.leftBarButtonItem = BackBtn;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue identifier]isEqualToString:@"ShowInvitation"])
    {
        InvitationView *view = (InvitationView*)[segue destinationViewController];
        view.InviterFaceImg = thread_img;
        view.InviterName = [NSString humanreadable: [delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"pid"]];
        view.InviteeVCard = _tRecord;
    }
}

#pragma mark - MessageReceiverNotificationDelegate methods

- (void)messageReceived {
	NSUInteger count = messages.count;
	[self ReloadTable];
	
	if(messages.count > count) {
		// new message was in this conversation
		AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
	} else {
		AudioServicesPlaySystemSound(1003);
	}
}


@end
