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
#import <MessageUI/MessageUI.h>

@class AppDelegate;
@class ContactEntry;

enum Dialogtype {
    User1Tag = 1,
    User2Tag
}UserTag;

@interface IntroduceView : UIViewController <MFMailComposeViewControllerDelegate, UIActionSheetDelegate>
{
    AppDelegate *delegate;
}

@property (nonatomic, strong) IBOutlet UIImageView *User1Photo;
@property (nonatomic, strong) IBOutlet UIImageView *User2Photo;
@property (nonatomic, strong) IBOutlet UILabel *HintLabel;
@property (nonatomic, strong) IBOutlet UILabel *ProgressLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *ProgressIndicator;
@property (nonatomic, strong) IBOutlet UIButton *IntroduceBtn;
@property (nonatomic, strong) IBOutlet UIButton *User1Btn;
@property (nonatomic, strong) IBOutlet UIButton *User2Btn;

@property (nonatomic, retain) AppDelegate *delegate;
@property (nonatomic, strong) ContactEntry *pickU1, *pickU2;
@property (nonatomic, strong) NSData *nonce1, *nonce2;
@property (nonatomic, strong) NSString *messageForU1, *messageForU2;

@property (nonatomic, readwrite) NSInteger pickUser;
@property (atomic, readwrite) BOOL U1Sent, U2Sent;

- (IBAction)SelectContact:(id)sender;
- (BOOL)EvaluateContact: (ContactEntry*)SelectContact;
- (void)SetupContact: (ContactEntry*)SelectContact;

@end
