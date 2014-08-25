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
#import "ComposeView.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "ContactSelectView.h"
#import "FunctionView.h"
#import "ContactManageView.h"
#import "AudioRecordView.h"

#import <safeslingerexchange/iToast.h>
#import <safeslingerexchange/ActivityWindow.h>

@interface ComposeView ()

@end

@implementation ComposeView

@synthesize AttachBtn, RecipientBtn, SelfBtn, Content, SendBtn, CancelBtn, LogoutBtn;
@synthesize selectedUser;
@synthesize delegate;
@synthesize attachFile;
@synthesize attachFileRawBytes;
@synthesize SelfPhoto, RecipientPhoto, ProgressHint, ProgressView, ScrollView;

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
    
    delegate = [[UIApplication sharedApplication] delegate];
    _originalFrame = self.view.frame;
    
    Content.layer.borderWidth = 1.0f;
    Content.layer.borderColor = [[UIColor grayColor] CGColor];
    
    SendBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_SendFile", @"Send")
                                               style:UIBarButtonItemStyleDone
                                              target:self
                                              action:@selector(SendMsg)];
    
    CancelBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                               style:UIBarButtonItemStyleDone
                                              target:self
                                              action:@selector(DismissKeyboard)];
    
    LogoutBtn = self.parentViewController.navigationItem.leftBarButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [Content resignFirstResponder];
    
    // Change Title and Help Button
    self.parentViewController.navigationItem.title = NSLocalizedString(@"menu_TagComposeMessage", @"Compose");
    self.parentViewController.navigationItem.hidesBackButton = YES;
    self.parentViewController.navigationItem.rightBarButtonItem = SendBtn;
    
    ProgressHint.text = nil;
    [ProgressView stopAnimating];
    
    [self UpdateSelf];
    [self CleanAttachment];
    [self CleanRecipient];
    Content.text = nil;
    
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
    ScrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height*1.5);
    
    // get the size of the keyboard
    CGSize keyboardSize = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    if(_originalFrame.size.height - (keyboardSize.height+Content.frame.origin.y+Content.frame.size.height) < 0)
    {
        // covered by keyboard, left the view and scroll it
        CGFloat offset = 20.0+(keyboardSize.height+Content.frame.origin.y+Content.frame.size.height)-_originalFrame.size.height;
        [ScrollView setContentOffset:CGPointMake(0.0, offset) animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    ScrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height);
    [ScrollView setContentOffset:CGPointMake(0.0, 0.0) animated:YES];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)unwindToCompose:(UIStoryboardSegue *)unwindSegue
{
    if([[unwindSegue identifier]isEqualToString:@"FinishRecording"])
    {
        AudioRecordView *view = [unwindSegue sourceViewController];
        self.attachFile = view.audio_recorder.url;
        [self UpdateAttachment];
    }else if([[unwindSegue identifier]isEqualToString:@"FinishContactSelect"])
    {
        ContactSelectView *view = [unwindSegue sourceViewController];
        self.selectedUser = view.selectedUser;
        [self UpdateRecipient];
    }else if([[unwindSegue identifier]isEqualToString:@"FinishEditContact"])
    {
        [self UpdateSelf];
    }
}

- (void)UpdateRecipient
{
    if(selectedUser)
    {
        NSString* btnStr = [NSString stringWithFormat:@"%@ %@\n%@ %@", NSLocalizedString(@"label_SendTo", @"To:"), [NSString composite_name:selectedUser.fname withLastName:selectedUser.lname], NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:selectedUser.keygenDate GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]];
        
        [RecipientBtn setTitle:btnStr forState:UIControlStateNormal];
        
        if(selectedUser.photo)
        {
            [RecipientPhoto setImage: [UIImage imageWithData: selectedUser.photo]];
        }else
        {
            [RecipientPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
        }
    }else{
        // No select user
        [RecipientPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
        [RecipientBtn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    }
}

- (void)UpdateSelf
{
    // get name from profile
    NSString* fulln = [delegate.DbInstance GetProfileName];
    if(delegate.IdentityNum==NonLink)
    {
        [SelfPhoto setImage:[UIImage imageNamed:@"blank_contact.png"]];
        
    }else if(delegate.IdentityNum>0)
    {
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = NULL;
        aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if (!granted) {
                return;
            }
        });
        
        ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, delegate.IdentityNum);
        // set self photo
        CFDataRef imgData = ABPersonCopyImageData(aRecord);
        if(imgData)
        {
            UIImage *image = [[UIImage imageWithData:(__bridge NSData *)imgData]scaleToSize:CGSizeMake(45.0f, 45.0f)];
            [SelfPhoto setImage:image];
            // update cache image
            delegate.IdentityImage = (NSData*)UIImageJPEGRepresentation(image, 0.9);
            CFRelease(imgData);
        }
        else [SelfPhoto setImage:[UIImage imageNamed:@"blank_contact.png"]];
        if(aBook)CFRelease(aBook);
    }
    
    NSString* btnStr = [NSString stringWithFormat:@"%@\n%@", [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_SendFrom", @"From:"), fulln], [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_Key", @"Key:"), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat:@"dd/MMM/yyyy"]]];
    
    [SelfBtn setTitle:btnStr forState:UIControlStateNormal];
    
}

-(void)UpdateAttachment
{
    if(attachFile)
    {
        attachFileRawBytes = [NSData dataWithContentsOfURL:attachFile];
        if([attachFileRawBytes length]==0)
        {
            [[[[iToast makeText: NSLocalizedString(@"error_CannotSendEmptyFile", @"Cannot send an empty file.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            attachFileRawBytes = nil;
            attachFile  = nil;
            [AttachBtn setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
        }else if([attachFileRawBytes length]>9437184)
        {
            NSString *msg = [NSString stringWithFormat: NSLocalizedString(@"error_CannotSendFilesOver", @"Cannot send attachments greater than %d bytes in size."), 9437184];
            [[[[iToast makeText: msg]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            attachFileRawBytes = nil;
            attachFile  = nil;
            [AttachBtn setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
        }else{
            [AttachBtn setTitle:[NSString stringWithFormat:@"%@ (%@)", [attachFile lastPathComponent], [NSString CalculateMemorySize:(int)[attachFileRawBytes length]]] forState:UIControlStateNormal];
        }
    }else{
        [AttachBtn setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)DismissKeyboard
{
    [Content resignFirstResponder];
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
            [[[[iToast makeText: NSLocalizedString(@"error_selectDataToSend", @"You need a file or a text message to send.")]setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
        }else{
            // delivery message
            [self sendSecureMessage];
        }
    }
}

-(IBAction) SelectRecipient:(id)sender
{
    // clean previous selection if necessary
    [self CleanRecipient];
    [self performSegueWithIdentifier:@"ContactSelectForCompose" sender:self];
}

-(IBAction) SelectSender:(id)sender
{
    // allow users to pick photos from multiple locations
    if([UtilityFunc checkContactPermission])
    {
        if(delegate.IdentityNum!=NonExist)
        {
            [self performSegueWithIdentifier:@"EditContact" sender:self];
        }
    }else{
        if(![[NSUserDefaults standardUserDefaults] boolForKey: kRequireContactPrivacy])
        {
            UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
                                                              message: NSLocalizedString(@"iOS_RequestPermissionContacts", @"You can select your contact card to send your friends and SafeSlinger will encrypt it for you. To enable this feature, you must allow SafeSlinger access to your Contacts when asked.")
                                                             delegate: self
                                                    cancelButtonTitle: NSLocalizedString(@"btn_NotNow", @"Not Now")
                                                    otherButtonTitles: NSLocalizedString(@"btn_Continue", @"Continue"), nil];
            message.tag = AskPerm;
            [message show];
            message = nil;
        }else{
            
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_Warn", @"Warning")
                                                              message: NSLocalizedString(@"iOS_contactError", @"Contacts permission required. Please go to iOS Settings to enable Contacts permissions.")
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                    otherButtonTitles:NSLocalizedString(@"menu_Help", @"Help"), nil];
            message.tag = HelpContact;
            [message show];
            message = nil;
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex)
    {
        if(alertView.tag==AskPerm)
        {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey: kRequireContactPrivacy];
            [UtilityFunc TriggerContactPermission];
        }else if(alertView.tag==HelpContact)
        {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kContactHelpURL]];
        }
    }
}

- (void) CleanAttachment
{
    // clean previous selection if necessary
    [AttachBtn setTitle:NSLocalizedString(@"btn_SelectFile", @"Select File") forState:UIControlStateNormal];
    attachFile = nil;
    attachFileRawBytes = nil;
}

- (void) CleanRecipient
{
    // clean previous selection if necessary
    [RecipientBtn setTitle:NSLocalizedString(@"label_SelectRecip", @"Select Recipient") forState:UIControlStateNormal];
    selectedUser = nil;
}

- (void) sendSecureMessage
{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            ProgressHint.text = NSLocalizedString(@"prog_encrypting", @"encrypting...");
            [ProgressView startAnimating];
        });
    });
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSData* packnonce = nil;
    NSMutableData* pktdata = [[NSMutableData alloc]initWithCapacity:0];
    
    // get file type in MIME format
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(__bridge CFStringRef)[[attachFile lastPathComponent] pathExtension] ,NULL);
    NSString* MimeType = (__bridge NSString*)UTTypeCopyPreferredTagWithClass(UTI,kUTTagClassMIMEType);
    
    packnonce = [SSEngine BuildCipher: selectedUser.keyid Message:Content.text Attach:[attachFile lastPathComponent] RawFile:attachFileRawBytes MIMETYPE:MimeType Cipher:pktdata];
    
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
            ProgressHint.text = NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...");
            [ProgressView startAnimating];
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
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
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
                     [ErrorLogger ERRORDEBUG:error_msg];
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self PrintErrorOnUI:error_msg];
                     });
                 }
             }
         }
     }];
}

- (void)PrintErrorOnUI:(NSString*)error
{
    ProgressHint.text = nil;
    [ProgressView stopAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

-(void)SaveMessage: (NSData*)msgid
{
    // [delegate.activityView DisableProgress];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // filetype
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,(__bridge CFStringRef)[attachFile pathExtension],NULL);
    NSString* fileType = (__bridge NSString*)UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    if(UTI)CFRelease(UTI);
    
    MsgEntry *NewMsg = [[MsgEntry alloc]
                        InitOutgoingMsg:msgid
                        Recipient:selectedUser
                        Message:Content.text
                        FileName:[attachFile lastPathComponent]
                        FileType:fileType
                        FileData:attachFileRawBytes];
    
    if([delegate.DbInstance InsertMessage: NewMsg])
    {
        // reload the view
        [[[[iToast makeText: NSLocalizedString(@"state_FileSent", @"Message sent.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [self.tabBarController setSelectedIndex:0];
    }else{
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
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
                                  nil];
    
    actionSheet.tag = AttachmentSelectionSheet;
    [actionSheet showInView: [self.navigationController view]];
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
            if(buttonIndex==SoundRecoderType){
                // sound recorder
                [self performSegueWithIdentifier:@"AudioRecord" sender:self];
            }else {
                // Dismiss First
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
    if(!urlstr)
    {
        DEBUGMSG(@"camera file");
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"yyyyMMdd-HHmmss"];
        NSDate *now = [[NSDate alloc] init];
        NSString *dateString = [format stringFromDate:now];
        FN = [NSString stringWithFormat:@"cam-%@.jpg", dateString];
        attachFile = [NSURL URLWithString:FN];
    }else {
        // has id
        NSRange range, idrange;
        range = [[urlstr absoluteString] rangeOfString:@"id="];
        idrange.location = range.location+range.length;
        range = [[urlstr absoluteString] rangeOfString:@"&ext="];
        idrange.length = range.location - idrange.location;
        FN = [NSString stringWithFormat:@"%@.%@", [[urlstr absoluteString]substringWithRange:idrange], [[urlstr absoluteString]substringFromIndex:range.location+range.length]];
        attachFile = [NSURL URLWithString:FN];
    }
    NSString *sizeinfo = [NSString stringWithFormat:@"%@ (%@).", FN,
                          [NSString stringWithFormat:NSLocalizedString(@"label_kb",@"%.0f kb"), [imgdata length]/1024.0f]
                          ];
    [AttachBtn setTitle:sizeinfo forState:UIControlStateNormal];
    attachFileRawBytes = imgdata;
    [self dismissViewControllerAnimated:YES completion:nil];
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
    self.parentViewController.navigationItem.leftBarButtonItem = CancelBtn;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    self.parentViewController.navigationItem.leftBarButtonItem = LogoutBtn;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}



@end
