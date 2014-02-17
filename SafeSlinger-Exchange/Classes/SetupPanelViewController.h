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

@class KeySlingerAppDelegate;
@class ActivityWindow;

@interface SetupPanelViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
{
    KeySlingerAppDelegate *delegate;
    // UI Components
    UITextField *Fnamefield, *Lnamefield, *phonefield, *emailfield;
    UIButton *ptypeBtn, *etypeBtn, *lanuchBtn;
    UILabel *backinfo, *instruction;
    UILabel *label1, *label2, *label3;
    NSDictionary *etypes, *ptypes;
    int index, select_1, select_2, id_dummy, recoverytry;
    
    UIBarButtonItem *HelpBtn;
    
    // For Grand Central Dispatch
    dispatch_queue_t BGQueue;
}

@property (nonatomic, assign) KeySlingerAppDelegate *delegate;
@property (nonatomic, readwrite) CGRect originalFrame;
@property (nonatomic, retain) NSDictionary *etypes, *ptypes;
@property (nonatomic, readwrite) int index, select_1, select_2, id_dummy, recoverytry;

@property (nonatomic, retain) IBOutlet UITextField *Fnamefield;
@property (nonatomic, retain) IBOutlet UILabel *backinfo;
@property (nonatomic, retain) IBOutlet UILabel *instruction;
@property (nonatomic, retain) IBOutlet UILabel *label1;
@property (nonatomic, retain) IBOutlet UILabel *label2;
@property (nonatomic, retain) IBOutlet UILabel *label3;
@property (nonatomic, retain) IBOutlet UITextField *Lnamefield;
@property (nonatomic, retain) IBOutlet UITextField *phonefield;
@property (nonatomic, retain) IBOutlet UITextField *emailfield;
@property (nonatomic, retain) IBOutlet UIButton *ptypeBtn;
@property (nonatomic, retain) IBOutlet UIButton *etypeBtn;
@property (nonatomic, retain) UIBarButtonItem *HelpBtn;

- (IBAction)pickEmailType: (id)button;
- (IBAction)pickPhoneType: (id)button;
- (void)SetField: (int)Index;
- (void)NotifyFromBackup:(BOOL)result;
- (void)GrebCopyFromCloud;

@end

@interface TypeChooser : UITableViewController <UITableViewDelegate, UITableViewDataSource>
{
    NSMutableArray* typelist;
    SetupPanelViewController *parent;
    KeySlingerAppDelegate *delegate;
}

@property (retain, nonatomic) NSMutableArray *typelist;
@property (nonatomic, assign) SetupPanelViewController *parent;
@property (nonatomic, assign) KeySlingerAppDelegate *delegate;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil typeArray:(NSArray*)items parent:(SetupPanelViewController*)parentpanel;

@end
