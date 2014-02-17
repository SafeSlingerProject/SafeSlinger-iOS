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

#import <MobileCoreServices/UTType.h>
#import <Foundation/Foundation.h>

#import "MessageComposer.h"
#import "SSContactSelector.h"
#import "KeySlingerAppDelegate.h"
#import "FileChooser.h"
#import "iToast.h"
#import "Utility.h"
#import "SoundRecoder.h"
#import "VersionCheckMarco.h"
#import "sha3.h"
#import "SSEngine.h"
#import "ErrorLogger.h"


@interface MessageComposer ()

@end

@implementation MessageComposer

@synthesize AttachBtn, RecipientBtn, SelfBtn, Content, SendBtn;
@synthesize selector, selectedUser;
@synthesize delegate;
@synthesize attachFile;
@synthesize attachFileRawBytes;
@synthesize SelfPhoto, RecipientPhoto, MsgBoxHInt;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        delegate = [[UIApplication sharedApplication] delegate];
        _originalFrame = self.view.frame;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationItem.title = NSLocalizedString(@"menu_TagComposeMessage", @"Compose");
    [MsgBoxHInt setText: NSLocalizedString(@"label_ComposeHint", @"Compose Message")];
    Content.layer.borderWidth = 1.0f;
    Content.layer.borderColor = [[UIColor grayColor] CGColor];
    [RecipientBtn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    [AttachBtn setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
    selector = [[SSContactSelector alloc] initWithNibName:@"GeneralTableView" bundle:nil];
    SendBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_SendFile", @"Send")
                                               style:UIBarButtonItemStyleDone
                                              target:self
                                              action:@selector(SendMsg)];
}

- (void)UpdateRecipient: (NSString*)RecipientName
{
    [RecipientBtn setTitle: [NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), RecipientName, NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:selectedUser.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]] forState:UIControlStateNormal];
    if(selectedUser.photo)
    {
        [RecipientPhoto setImage: [UIImage imageWithData:selectedUser.photo]];
    }else
    {
        DEBUGMSG(@"no photo.");
        [RecipientPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
    }
}

- (void)UpdateSelf
{
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            return;
        }
    });
    
    ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
    // set self photo
    CFDataRef imgData = ABPersonCopyImageData(aRecord);
    if(imgData)
    {
        UIImage *image = [[UIImage imageWithData:(NSData *)imgData]scaleToSize:CGSizeMake(45.0f, 45.0f)];
        [SelfPhoto setImage:image];
        // update cache image
        delegate.SelfPhotoCache = [(NSData*)UIImageJPEGRepresentation(image, 0.9)retain];
        
        CFRelease(imgData);
    }
    else [SelfPhoto setImage:[UIImage imageNamed:@"blank_contact.png"]];
    
    // set name and genkey date
    NSString* fulln = nil;
    
    CFStringRef fn = ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
    CFStringRef ln = ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
    fulln = [NSString composite_name:(NSString*)fn withLastName:(NSString*)ln];
    if(fn)CFRelease(fn);
    if(ln)CFRelease(ln);
    
    NSString* btnStr = [NSString stringWithFormat:@"%@\n%@", [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_SendFrom", @"From:"), fulln], [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]]];
    [SelfBtn setTitle:btnStr forState:UIControlStateNormal];
    
    if(aBook)CFRelease(aBook);
}

-(void)setAttachment: (NSURL*)attachfile
{
    // attachment check
    if(!attachfile)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_CannotSendNullFile", @"Cannot send a null file.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }
    else
    {
        NSData* fdata = [NSData dataWithContentsOfURL:attachfile];
        if([fdata length]==0)
        {
            [[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        }else if([fdata length]>9437184)
        {
            NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", @"Cannot send attachments greater than %d bytes in size."), 9437184];
            [[[[iToast makeText: msg]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            
        }else{
            attachFile = [attachfile retain];
            attachFileRawBytes = [fdata retain];
            [AttachBtn setTitle:[NSString stringWithFormat:@"%@ (%@)", [attachfile lastPathComponent], [NSString CalculateMemorySize:[fdata length]]] forState:UIControlStateNormal];
            // display send button dynamically
            self.navigationItem.rightBarButtonItem = SendBtn;
        }
        [fdata release];
        fdata = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [self UpdateSelf];
    [Content resignFirstResponder];
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
    [Content resignFirstResponder];
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

- (void)dealloc
{
    [AttachBtn release]; AttachBtn = nil;
    [RecipientBtn release]; RecipientBtn = nil;
    [SelfBtn release];SelfBtn = nil;
    [SelfPhoto release];SelfPhoto = nil;
    [RecipientPhoto release];RecipientPhoto = nil;
    [Content release];Content = nil;
    [selectedUser release];selectedUser = nil;
    [selector release];selector = nil;
    [attachFile release];attachFile = nil;
    [SendBtn release];SendBtn = nil;
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)SendMsg
{
    [Content resignFirstResponder];
    if([[self.RecipientBtn titleLabel].text isEqualToString: NSLocalizedString(@"label_SelectRecip", @"Select Recipient")])
    {
        // no user selected
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidRecipient", @"Invalid recipient.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }else {
        // prepare cipher
        NSString* text = self.Content.text;
        if(!attachFile && ([text length]==0) )
        {
            // no user selected
            [[[[iToast makeText: NSLocalizedString(@"error_selectDataToSend", @"You need a file or a text message to send.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        }else{
            // delivery message
            [self sendSecureMessage];
        }
    }
}

-(IBAction) SelectSender:(id)sender
{
    // allow users to pick photos from multiple locations
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: NSLocalizedString(@"title_MyIdentity", @"My Identity")
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_Edit", @"Edit"),
                                  NSLocalizedString(@"menu_CreateNew", @"Create New"),
                                  NSLocalizedString(@"menu_UseAnother", @"Use Another"),
                                  nil];
    actionSheet.tag = IdentityChangeSheet;
    [actionSheet showInView: [self.navigationController view]];
    [actionSheet release];
}

-(IBAction) SelectReceiver:(id)sender
{
    // clean previous user if necessary
    [self CleanRecipient];
    [delegate.navController pushViewController: self.selector animated: YES];
}

- (void) CleanRecipient
{
    [selectedUser release];
    selectedUser = nil;
    [self.RecipientPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
    [RecipientBtn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
}

- (void) CleanAttachment
{
    // clean previous selection if necessary
    [AttachBtn setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
    [attachFile release];attachFile = nil;
    [attachFileRawBytes release];attachFileRawBytes = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (void)getDeviceStatus
{
    DEBUGMSG(@"getDeviceStatus");
    if(selectedUser.devType==iOS)
    {
        NSMutableData *query = [[NSMutableData alloc] init];
        // version(4) || ID_length(4) || token (various) || devicetype(4)
        int tmp = htonl([delegate getVersionNumberByInt]);
        [query appendBytes: &tmp length: 4];
        tmp = htonl([selectedUser.pushtoken length]);
        [query appendBytes: &tmp length: 4];
        [query appendData:[selectedUser.pushtoken dataUsingEncoding:NSUTF8StringEncoding]];
        tmp = htonl(selectedUser.devType);
        [query appendBytes: &tmp length: 4];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, QUERYTOKEN]];
        
        // Default timeout
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
        [request setURL: url];
        [request setHTTPMethod: @"POST"];
        [request setHTTPBody: query];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
         {
             if(error)
             {
                 [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                           [error localizedDescription],
                                           [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
                 if(error.code==NSURLErrorTimedOut)
                 {
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         // [self ReloadTable];
                         [self PrintErrorOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                     });
                 }else{
                     // general errors
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         // [self ReloadTable];
                         [self PrintErrorOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     });
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         // [self ReloadTable];
                         [self PrintErrorOnUI:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'")];
                     });
                 }
             }else{
                 if ([data length] > 0 )
                 {
                     // start parsing data
                     const char *msgchar = [data bytes];
                     if(ntohl(*(int *)msgchar) == 0)
                     {
                         // Error Message
                         NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                         DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             // [self ReloadTable];
                             [self PrintErrorOnUI:error_msg];
                         });
                     }
                 }
             }
             [query release];
         }];
    }
}

- (void)sendSecureMessage
{
    DEBUGMSG(@"sendSecureMessage");
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [delegate.activityView EnableProgress:NSLocalizedString(@"prog_encrypting", @"encrypting...") SecondMeesage:@"" ProgessBar:NO];
        });
    });
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSData* packnonce = nil;
    NSMutableData* pktdata = [[NSMutableData alloc]initWithCapacity:0];
    
    // get file type in MIME format
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(CFStringRef)[[attachFile lastPathComponent] pathExtension] ,NULL);
    NSString* MimeType = (NSString*)UTTypeCopyPreferredTagWithClass(UTI,kUTTagClassMIMEType);
    
    packnonce = [SSEngine BuildCipher:[NSString composite_name:selectedUser.fname withLastName:selectedUser.lname]  Token:selectedUser.pushtoken Message:Content.text Attach:[attachFile lastPathComponent] RawFile:attachFileRawBytes MIMETYPE:MimeType Cipher:pktdata];
    
    NSURL *url = nil;
    switch (selectedUser.devType) {
        case Android:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTANDROIDMSG]];
            break;
        case iOS:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTIOSMSG]];
            break;
        default:
            break;
    }
    if(!url)return;
    
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [delegate.activityView UpdateProgessMsg: NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...")];
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
                    // [self ReloadTable];
                    [self PrintErrorOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                });
            }else{
                // general errors
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    // [self ReloadTable];
                    [self PrintErrorOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                });
            }
        }else{
            if ([data length] > 0 )
            {
                // start parsing data
                const char *msgchar = [data bytes];
                DEBUGMSG(@"Succeeded! Received %d bytes of data",[data length]);
                DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                if (ntohl(*(int *)msgchar) > 0)
                {
                    // Send Response
                    DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                    DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                    // Save to Database
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [self SaveMessage:packnonce];
                    });
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
        [pktdata release];
    }];
}

- (void)PrintErrorOnUI:(NSString*)error
{
    [delegate.activityView DisableProgress];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

-(void)SaveMessage: (NSData*)msgid
{
    [delegate.activityView DisableProgress];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // filetype
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(CFStringRef)[attachFile pathExtension],NULL);
    NSString* fileType = (NSString*)UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    if(UTI)CFRelease(UTI);
    
    MsgEntry *NewMsg = [[MsgEntry alloc]
                        initPlainTextMessage:msgid
                        UserName:[NSString composite_name:selectedUser.fname withLastName:selectedUser.lname]
                        Token:selectedUser.pushtoken
                        Message:Content.text
                        Photo:nil
                        FileName:[attachFile lastPathComponent]
                        FileType:fileType
                        FIleData:attachFileRawBytes];
    
    if([delegate.DbInstance InsertMessage: NewMsg])
    {
        // reload the view
        [[[[iToast makeText: NSLocalizedString(@"state_FileSent", @"Message sent.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [delegate.navController popViewControllerAnimated: NO];
        [delegate.navController pushViewController: delegate.msgList animated: YES];
    }else{
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    [NewMsg release];
}

-(IBAction) SelectAttach:(id)sender
{
    [self CleanAttachment];
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
                                  NSLocalizedString(@"title_sharingfolder", @"Sharing Folder"),
                                  nil];
    actionSheet.tag = AttachmentSelectionSheet;
    [actionSheet showInView: [self.navigationController view]];
    [actionSheet release];
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet
{
    
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // files
    if(buttonIndex==actionSheet.cancelButtonIndex)
    {
        // reset everything
        if(actionSheet.tag==AttachmentSelectionSheet)[self CleanAttachment];
    }else{
        if(actionSheet.tag==AttachmentSelectionSheet)
        {
            if(buttonIndex==ShareFolderType){
                // from file sharing folder
                FileChooser *chooser = [[FileChooser alloc] initWithStyle: UITableViewStyleGrouped];
                [self.delegate.navController pushViewController:chooser animated:YES];
                [chooser release];
                chooser = nil;
            }else if(buttonIndex==SoundRecoderType){
                // sound recorder
                SoundRecoder *recoder = nil;
                
                if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
                {
                    if(IS_4InchScreen)
                        recoder = [[SoundRecoder alloc] initWithNibName:@"SoundRecoder_4in" bundle:nil];
                    else
                        recoder = [[SoundRecoder alloc] initWithNibName:@"SoundRecoder" bundle:nil];
                }
                else{
                    recoder = [[SoundRecoder alloc] initWithNibName:@"SoundRecoder_ip5" bundle:nil];
                }
                
                [self.delegate.navController pushViewController:recoder animated:YES];
                [recoder release];
                recoder = nil;
            }else {
                // Dismiss First
                //[self dismissModalViewControllerAnimated:NO];
                [self dismissViewControllerAnimated:NO completion:nil];
                // use new instread of using alloc, init call due to memory leaks
                UIImagePickerController *imagePicker = [UIImagePickerController new];
                [imagePicker setDelegate:self];
                switch(buttonIndex)
                {
                    case PhotoLibraryType:
                        //Photo Library
                        [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                        break;
                    case PhotosAlbumType:
                        [imagePicker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
                        break;
                    case CameraType:
                        [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
                        break;
                    default:
                        break;
                }
                [imagePicker setAllowsEditing:YES];
                [self presentViewController:imagePicker animated:YES completion:nil];
                [imagePicker release];
                imagePicker = nil;
            }
        }else if(actionSheet.tag==IdentityChangeSheet)
        {
            switch(buttonIndex)
            {
                case EditOld:
                    //Edit Contact
                    [self editContact];
                    break;
                case AddNew:
                    // Create New
                    [self addContact];
                    break;
                case ReSelect:
                    // Use Another
                    [self selectAnotherContact];
                    break;
                default:
                    break;
            }
        }
    }
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [info valueForKey:UIImagePickerControllerReferenceURL];
    NSURL* urlstr = [info valueForKey:UIImagePickerControllerReferenceURL];
    NSData* imgdata = UIImageJPEGRepresentation([info valueForKey:UIImagePickerControllerOriginalImage], 1.0);
    
    if([imgdata length]==0)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }else if([imgdata length]>9437184)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", @"Cannot send files greater than %d megabytes in size."), 9437184];
        [self dismissViewControllerAnimated:YES completion:nil];
        [[[[iToast makeText: msg]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        return;
    }
    
    NSString *FN = nil;
    if(urlstr==nil)
    {
        DEBUGMSG(@"camera file");
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"yyyyMMdd-HHmmss"];
        NSDate *now = [[NSDate alloc] init];
        NSString *dateString = [format stringFromDate:now];
        FN = [NSString stringWithFormat:@"cam-%@.jpg", dateString];
        self.attachFile = [NSURL URLWithString:FN];
        [format release];
        [now release];
        
    }else {
        // has id
        NSRange range, idrange;
        range = [[urlstr absoluteString] rangeOfString:@"id="];
        idrange.location = range.location+range.length;
        range = [[urlstr absoluteString] rangeOfString:@"&ext="];
        idrange.length = range.location - idrange.location;
        FN = [NSString stringWithFormat:@"%@.%@", [[urlstr absoluteString]substringWithRange:idrange], [[urlstr absoluteString]substringFromIndex:range.location+range.length]];
        self.attachFile = [NSURL URLWithString:FN];
    }
    NSString *sizeinfo = [NSString stringWithFormat:@"%@ (%@).",
                          FN,
                          [NSString stringWithFormat:NSLocalizedString(@"label_kb",@"%.0f kb"), [imgdata length]/1024.0f]
                          ];
    [AttachBtn setTitle:sizeinfo forState:UIControlStateNormal];
    attachFileRawBytes = [imgdata retain];
    self.navigationItem.rightBarButtonItem = SendBtn;
    [self dismissViewControllerAnimated:YES completion:nil];
}


-(void)setRecipient: (SSContactEntry*)GivenUser
{
    selectedUser = [GivenUser retain];
    // new feature, check token status for iOS devices
    [self getDeviceStatus];
    [self UpdateRecipient:[NSString composite_name:selectedUser.fname withLastName:selectedUser.lname]];
}

#pragma UITextViewDelegate Methods
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    return YES;
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    self.navigationItem.rightBarButtonItem = SendBtn;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    self.navigationItem.rightBarButtonItem = nil;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}

#pragma mark ABPeoplePickerNavigationControllerDelegate
-(void) peoplePickerNavigationControllerDidCancel: (ABPeoplePickerNavigationController *)peoplePicker
{
    DEBUGMSG(@"peoplePickerNavigationControllerDidCancel");
    //user canceled, no new contact selected
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
	[peoplePicker autorelease];
}

-(BOOL) peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person
{
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
	[peoplePicker autorelease];
    // check name field is existed.
    if ((ABRecordCopyValue(person, kABPersonFirstNameProperty)==NULL)&&(ABRecordCopyValue(person, kABPersonLastNameProperty)==NULL))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing2", @"This contact is missing a name, please reselect.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else{
        delegate.myID = ABRecordGetRecordID(person);
        [delegate saveConactData];
        [self UpdateSelf];
    }
	return NO;
}

-(BOOL) peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person property: (ABPropertyID)property identifier: (ABMultiValueIdentifier)identifier
{
	return NO;
}

#pragma mark ABPersonViewControllerDelegate
-(BOOL) personViewController: (ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson: (ABRecordRef)person property: (ABPropertyID)property identifier: (ABMultiValueIdentifier)identifierForValue
{
    DEBUGMSG(@"shouldPerformDefaultActionForPerson");
	return NO;
}

#pragma mark ABNewPersonViewControllerDelegate methods
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
    if (person)
    {
        if ((ABRecordCopyValue(person, kABPersonFirstNameProperty)==NULL)&&(ABRecordCopyValue(person, kABPersonLastNameProperty)==NULL))
        {
            [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }else{
            delegate.myID = ABRecordGetRecordID(person);
            [delegate saveConactData];
            [self UpdateSelf];
        }
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) editContact
{
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            return;
        }
    });
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
    ABPersonViewController *personView = [[ABPersonViewController alloc] init];
    
    personView.allowsEditing = YES;
    personView.personViewDelegate = self;
    personView.displayedPerson = person;
    
    personView.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_Done", @"Done")
                                                                                   style:UIBarButtonItemStylePlain
                                                                                  target:self
                                                                                  action:@selector(ReturnFromEditView)] ;
    [self.navigationController pushViewController:personView animated:YES];
    [personView release];
    if(aBook)CFRelease(aBook);
}

- (void)ReturnFromEditView
{
    // check name if it existed
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            return;
        }
    });
    
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
    CFStringRef FName = ABRecordCopyValue(person, kABPersonFirstNameProperty);
    CFStringRef LName = ABRecordCopyValue(person, kABPersonLastNameProperty);
    
    if((FName==NULL)&&(LName==NULL))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else
    {
        if(FName)CFRelease(FName);
        if(LName)CFRelease(LName);
        [self UpdateSelf];
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    if(aBook)CFRelease(aBook);
}

- (void) addContact
{
    [self dismissViewControllerAnimated:NO completion:nil];
    ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
    picker.newPersonViewDelegate = self;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:navigation animated:YES completion:nil];
    [picker release];
    [navigation release];
}

- (void) selectAnotherContact
{
    [self dismissViewControllerAnimated:NO completion:nil];
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

@end
