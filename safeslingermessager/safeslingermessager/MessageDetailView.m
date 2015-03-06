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

#import <MobileCoreServices/UTType.h>
#import <AssetsLibrary/AssetsLibrary.h>
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

typedef enum {
	AttachmentStatusEmpty,
	AttachmentStatusAudio,
	AttachmentStatusImage
} AttachmentStatus;

typedef enum {
	AttachmentTypePhotoLibrary = 0,
	AttachmentTypePhotosAlbum = 1,
	AttachmentTypeCamera = 2,
	AttachmentTypeSoundRecoder = 3,
	AttachmentTypeClear = 4
} AttachmentType;

@interface MessageDetailView ()

@property (strong, nonatomic) ContactEntry *recipient;
@property (strong, nonatomic) NSMutableDictionary *pendingMessages;
@property (strong, nonatomic) NSIndexPath *longPressedIndexPath;

@property (strong, nonatomic) NSURL *attachedFile;
@property (strong, nonatomic) NSData *attachedFileRawData;
@property AttachmentStatus attachmentStatus;
@end

@implementation MessageDetailView

@synthesize delegate, b_img, thread_img, assignedEntry, OperationLock, InstanceMessage, CancelBtn, BackBtn, InstanceBox;

- (void)viewDidLoad {
    [super viewDidLoad];
	
	_attachmentStatus = AttachmentStatusEmpty;
	[self updateAttachmentStatus];
    
    delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    BackGroundQueue = dispatch_queue_create("safeslinger.background.queue", NULL);
    b_img = [UIImage imageNamed: @"blank_contact_small.png"];
	
    OperationLock = [NSLock new];
	
    _previewer = [QLPreviewController new];
    [_previewer setDataSource:self];
    [_previewer setDelegate:self];
    [_previewer setCurrentPreviewItemIndex:0];
	
	_recipient = [delegate.DbInstance loadContactEntryWithKeyId:assignedEntry.keyid];
	_pendingMessages = [NSMutableDictionary new];
	
    //for unknown thread
    if(_recipient == nil || (_recipient.firstName == nil && _recipient.lastName == nil)) {
        DEBUGMSG(@"UNDEFINED thread...");
        [InstanceBox setHidden:YES];
    } else {
        [InstanceBox setHidden:NO];
    }
	
	thread_img = [_recipient.photo length] > 0 ? [[UIImage imageWithData:_recipient.photo] scaleToSize:CGSizeMake(45.0f, 45.0f)] : nil;
    
    BackBtn = self.navigationItem.backBarButtonItem;
    CancelBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(DismissKeyboard)];
	
	// hides textfield if this contact is not active
	if(assignedEntry.active) {
        InstanceMessage.autocapitalizationType = UITextAutocapitalizationTypeSentences;
		[InstanceMessage setPlaceholder:NSLocalizedString(@"label_ComposeHint", @"Compose Message")];
//		[_sendButton setTitle: NSLocalizedString(@"title_SendFile", @"Send") forState: UIControlStateNormal];
	} else {
		[self.tableView.tableFooterView removeFromSuperview];
		self.tableView.tableFooterView = nil;
	}
	
	UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
	gestureRecognizer.delegate = self;
	[self.tableView addGestureRecognizer:gestureRecognizer];
}

- (void)updateTitle {
	NSString* displayName = nil;
	if(_recipient == nil || (_recipient.firstName == nil && _recipient.lastName == nil)) {
		displayName = NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown");
	} else {
		displayName = [NSString compositeName:_recipient.firstName withLastName:_recipient.lastName];
	}
	
	if(assignedEntry.ciphercount == 0) {
		self.navigationItem.title = [NSString stringWithFormat:@"%@ %d", displayName, assignedEntry.messagecount];
	} else {
		self.navigationItem.title = [NSString stringWithFormat:@"%@ %d (%d)", displayName, assignedEntry.ciphercount+assignedEntry.messagecount, assignedEntry.ciphercount];
	}
}

- (void)updateAttachmentStatus {
	switch (_attachmentStatus) {
		case AttachmentStatusEmpty:
			[_attachmentButton setImage:[UIImage imageNamed:@"attachment_add"] forState:UIControlStateNormal];
			[_sendButton setImage:[UIImage imageNamed:@"send"] forState:UIControlStateNormal];
			break;
			
		case AttachmentStatusAudio:
			[_attachmentButton setImage:[UIImage imageNamed:@"attachment_audio"] forState:UIControlStateNormal];
			[_sendButton setImage:[UIImage imageNamed:@"send_attachment"] forState:UIControlStateNormal];
			break;
			
		case AttachmentStatusImage:
			[_attachmentButton setImage:[UIImage imageNamed:@"attachment_image"] forState:UIControlStateNormal];
			[_sendButton setImage:[UIImage imageNamed:@"send_attachment"] forState:UIControlStateNormal];
			break;
	}
}

- (void)DismissKeyboard {
    [InstanceMessage resignFirstResponder];
}

- (void)scrollToBottom {
	if(self.tableView.contentSize.height > self.tableView.frame.size.height) {
		CGPoint offset = CGPointMake(0, self.tableView.contentSize.height - self.tableView.frame.size.height);
		[self.tableView setContentOffset:offset animated:NO];
	}
}

- (void)reloadTable {
	[self.messages removeAllObjects];
    [self.messages setArray:[delegate.DbInstance loadMessagesExchangedWithKeyId:assignedEntry.keyid]];
	
	NSArray *cipherMessages = [delegate.UDbInstance LoadThreadMessage:assignedEntry.keyid];
    [self.messages addObjectsFromArray:cipherMessages];
	assignedEntry.ciphercount = (int)cipherMessages.count;
	
	MsgEntry *outgoingMessage = delegate.messageSender.outgoingMessage;
	if([outgoingMessage.keyid isEqualToString:assignedEntry.keyid]) {
		[self.messages addObject:outgoingMessage];
	}
	
	assignedEntry.messagecount = (int)self.messages.count;
	
    [self.tableView reloadData];
	
	[self scrollToBottom];
}

- (void)viewDidUnload {
    [super viewDidLoad];
    [self.messages removeAllObjects];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
	
	delegate.MessageInBox.notificationDelegate = self;
    
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
	
	[self reloadTable];
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
}

- (void)keyboardDidShow:(NSNotification *)notification {
    // adjust view due to keyboard
    if(floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        CGFloat keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size.height;
        CGFloat offset = self.tableView.contentSize.height + InstanceBox.frame.size.height + keyboardSize - self.view.frame.size.height;
        if(offset>0) {
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

- (NSMutableArray *)messages {
	if(!_messages) {
		_messages = [NSMutableArray new];
	}
	return _messages;
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    assignedEntry.messagecount = [delegate.DbInstance ThreadMessageCount:assignedEntry.keyid];
    assignedEntry.ciphercount = [delegate.UDbInstance ThreadCipherCount:assignedEntry.keyid];
	
	[self updateTitle];
	
    return [self.messages count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if([self.messages count]==0)
        return NSLocalizedString(@"label_InstNoMessages", @"No messages. You may send a message from tapping the 'Compose Message' Button in Home Menu.");
    else
        return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat totalheight = 0.0f;
    MsgEntry* msg = [self.messages objectAtIndex:indexPath.row];
    if(msg.smsg) {
        totalheight = 60.0f;
    } else {
        totalheight += 62.0f;
		
        if([msg.msgbody length] > 0) {
            totalheight += [[NSString stringWithUTF8String: [msg.msgbody bytes]]
                            sizeWithFont:[UIFont systemFontOfSize:12] constrainedToSize:CGSizeMake(300, CGFLOAT_MAX)].height;
        }
		
		if(msg.attach) {
			totalheight += 56.0f;
		}
    }
    return totalheight;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        MsgEntry* entry = [self.messages objectAtIndex:indexPath.row];
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
            [self.messages removeObjectAtIndex:indexPath.row];
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    cell.imageView.image = nil;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    cell.textLabel.text = nil;
    
    if([assignedEntry.keyid isEqualToString:@"UNDEFINED"]) {
        MsgEntry* msg = [self.messages objectAtIndex:indexPath.row];
        [cell.imageView setImage:b_img];
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.text = NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.");
        cell.detailTextLabel.text = [NSString GetTimeLabelString: msg.cTime];
    } else {
        MsgEntry* msg = [self.messages objectAtIndex:indexPath.row];
        
        if(msg.smsg==Encrypted) {
            // encrypted message
            cell.textLabel.textColor = [UIColor blueColor];
            cell.textLabel.text = NSLocalizedString(@"label_TapToDecryptMessage", @"Tap to decrypt");
        } else {
			cell.textLabel.textColor = [UIColor blackColor];
			
            // new thread, show picture
            if(msg.dir == ToMsg){
                // To message
                UIImageView *imageView = nil;
				if([delegate.IdentityImage length] > 0) {
                    imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithData: delegate.IdentityImage]];
				} else {
                    imageView = [[UIImageView alloc] initWithImage:b_img];
				}
                cell.accessoryView = imageView;
				
				switch (msg.outgoingStatus) {
					case MessageOutgoingStatusSending:
						cell.detailTextLabel.text = NSLocalizedString(@"prog_FileSent", nil);
						break;
						
					case MessageOutgoingStatusFailed:
						cell.textLabel.textColor = [UIColor redColor];
						cell.detailTextLabel.text = NSLocalizedString(@"state_FailedToSendMessage", nil);
						break;
						
					default:
						cell.detailTextLabel.text = [NSString GetTimeLabelString:msg.cTime];
						break;
				}
            } else {
                // From message
				if(thread_img) {
                    [cell.imageView setImage:thread_img];
				} else {
                    [cell.imageView setImage:b_img];
				}
				
				cell.detailTextLabel.text = [NSString GetTimeLabelString:msg.cTime];
            }
			
			// set as empty string
			NSMutableString* msgText = [NSMutableString stringWithCapacity:0];
            NSString* textbody = nil;
			if([msg.msgbody length]>0) {
                textbody = [[NSString alloc] initWithData:msg.msgbody encoding:NSUTF8StringEncoding];
			}
			
			if(textbody) {
                [msgText appendString:textbody];
			}
            
            if(msg.attach){
                if(msg.sfile) {
                    FileInfo *fio = [delegate.DbInstance GetFileInfo:msg.msgid];
                    // display file date
                    NSString* tm = [NSString GetFileDateLabelString: msg.cTime];
                    
					if(!tm) {
                        // negative, expired
                        cell.textLabel.textColor = [UIColor redColor];
                        [msgText appendFormat:@"\n%@", NSLocalizedString(@"label_expired", @"expired")];
                    } else {
                        [msgText appendFormat: @"\n%@:\n%@ (%@)", NSLocalizedString(@"label_TapToDownloadFile", @"Tap to download file"), fio.FName, [NSString CalculateMemorySize:fio.FSize]];
                        [msgText appendString:tm];
                    }
                } else {
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
    MsgEntry* entry = [self.messages objectAtIndex:indexPath.row];
    
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

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
	CGPoint point = [gestureRecognizer locationInView:self.tableView];
	_longPressedIndexPath = [self.tableView indexPathForRowAtPoint:point];
	if(_longPressedIndexPath && gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		MsgEntry *message = self.messages[_longPressedIndexPath.row];
		if(message.dir == ToMsg && message.outgoingStatus == MessageOutgoingStatusFailed) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_MessageOptions", nil)
										message:nil
									   delegate:self
							  cancelButtonTitle:NSLocalizedString(@"btn_Cancel", nil)
							  otherButtonTitles:NSLocalizedString(@"btn_Retry", nil), NSLocalizedString(@"btn_Delete", nil) , nil] show];
		}
	}
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex != alertView.cancelButtonIndex) {
		MsgEntry *message = self.messages[_longPressedIndexPath.row];
		
		// remove message from array and from database
		[self.messages removeObjectAtIndex:_longPressedIndexPath.row];
		[delegate.DbInstance DeleteMessage:message.msgid];
		
		
		if(buttonIndex == 1) {
			// retry
			
			[CATransaction begin];
			[CATransaction setCompletionBlock:^{
				// animation has finished
				[self.tableView scrollRectToVisible:InstanceBox.frame animated:YES];
			}];
			
			[self.tableView beginUpdates];
			[self.tableView deleteRowsAtIndexPaths:@[_longPressedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
			
			[self sendTextMessage:[[NSString alloc] initWithData:message.msgbody encoding:NSUTF8StringEncoding] tableViewUpdateStarted:YES];
		} else {
			// remove message from tableview
			[self.tableView beginUpdates];
			[self.tableView deleteRowsAtIndexPaths:@[_longPressedIndexPath] withRowAnimation:UITableViewRowAnimationTop];
			[self.tableView endUpdates];
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
                                 [self reloadTable];
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
        DEBUGMSG(@"gmt: %@", gmt);
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
        [self reloadTable];
    });
}

- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
	return _preview_cache_page;
}

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller {
	return 1;
}

- (IBAction)sendshortmsg:(id)sender {
	if((InstanceMessage.text == nil || InstanceMessage.text.length == 0) && !_attachedFile) {
		return;
	}
	
	[self sendTextMessage:InstanceMessage.text tableViewUpdateStarted:NO];
}

- (void)sendTextMessage:(NSString *)text tableViewUpdateStarted:(BOOL)updateStarted {
	NSMutableData *pktdata = [NSMutableData new];
	
	// get file type in MIME format
	CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(__bridge CFStringRef)[[_attachedFile lastPathComponent] pathExtension], NULL);
	NSString* mimeType = (__bridge NSString*)UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
	
	NSData *messageId = [SSEngine BuildCipher:_recipient.keyId Message:[text dataUsingEncoding:NSUTF8StringEncoding] Attach:[_attachedFile lastPathComponent]	RawFile:_attachedFileRawData MIMETYPE:mimeType Cipher:pktdata];
	
	MsgEntry *newMessage = [[MsgEntry alloc]
							InitOutgoingMsg:messageId
							Recipient:_recipient
							Message:text
							FileName:[_attachedFile lastPathComponent]
							FileType:mimeType
							FileData:_attachedFileRawData];
	newMessage.outgoingStatus = MessageOutgoingStatusSending;
	
	InstanceMessage.text = @"";
	
	[self.messages addObject:newMessage];
	
	if(!updateStarted) {
		[CATransaction begin];
		[CATransaction setCompletionBlock:^{
			// animation has finished
			[self.tableView scrollRectToVisible:InstanceBox.frame animated:YES];
		}];
		
		[self.tableView beginUpdates];
	}
	
	[self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0]] withRowAnimation:UITableViewRowAnimationBottom];
	[self.tableView endUpdates];
	
	[CATransaction commit];
	
	
	delegate.messageSender.delegate = self;
	[delegate.messageSender sendMessage:newMessage packetData:pktdata];
	
	_attachedFile = nil;
	_attachedFileRawData = nil;
	_attachmentStatus = AttachmentStatusEmpty;
	[self updateAttachmentStatus];
}

- (BOOL)CheckPhotoPermission {
	BOOL ret = NO;
	ALAuthorizationStatus authStatus = [ALAssetsLibrary authorizationStatus];
	if(authStatus == ALAuthorizationStatusNotDetermined) {
		ret = YES; // wait to trigger it
	} else if(authStatus == ALAuthorizationStatusRestricted || authStatus == ALAuthorizationStatusDenied) {
		// show indicator
		NSString* buttontitle = nil;
		NSString* description = nil;
		
		if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
			buttontitle = NSLocalizedString(@"menu_Help", nil);
			description = [NSString stringWithFormat: NSLocalizedString(@"iOS_photolibraryError", nil), buttontitle];
		} else {
			buttontitle = NSLocalizedString(@"menu_Settings", nil);
			description = [NSString stringWithFormat: NSLocalizedString(@"iOS_photolibraryError", nil), buttontitle];
		}
		
		UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", nil)
														  message: description
														 delegate: self
												cancelButtonTitle: NSLocalizedString(@"btn_Cancel", nil)
												otherButtonTitles: buttontitle, nil];
		message.tag = HelpPhotoLibrary;
		[message show];
		message = nil;
	} else if(authStatus == ALAuthorizationStatusAuthorized){
		ret = YES;
	}
	return ret;
}

- (BOOL)CheckCameraPermission {
	AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
	if (!captureInput) {
		// show indicator
		NSString* buttontitle = nil;
		NSString* description = nil;
		
		if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
			buttontitle = NSLocalizedString(@"menu_Help", nil);
			description = [NSString stringWithFormat: NSLocalizedString(@"iOS_cameraError", nil), buttontitle];
		} else {
			buttontitle = NSLocalizedString(@"menu_Settings", nil);
			description = [NSString stringWithFormat: NSLocalizedString(@"iOS_cameraError", nil), buttontitle];
		}
		
		UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", nil)
														  message: description
														 delegate: self
												cancelButtonTitle: NSLocalizedString(@"btn_Cancel", nil)
												otherButtonTitles: buttontitle, nil];
		message.tag = HelpCamera;
		[message show];
		message = nil;
		return NO;
	} else {
		return YES;
	}
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue identifier]isEqualToString:@"ShowInvitation"]) {
        InvitationView *view = (InvitationView*)[segue destinationViewController];
        view.InviterFaceImg = thread_img;
        view.InviterName = [NSString humanreadable: [delegate.DbInstance QueryStringInTokenTableByKeyID: assignedEntry.keyid Field:@"pid"]];
        view.InviteeVCard = _tRecord;
	} else if([segue.identifier isEqualToString:@"AudioRecordSegue"]) {
		AudioRecordView *destination = (AudioRecordView *)segue.destinationViewController;
		destination.delegate = self;
	}
}

#pragma mark - MessageReceiverNotificationDelegate methods

- (void)messageReceived {
	NSUInteger count = self.messages.count;
	[self reloadTable];
	
	if(self.messages.count > count) {
		// new message was in this conversation
		[UtilityFunc playVibrationAlert];
	} else {
		[UtilityFunc playSoundAlert];
	}
}

#pragma mark - MessageSenderDelegate methods

- (void)updatedOutgoingStatusForMessage:(MsgEntry *)message {
	int i = (int)self.messages.count - 1;
	BOOL found = NO;
	
	while(i >= 0 && !found) {
		MsgEntry *entry = self.messages[i];
		if([entry.msgid isEqualToData:message.msgid]) {
			[self.messages removeObjectAtIndex:i];
			[self.messages insertObject:message atIndex:i];
			[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
			found = YES;
		}
	}
	
	if(!found) {
		[self.messages addObject:message];
		
		[self reloadTable];
	}
}

#pragma mark - AudioRecordDelegate methods

- (void)recordedAudioInURL:(NSURL *)audioURL {
	NSData *rawData = [NSData dataWithContentsOfURL:audioURL];
	
	if([rawData length] == 0) {
		[[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
	} else if([_attachedFileRawData length] > 9437184) {
		NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", @"Cannot send attachments greater than %d bytes in size."), 9437184];
		[[[[iToast makeText: msg]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
	} else {
		_attachedFile = audioURL;
		_attachedFileRawData = rawData;
		_attachmentStatus = AttachmentStatusAudio;
		[self updateAttachmentStatus];
	}
}

#pragma mark - IBAction methods

- (IBAction)selectAttachment:(id)sender {
	UIActionSheet *actionSheet = [[UIActionSheet alloc]
								  initWithTitle: NSLocalizedString(@"title_ChooseFileLoad", @"Choose Your File")
								  delegate: self
								  cancelButtonTitle: nil
								  destructiveButtonTitle: nil
								  otherButtonTitles:
								  NSLocalizedString(@"title_photolibary", @"Photo Library"),
								  NSLocalizedString(@"title_photoalbum", @"Photo Album"),
								  NSLocalizedString(@"title_camera", @"Camera"),
								  NSLocalizedString(@"title_soundrecoder", @"Sound Recorder"),
								  nil];
	
	if(_attachmentStatus != AttachmentStatusEmpty) {
		[actionSheet setDestructiveButtonIndex:[actionSheet addButtonWithTitle:NSLocalizedString(@"title_clear", nil)]]; 
	}
	
	[actionSheet setCancelButtonIndex:[actionSheet addButtonWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")]];
	[actionSheet showInView:[self.navigationController view]];
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == actionSheet.cancelButtonIndex) {
		return;
	}
	
	[self dismissViewControllerAnimated:NO completion:nil];
	
	switch (buttonIndex) {
		case AttachmentTypePhotoLibrary:
			if([self CheckPhotoPermission]) {
				UIImagePickerController *imagePicker = [UIImagePickerController new];
				imagePicker.delegate = self;
				imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
				imagePicker.allowsEditing = YES;
				[self presentViewController:imagePicker animated:YES completion:nil];
			}
			
			break;
			
		case AttachmentTypePhotosAlbum:
			if([self CheckPhotoPermission]) {
				UIImagePickerController *imagePicker = [UIImagePickerController new];
				imagePicker.delegate = self;
				imagePicker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
				imagePicker.allowsEditing = YES;
				[self presentViewController:imagePicker animated:YES completion:nil];
			}
			
			break;
			
		case AttachmentTypeCamera:
			if([self CheckCameraPermission]) {
				UIImagePickerController *imagePicker = [UIImagePickerController new];
				imagePicker.delegate = self;
				imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
				imagePicker.showsCameraControls = YES;
				imagePicker.allowsEditing = YES;
				[self presentViewController:imagePicker animated:YES completion:nil];
			}
			
			break;
			
		case AttachmentTypeSoundRecoder:
			[self performSegueWithIdentifier:@"AudioRecordSegue" sender:self];
			break;
			
		case AttachmentTypeClear:
			_attachedFile = nil;
			_attachedFileRawData = nil;
			_attachmentStatus = AttachmentStatusEmpty;
			[self updateAttachmentStatus];
			break;
			
	}
}

#pragma mark - UIImagePickerControllerDelegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	[self dismissViewControllerAnimated:YES completion:nil];
	
	[info valueForKey:UIImagePickerControllerReferenceURL];
	NSURL *urlstr = [info valueForKey:UIImagePickerControllerReferenceURL];
	NSData *imgdata = UIImageJPEGRepresentation([info valueForKey:UIImagePickerControllerOriginalImage], 1.0);
	
	if(!imgdata.length) {
		[[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		return;
	} else if(imgdata.length > 9437184) {
		NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", "Cannot send attachments greater than %d bytes in size."), 9437184];
		[[[[iToast makeText: msg]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		return;
	}
	
	NSString *filename = nil;
	
	if(!urlstr) {
		DEBUGMSG(@"camera file");
		NSDateFormatter *format = [[NSDateFormatter alloc] init];
		[format setDateFormat:@"yyyyMMdd-HHmmss"];
		NSDate *now = [[NSDate alloc] init];
		NSString *dateString = [format stringFromDate:now];
		filename = [NSString stringWithFormat:@"cam-%@.jpg", dateString];
	} else {
		// has id
		NSRange range, idrange;
		range = [[urlstr absoluteString] rangeOfString:@"id="];
		idrange.location = range.location+range.length;
		range = [[urlstr absoluteString] rangeOfString:@"&ext="];
		idrange.length = range.location - idrange.location;
		filename = [NSString stringWithFormat:@"%@.%@", [[urlstr absoluteString]substringWithRange:idrange], [[urlstr absoluteString]substringFromIndex:range.location+range.length]];
	}
	
//	NSString *sizeinfo = [NSString stringWithFormat:@"%@ (%@).", filename,
//						  [NSString stringWithFormat:NSLocalizedString(@"label_kb",@"%.0f kb"), [imgdata length]/1024.0f]
//						  ];
	
	_attachedFile = [NSURL URLWithString:filename];
	_attachedFileRawData = imgdata;
	_attachmentStatus = AttachmentStatusImage;
	[self updateAttachmentStatus];
}

@end
