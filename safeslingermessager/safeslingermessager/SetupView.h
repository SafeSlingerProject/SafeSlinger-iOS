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

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "BackupCloud.h"

@class AppDelegate;

enum Dialogtype {
    PushNotificationConfirm,
    HelpAndFeedBack
}Dialogtype;

@interface SetupView : UIViewController <UITextFieldDelegate, BackupDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
{
    // For Grand Central Dispatch
    dispatch_queue_t _bg_queue;
    AppDelegate *delegate;
}

@property (nonatomic, strong) IBOutlet UITextField *PassField;
@property (nonatomic, strong) IBOutlet UITextField *RepassField;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *DoneBtn;
@property (nonatomic, strong) IBOutlet UITextField *Fnamefield;
@property (nonatomic, strong) IBOutlet UITextField *Lnamefield;
@property (nonatomic, strong) IBOutlet UILabel *backinfo;
@property (nonatomic, strong) IBOutlet UILabel *instruction;
@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *passphraseLabel;
@property (nonatomic, strong) IBOutlet UIProgressView *keygenProgress;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *keygenIndicator;
@property (nonatomic, strong) IBOutlet UIScrollView *Scrollview;
@property (nonatomic, strong) IBOutlet UIButton *LicenseBtn;
@property (nonatomic, strong) IBOutlet UIButton *PrivacyBtn;
@property (nonatomic, readwrite) CGRect originalFrame;
@property (nonatomic, readwrite) CGFloat textfieldOffset;

@property (nonatomic, retain) AppDelegate *delegate;
@property (nonatomic, readwrite) BOOL newkeycreated;

- (IBAction) DisplayHelp: (id)sender;
- (IBAction) CreateProfile: (id)sender;
- (IBAction) ClickPrivacy:(id)sender;
- (IBAction) ClickLicense:(id)sender;

@end
