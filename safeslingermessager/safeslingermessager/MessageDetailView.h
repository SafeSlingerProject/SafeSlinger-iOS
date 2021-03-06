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

@import UIKit;
@import QuickLook;
@import AddressBook;
@import Dispatch;
#import "MessageReceiver.h"
#import "MessageSender.h"
#import "AudioRecordView.h"

@class MsgListEntry;
@class AppDelegate;
@class MessageView;

@interface MessageDetailView : UIViewController <UITableViewDataSource, UITabBarDelegate, QLPreviewControllerDataSource, QLPreviewControllerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate, MessageReceiverNotificationDelegate, MessageSenderDelegate, AudioRecordDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    // For Grand Central Dispatch
    dispatch_queue_t BackGroundQueue;
    AppDelegate *delegate;
}

@property (nonatomic, retain) AppDelegate *delegate;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSURL *preview_cache_page;
@property (nonatomic, strong) QLPreviewController *previewer;
@property (nonatomic, readwrite) BOOL preview_used;
@property (nonatomic, strong) NSIndexPath *selectIndex;
@property (nonatomic, strong) UIImage *b_img;
@property (nonatomic, strong) UIImage *thread_img;
@property (nonatomic, strong) MsgListEntry *assignedEntry;
@property (nonatomic, strong) NSLock *OperationLock;

@property (strong, nonatomic) IBOutlet UIButton *attachmentButton;

@property (strong, nonatomic) IBOutlet UIView *bottomBarView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomBarHeightConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomBarBottomSpaceConstraint;
@property (nonatomic, strong) IBOutlet UITextField *messageTextField;
@property (nonatomic, strong) IBOutlet UIButton *sendButton;

@property (strong, nonatomic) IBOutlet UIView *attachmentDetailsView;
@property (strong, nonatomic) IBOutlet UIButton *attachmentFileNameButton;
@property (strong, nonatomic) IBOutlet UIImageView *attachmentFileThumbnailImageView;

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) UIBarButtonItem *CancelBtn;
@property (nonatomic, strong) UIBarButtonItem *BackBtn;
@property (nonatomic) ABRecordRef tRecord;

@end
