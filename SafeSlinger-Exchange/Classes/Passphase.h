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

typedef enum PassStatus {
	NormalLogin = 0,
	UnsetPass,
	ChangePass
}PassStatus;

typedef enum AboutStatus {
	Help = 0,
	Feedback
}AboutStatus;

typedef enum SubmitAction {
	SelectKey = 0,
    LoginSubmit,
	AskHelp,
    CancelPassChange
}SubmitAction;

typedef enum InputField {
	Pass = 0,
    RePass
}InputField;

@class KeySlingerAppDelegate;

@interface Passphase : UIViewController <UITextFieldDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate>
{
    UILabel *VersionLabel;
    UITextField *PassField, *RepassField;
    UIButton *LoginBtn, *KeySelectBtn, *CancelBtn;
    KeySlingerAppDelegate *delegate;
    int mode, error_t, tout_bound;
    NSTimer *errTimer;
}

@property (nonatomic, retain) IBOutlet UIButton *CancelBtn;
@property (nonatomic, retain) IBOutlet UIButton *LoginBtn;
@property (nonatomic, retain) IBOutlet UIButton *KeySelectBtn;
@property (nonatomic, retain) IBOutlet UILabel *VersionLabel;
@property (nonatomic, retain) IBOutlet UITextField *PassField;
@property (nonatomic, retain) IBOutlet UITextField *RepassField;
@property (nonatomic, readwrite) int mode, error_t, tout_bound;
@property (weak) NSTimer *errTimer;
@property (nonatomic, readwrite) CGRect originalFrame;
@property (nonatomic, assign) KeySlingerAppDelegate *delegate;

-(IBAction)clickAction:(id)sender;
-(void)InitializePanel;
-(void)EncryptPrivateKeys: (NSString*) passphrase;

@end

@interface KeyChooser : UITableViewController <UITableViewDelegate, UITableViewDataSource>
{
    NSMutableArray* keyitem;
    NSMutableArray* keylist;
    Passphase *parent;
    KeySlingerAppDelegate *delegate;
}

@property (retain, nonatomic) NSMutableArray *keyitem;
@property (nonatomic, retain) NSMutableArray *keylist;
@property (nonatomic, assign) Passphase *parent;
@property (nonatomic, assign) KeySlingerAppDelegate *delegate;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil parent:(Passphase*)parentpanel;

@end
