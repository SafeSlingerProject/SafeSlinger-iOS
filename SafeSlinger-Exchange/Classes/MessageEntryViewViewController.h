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
#import <QuickLook/QuickLook.h>
#import <AddressBook/AddressBook.h>
#import <dispatch/dispatch.h>

@class KeySlingerAppDelegate;
@class MsgListEntry;
@class IntroWindow;

@interface MessageEntryViewViewController : UITableViewController <QLPreviewControllerDataSource, QLPreviewControllerDelegate, UIGestureRecognizerDelegate, UITextFieldDelegate>
{
    UIImage *b_img, *thread_img;
    MsgListEntry *assignedEntry;
    
    // For Grand Central Dispatch
    dispatch_queue_t BackGroundQueue;
    
    // For instand message response
    UITextField *InstandMessageField;
    UIButton *InstandMessageBtn;
    
    IntroWindow *intro_Window;
}

@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSURL *preview_cache_page;
@property (nonatomic, strong) QLPreviewController *previewer;
@property (nonatomic, strong) NSIndexPath *selectIndex;
@property (nonatomic) ABRecordRef tRecord;
@property (nonatomic, assign) KeySlingerAppDelegate *delegate;
@property (nonatomic, retain) UIImage *b_img;
@property (nonatomic, retain) UIImage *thread_img;
@property (nonatomic, retain) UITextField *InstandMessageField;
@property (nonatomic, retain) UIButton *InstandMessageBtn;
@property (nonatomic, retain) MsgListEntry *assignedEntry;
@property (nonatomic, retain) IntroWindow *intro_Window;
@property (nonatomic, retain) NSLock *ThreadLock;

- (void)AssignedEntry: (MsgListEntry*)UserEntry;
- (BOOL)IsCurrentThread: (NSString*)token;
- (void)ReloadTable;

@end
