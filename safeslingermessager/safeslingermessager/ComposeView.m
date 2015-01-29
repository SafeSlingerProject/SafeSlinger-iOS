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
#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ComposeView.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "ContactEntry.h"
#import "FunctionView.h"
#import "ContactManageView.h"
#import "AudioRecordView.h"
#import "Config.h"

#import <safeslingerexchange/iToast.h>
#import <safeslingerexchange/ActivityWindow.h>

@interface ComposeView ()

@end

@implementation ComposeView

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    
    _messageTextView.layer.borderWidth = 1.0f;
    _messageTextView.layer.borderColor = [[UIColor grayColor] CGColor];
	
	_sendButton.title = NSLocalizedString(@"btn_SendFile", @"Send");
	_cancelButton.title = NSLocalizedString(@"btn_Cancel", @"Cancel");
	
	_logoutButton = self.parentViewController.navigationItem.leftBarButtonItem;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contactEdited:)
												 name:NSNotificationContactEdited
											   object:nil];
	
	[self updateReceiver];
}

- (void)viewWillAppear:(BOOL)animated {
    [_messageTextView resignFirstResponder];
    
    // Change Title and Help Button
    self.parentViewController.navigationItem.title = NSLocalizedString(@"menu_TagComposeMessage", @"Compose");
    self.parentViewController.navigationItem.hidesBackButton = YES;
    self.parentViewController.navigationItem.rightBarButtonItem = _sendButton;
	
    _progressLabel.text = nil;
    [_progressView stopAnimating];
    
    [self updateSelf];
    [self cleanAttachment];
    _messageTextView.text = nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
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
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillAppear:animated];
	
    [_messageTextView resignFirstResponder];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:@"UITextInputCurrentInputModeDidChangeNotification"
												  object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSNotification methods

- (void)contactEdited:(NSNotification *)notification {
	ContactEntry *editedContact = notification.userInfo[NSNotificationContactEditedObject];
	if(editedContact) {
		if([_selectedReceiver.pushToken isEqualToString:editedContact.pushToken]) {
			_selectedReceiver = editedContact;
			[self updateReceiver];
		}
	} else {
		[self updateSelf];
	}
}

- (void)keyboardWasShown:(NSNotification *)notification {
	NSDictionary* info = [notification userInfo];
	CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
	CGSize tabBarSize = self.tabBarController.tabBar.frame.size;
 
	UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height - tabBarSize.height, 0.0);
	_scrollView.contentInset = contentInsets;
	_scrollView.scrollIndicatorInsets = contentInsets;
 
	// If active text field is hidden by keyboard, scroll it so it's visible
	// Your app might not need or want this behavior.
	CGRect rect = self.view.frame;
	rect.size.height -= kbSize.height;
	
	CGPoint scrollPoint = _messageTextView.frame.origin;
	scrollPoint.y += 100;
	
	if (!CGRectContainsPoint(rect, scrollPoint) ) {
		[self.scrollView scrollRectToVisible:_messageTextView.frame animated:YES];
	}
}

- (void)keyboardWillHide:(NSNotification *)notification {
	UIEdgeInsets contentInsets = UIEdgeInsetsZero;
	_scrollView.contentInset = contentInsets;
	_scrollView.scrollIndicatorInsets = contentInsets;
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
		[_messageTextView resignFirstResponder];
		[_messageTextView becomeFirstResponder];
		
		[UIView setAnimationsEnabled:YES];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardWasShown:)
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

- (void)updateReceiver {
    if(_selectedReceiver) {
        NSString* btnStr = [NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString compositeName:_selectedReceiver.firstName withLastName:_selectedReceiver.lastName], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:_selectedReceiver.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]];
        
        [_receiverButton setTitle:btnStr forState:UIControlStateNormal];
        
		if(_selectedReceiver.photo) {
            [_receiverPhoto setImage: [UIImage imageWithData: _selectedReceiver.photo]];
		} else {
            [_receiverPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
		}
    } else {
        // No select user
        [_receiverPhoto setImage:[UIImage imageNamed:@"blank_contact.png"]];
        [_receiverButton setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    }
}

- (void)updateSelf {
	// get name from profile
	NSString* fulln = [_appDelegate.DbInstance GetProfileName];
	if(_appDelegate.IdentityNum == NonLink) {
		[_senderPhoto setImage:[UIImage imageNamed:@"blank_contact.png"]];
	} else if(_appDelegate.IdentityNum > 0) {
		CFErrorRef error = NULL;
		ABAddressBookRef aBook = NULL;
		aBook = ABAddressBookCreateWithOptions(NULL, &error);
		ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
			if (!granted) {
				return;
			}
		});
		
		ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, _appDelegate.IdentityNum);
		// set self photo
		if(ABPersonHasImageData(aRecord)) {
			CFDataRef imgData = ABPersonCopyImageDataWithFormat(aRecord, kABPersonImageFormatThumbnail);
			UIImage *image = [UIImage imageWithData:(__bridge NSData *)imgData];
			[_senderPhoto setImage:image];
			// update cache image
			_appDelegate.IdentityImage = UIImageJPEGRepresentation([image scaleToSize:CGSizeMake(45.0f, 45.0f)], 0.9);
			CFRelease(imgData);
		} else {
			[_senderPhoto setImage:[UIImage imageNamed:@"blank_contact.png"]];
		}
		
		if(aBook) {
			CFRelease(aBook);
		}
	}
	
	NSString* btnStr = [NSString stringWithFormat:@"%@\n%@", [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_SendFrom", @"From:"), fulln], [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]]];
	[_senderButton setTitle:btnStr forState:UIControlStateNormal];
}

- (void)UpdateAttachment {
    if(_attachFile) {
        attachFileRawBytes = [NSData dataWithContentsOfURL:_attachFile];
        if([attachFileRawBytes length]==0) {
            [[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            attachFileRawBytes = nil;
            _attachFile  = nil;
            [_addAttachmentButton setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
        } else if([attachFileRawBytes length]>9437184) {
            NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", @"Cannot send attachments greater than %d bytes in size."), 9437184];
            [[[[iToast makeText: msg]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            attachFileRawBytes = nil;
            _attachFile  = nil;
            [_addAttachmentButton setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
        } else {
            [_addAttachmentButton setTitle:[NSString stringWithFormat:@"%@ (%@)", [_attachFile lastPathComponent], [NSString CalculateMemorySize:(int)[attachFileRawBytes length]]] forState:UIControlStateNormal];
        }
    } else {
        [_addAttachmentButton setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex!=alertView.cancelButtonIndex) {
        NSString *helpurl = nil;
        switch (alertView.tag) {
            case HelpContact:
                helpurl = kContactHelpURL;
                break;
            case HelpPhotoLibrary:
                helpurl = kPhotoHelpURL;
                break;
            case HelpCamera:
                helpurl = kCameraHelpURL;
                break;
            default:
                break;
        }
        
        switch (alertView.tag) {
            case AskPerm:
                [UtilityFunc TriggerContactPermission];
                break;
            case HelpContact:
            case HelpPhotoLibrary:
            case HelpCamera:
                if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:helpurl]];
                } else {
                    // iOS8
                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    [[UIApplication sharedApplication] openURL:url];
                }
                break;	
            default:
                break;
        }
    }
}

- (void)cleanAttachment {
    // clean previous selection if necessary
    [_addAttachmentButton setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
    _attachFile = nil;
    attachFileRawBytes = nil;
}

- (void)sendSecureMessage {
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
			if(_attachFile) {
                _progressLabel.text = [NSString stringWithFormat: NSLocalizedString(@"prog_SendingFile", @"sending encrypted %@..."), [_attachFile lastPathComponent]];
			} else {
                _progressLabel.text = NSLocalizedString(@"prog_encrypting", @"encrypting...");
			}
            [_progressView startAnimating];
        });
    });
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSData* packnonce = nil;
    NSMutableData* pktdata = [[NSMutableData alloc]initWithCapacity:0];
    
    // get file type in MIME format
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(__bridge CFStringRef)[[_attachFile lastPathComponent] pathExtension] ,NULL);
    NSString* MimeType = (__bridge NSString*)UTTypeCopyPreferredTagWithClass(UTI,kUTTagClassMIMEType);
    
    packnonce = [SSEngine BuildCipher:_selectedReceiver.keyId Message:_messageTextView.text Attach:[_attachFile lastPathComponent] RawFile:attachFileRawBytes MIMETYPE:MimeType Cipher:pktdata];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTMSG]];;
    
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            _progressLabel.text = NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...");
            [_progressView startAnimating];
        });
    });
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
         if(error) {
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             
             if(error.code==NSURLErrorTimedOut) {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self PrintErrorOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                 });
             } else {
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self PrintErrorOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                 });
             }
         } else {
             if([data length] > 0) {
                 // start parsing data
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
                 DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                 if(ntohl(*(int *)msgchar) > 0) {
                     // Send Response
                     DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                     DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                     // Save to Database
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self SaveMessage:packnonce];
                     });
                 } else if(ntohl(*(int *)msgchar) == 0) {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     [ErrorLogger ERRORDEBUG:error_msg];
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self PrintErrorOnUI:error_msg];
                     });
                 }
             }
         }
     }];
}

- (void)PrintErrorOnUI:(NSString*)error {
    _progressLabel.text = nil;
    [_progressView stopAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

- (void)SaveMessage:(NSData *)msgid {
    // [_appDelegate.activityView DisableProgress];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // filetype
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(__bridge CFStringRef)[_attachFile pathExtension],NULL);
    NSString *fileType = (__bridge NSString *)UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    if(UTI)CFRelease(UTI);
    
    MsgEntry *NewMsg = [[MsgEntry alloc]
                        InitOutgoingMsg:msgid
                        Recipient:_selectedReceiver
                        Message:_messageTextView.text
                        FileName:[_attachFile lastPathComponent]
                        FileType:fileType
                        FileData:attachFileRawBytes];
    
    if([_appDelegate.DbInstance InsertMessage:NewMsg]) {
        // reload the view
        [[[[iToast makeText: NSLocalizedString(@"state_FileSent", @"Message sent.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [self.tabBarController setSelectedIndex:0];
    } else {
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
}

- (BOOL)CheckPhotoPerm {
    BOOL ret = NO;
    ALAuthorizationStatus authStatus = [ALAssetsLibrary authorizationStatus];
    if(authStatus == ALAuthorizationStatusNotDetermined) {
        ret = YES; // wait to trigger it
    } else if(authStatus == ALAuthorizationStatusRestricted || authStatus == ALAuthorizationStatusDenied) {
        // show indicator
        NSString* buttontitle = nil;
        NSString* description = nil;
        
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
            buttontitle = NSLocalizedString(@"menu_Help", @"Help");
            description = [NSString stringWithFormat: NSLocalizedString(@"iOS_photolibraryError", @"Photo Library permission is required to attach pictures to secure messages. Tap the %@ button for SafeSlinger Photo Library permission details."), buttontitle];
        } else {
            buttontitle = NSLocalizedString(@"menu_Settings", @"menu_Settings");
            description = [NSString stringWithFormat: NSLocalizedString(@"iOS_photolibraryError", @"Photo Library permission is required to attach pictures to secure messages. Tap the %@ button for SafeSlinger Photo Library permission details."), buttontitle];
        }
        
        UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
                                                          message: description
                                                         delegate: self
                                                cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                otherButtonTitles: buttontitle, nil];
        message.tag = HelpPhotoLibrary;
        [message show];
        message = nil;
    } else if(authStatus == ALAuthorizationStatusAuthorized){
        ret = YES;
    }
    return ret;
}

- (BOOL)CheckCameraPerm {
    AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
    if (!captureInput) {
        // show indicator
        NSString* buttontitle = nil;
        NSString* description = nil;
        
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
            buttontitle = NSLocalizedString(@"menu_Help", @"Help");
            description = [NSString stringWithFormat: NSLocalizedString(@"iOS_cameraError", @"Camera permission is required to attach snapshots to secure messages. Tap the %@ button for SafeSlinger Camera permission details."), buttontitle];
        } else {
            buttontitle = NSLocalizedString(@"menu_Settings", @"menu_Settings");
            description = [NSString stringWithFormat: NSLocalizedString(@"iOS_cameraError", @"Camera permission is required to attach snapshots to secure messages. Tap the %@ button for SafeSlinger Camera permission details."), buttontitle];
        }
        
        UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
                                                          message: description
                                                         delegate: self
                                                cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                otherButtonTitles: buttontitle, nil];
        message.tag = HelpCamera;
        [message show];
        message = nil;
        return NO;
    } else {
        return YES;
    }
}

#pragma mark - IBAction methods

- (IBAction)dismissKeyboard {
	[_messageTextView resignFirstResponder];
}

- (IBAction)sendMessage {
	[_messageTextView resignFirstResponder];
	if([[_receiverButton titleLabel].text isEqualToString: NSLocalizedString(@"label_SelectRecip", @"Select Recipient")]) {
		// no user selected
		[[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
	} else {
		// prepare cipher
		NSString* text = _messageTextView.text;
		if(!_attachFile && ([text length]==0)) {
			// no user selected
			[[[[iToast makeText: NSLocalizedString(@"error_selectDataToSend", @"You need a file or a text message to send.")]setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		} else {
			// delivery message
			[self sendSecureMessage];
		}
	}
}

- (IBAction)selectSender:(id)sender {
	// allow users to pick photos from multiple locations
	ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
	if(status == kABAuthorizationStatusNotDetermined) {
		UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
														  message: NSLocalizedString(@"iOS_RequestPermissionContacts", @"You can select your contact card to send your friends and SafeSlinger will encrypt it for you. To enable this feature, you must allow SafeSlinger access to your Contacts when asked.")
														 delegate: self
												cancelButtonTitle: NSLocalizedString(@"btn_NotNow", @"Not Now")
												otherButtonTitles: NSLocalizedString(@"btn_Continue", @"Continue"), nil];
		message.tag = AskPerm;
		[message show];
	} else if(status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
		NSString* buttontitle = nil;
		NSString* description = nil;
		
		if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
			buttontitle = NSLocalizedString(@"menu_Help", @"Help");
			description = [NSString stringWithFormat: NSLocalizedString(@"iOS_contactError", @"Contacts permission is required for securely sharing contact cards. Tap the %@ button for SafeSlinger Contacts permission details."), buttontitle];
		} else {
			buttontitle = NSLocalizedString(@"menu_Settings", @"Settings");
			description = [NSString stringWithFormat: NSLocalizedString(@"iOS_contactError", @"Contacts permission is required for securely sharing contact cards. Tap the %@ button for SafeSlinger Contacts permission details."), buttontitle];
		}
		
		UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
														  message: description
														 delegate: self
												cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
												otherButtonTitles: buttontitle, nil];
		message.tag = HelpContact;
		[message show];
	} else if(status == kABAuthorizationStatusAuthorized) {
		if(_appDelegate.IdentityNum != NonExist) {
			[self performSegueWithIdentifier:@"EditContact" sender:self];
		}
	}
}

- (IBAction)selectAttachment:(id)sender {
	[self cleanAttachment];
	// allow users to pick photos from multiple locations
	UIActionSheet *actionSheet = [[UIActionSheet alloc]
								  initWithTitle: NSLocalizedString(@"title_ChooseFileLoad", @"Choose Your File")
								  delegate: self
								  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
								  destructiveButtonTitle: nil
								  otherButtonTitles:
								  NSLocalizedString(@"title_photolibary", @"Photo Library"),
								  NSLocalizedString(@"title_photoalbum", @"Photo Album"),
								  NSLocalizedString(@"title_camera", @"Camera"),
								  NSLocalizedString(@"title_soundrecoder", @"Sound Recorder"),
								  nil];
	
	actionSheet.tag = AttachmentSelectionSheet;
	[actionSheet showInView: [self.navigationController view]];
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // files
    if(buttonIndex == actionSheet.cancelButtonIndex) {
        // reset everything
		if(actionSheet.tag == AttachmentSelectionSheet) {
			[self cleanAttachment];
		}
    } else {
        if(actionSheet.tag == AttachmentSelectionSheet) {
            if(buttonIndex == SoundRecoderType) {
                // sound recorder
                [self performSegueWithIdentifier:@"AudioRecord" sender:self];
            } else {
                // Dismiss First
                [self dismissViewControllerAnimated:NO completion:nil];
                
                BOOL _hasPerm = NO;
                // check permission first
                switch(buttonIndex) {
                    case PhotoLibraryType:
                    case PhotosAlbumType:
                        _hasPerm = [self CheckPhotoPerm];
                        break;
                    case CameraType:
                        _hasPerm = [self CheckCameraPerm];
                        break;
                    default:
                        break;
                }
				
                if(_hasPerm) {
                    UIImagePickerController *imagePicker = [UIImagePickerController new];
                    [imagePicker setDelegate:self];
                    switch(buttonIndex) {
                        case PhotoLibraryType:
                            //Photo Library
                            [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                            break;
                        case PhotosAlbumType:
                            [imagePicker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
                            break;
                        case CameraType:
                            [imagePicker setSourceType: UIImagePickerControllerSourceTypeCamera];
                            [imagePicker setShowsCameraControls:YES];
                            break;
                        default:
                            break;
                    }
                    [imagePicker setAllowsEditing:YES];
                    [self presentViewController:imagePicker animated:YES completion:nil];
                    imagePicker = nil;
                }
                
            }
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [info valueForKey:UIImagePickerControllerReferenceURL];
    NSURL* urlstr = [info valueForKey:UIImagePickerControllerReferenceURL];
    NSData* imgdata = UIImageJPEGRepresentation([info valueForKey:UIImagePickerControllerOriginalImage], 1.0);
    
    if(!imgdata.length) {
        [[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    } else if(imgdata.length > 9437184) {
        NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", "Cannot send attachments greater than %d bytes in size."), 9437184];
        [self dismissViewControllerAnimated:YES completion:nil];
        [[[[iToast makeText: msg]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        return;
    }
    
    NSString *FN = nil;
    if(!urlstr) {
        DEBUGMSG(@"camera file");
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"yyyyMMdd-HHmmss"];
        NSDate *now = [[NSDate alloc] init];
        NSString *dateString = [format stringFromDate:now];
        FN = [NSString stringWithFormat:@"cam-%@.jpg", dateString];
        _attachFile = [NSURL URLWithString:FN];
    } else {
        // has id
        NSRange range, idrange;
        range = [[urlstr absoluteString] rangeOfString:@"id="];
        idrange.location = range.location+range.length;
        range = [[urlstr absoluteString] rangeOfString:@"&ext="];
        idrange.length = range.location - idrange.location;
        FN = [NSString stringWithFormat:@"%@.%@", [[urlstr absoluteString]substringWithRange:idrange], [[urlstr absoluteString]substringFromIndex:range.location+range.length]];
        _attachFile = [NSURL URLWithString:FN];
    }
    NSString *sizeinfo = [NSString stringWithFormat:@"%@ (%@).", FN,
                          [NSString stringWithFormat:NSLocalizedString(@"label_kb",@"%.0f kb"), [imgdata length]/1024.0f]
                          ];
    [_addAttachmentButton setTitle:sizeinfo forState:UIControlStateNormal];
    attachFileRawBytes = imgdata;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"AudioRecord"]) {
        AudioRecordView *dest = (AudioRecordView *)segue.destinationViewController;
        dest.parent = self;
    } else if([segue.identifier isEqualToString:@"ContactSelectForCompose"]) {
        ContactSelectView *dest = (ContactSelectView *)segue.destinationViewController;
        dest.delegate = self;
		dest.contactSelectionMode = ContactSelectionModeCompose;
    }
}

#pragma mark - UITextViewDelegate methods

- (void)textViewDidBeginEditing:(UITextView *)textView {
    self.parentViewController.navigationItem.leftBarButtonItem = _cancelButton;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    self.parentViewController.navigationItem.leftBarButtonItem = _logoutButton;
}

#pragma mark - ContactSelectViewDelegate methods

- (void)contactSelected:(ContactEntry *)contact {
	_selectedReceiver = contact;
	[self updateReceiver];
}

- (void)contactDeleted:(ContactEntry *)contact {
	if([_selectedReceiver.pushToken isEqualToString:contact.pushToken]) {
		_selectedReceiver = nil;
		[self updateReceiver];
	}
}

@end
