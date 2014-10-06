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

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

@class ContactEntry;
@class AppDelegate;

typedef enum ActionSheetCmd{
    IdentityChangeSheet = 0,
    AttachmentSelectionSheet
}ActionSheetCmd;

typedef enum AttachCategory{
    PhotoLibraryType = 0,
    PhotosAlbumType=1,
    CameraType=2,
    SoundRecoderType=3,
    ShareFolderType=4
}AttachCategory;

@interface ComposeView : UIViewController <UITextViewDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIAlertViewDelegate>
{
    // SafeSlinger Selector
    ContactEntry *selectedUser;
    
    // Delegate
    AppDelegate *delegate;
    
    // Attachment
    NSURL *attachFile;
    NSData *attachFileRawBytes;
}

@property (nonatomic, strong) IBOutlet UIButton *AttachBtn;
@property (nonatomic, strong) IBOutlet UIButton *SelfBtn;
@property (nonatomic, strong) IBOutlet UIButton *RecipientBtn;
@property (nonatomic, strong) IBOutlet UIImageView *SelfPhoto;
@property (nonatomic, strong) IBOutlet UIImageView *RecipientPhoto;
@property (nonatomic, strong) IBOutlet UITextView *Content;
@property (nonatomic, strong) IBOutlet UILabel *ProgressHint;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *ProgressView;
@property (nonatomic, strong) IBOutlet UIScrollView *ScrollView;
@property (nonatomic, strong) UIBarButtonItem *SendBtn;
@property (nonatomic, strong) UIBarButtonItem *CancelBtn;
@property (nonatomic, strong) UIBarButtonItem *LogoutBtn;

@property (nonatomic, readwrite) CGRect originalFrame;
@property (nonatomic, strong) ContactEntry *selectedUser;

@property (nonatomic, retain) AppDelegate *delegate;
@property (nonatomic, retain) NSURL *attachFile;
@property (nonatomic, retain) NSData *attachFileRawBytes;


-(IBAction) SelectSender:(id)sender;
-(IBAction) SelectRecipient:(id)sender;
-(IBAction) SelectAttach:(id)sender;

-(void) UpdateSelf;
-(void) UpdateAttachment;
-(void) UpdateRecipient;

@end
