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

#import "GroupingViewController.h"
#import "SafeSlinger.h"
#import "safeslingerexchange.h"
#import "iToast.h"

@implementation GroupingViewController

@synthesize AssignedID, LowestID, SubmitID, HintLabel, CompareLabel, delegate;


 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [SubmitID setTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_OK", @"OK") forState:UIControlStateNormal];
    [LowestID setPlaceholder:NSLocalizedStringFromBundle(delegate.res, @"label_UserIdHint", @"Lowest")];
    [HintLabel setText: NSLocalizedStringFromBundle(delegate.res, @"label_PromptInstruct", @"This number is used to create a unique group of users. Compare, then enter the lowest number among all users.")];
    
    // customized cancel button
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc]initWithTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_Cancel", @"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(ExitProtocol:)];
    [self.navigationItem setLeftBarButtonItem:cancelBtn];
    self.navigationItem.hidesBackButton = YES;
    
    // ? button
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HomeButton];
    
    _originalFrame = self.view.frame;
}

-(void) ExitProtocol: (id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromBundle(delegate.res, @"title_Question", @"Question")
                                                    message: NSLocalizedStringFromBundle(delegate.res, @"ask_QuitConfirmation", @"Quit? Are you sure?")
                                                   delegate: self
                                          cancelButtonTitle: NSLocalizedStringFromBundle(delegate.res, @"btn_No", @"No")
                                          otherButtonTitles: NSLocalizedStringFromBundle(delegate.res, @"btn_Yes", @"Yes"), nil];
    [alert show];
    alert = nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex)
    {
        // exit protocol
        delegate.protocol.state = ProtocolCancel;
        [delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_WebCancelledByUser", @"User canceled server request.")];
    }
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromBundle(delegate.res, @"title_userid", @"Grouping")
                                                      message: NSLocalizedStringFromBundle(delegate.res, @"help_userid", @"This number on this screen is used to create a unique group of users. Review the numbers on all users' screens, then all users should enter the same lowest number and press 'OK'.")
                                                     delegate:nil
                                            cancelButtonTitle: NSLocalizedStringFromBundle(delegate.res, @"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    message = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    // decide after user input
    [CompareLabel setText:[NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"label_CompareScreensNDevices", @"Compare screens on %@ devices.."), [NSString stringWithFormat:@"%d", delegate.protocol.users]]];
    [LowestID resignFirstResponder];
    
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
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)keyboardWillShown:(NSNotification *)notification
{
    UIScrollView* scrollView = (UIScrollView*)self.view;
    // make it scrollable
    if(self.view.frame.size.height<568.0f)
        scrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height*1.2);
    else
        scrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height*1.1);
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    UIScrollView* scrollView = (UIScrollView*)self.view;
    scrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height);
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
}


-(IBAction)SubmitLowestID
{
	int lowest_id = [[LowestID text] intValue];
	if (lowest_id == 0)
	{
        [[[[iToast makeText: NSLocalizedStringFromBundle(delegate.res, @"error_InvalidCommonUserId", @"Please enter a positive integer.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
	}else{
        [LowestID resignFirstResponder];
        delegate.protocol.minID = lowest_id;
        [delegate.protocol sendMinID];
    }
}

@end
