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
#import "KeySlingerAppDelegate.h"
#import "iToast.h"

@implementation GroupingViewController

@synthesize AssignedID, LowestID, SubmitID, HintLabel;


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
    
	self.engine.users = self.users;
    
    [SubmitID setTitle:NSLocalizedString(@"btn_OK", @"OK") forState:UIControlStateNormal];
    [LowestID setPlaceholder:NSLocalizedString(@"label_UserIdHint", @"Lowest")];
    HintLabel.text = [NSString stringWithFormat: NSLocalizedString(@"label_PromptInstruct", @"This number is used to create a unique group of users. Compare, then enter the lowest number among all users.")];
    
    // customized cancel button
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc]initWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(ExitProtocol:)];
    [self.navigationItem setLeftBarButtonItem:cancelBtn];
    self.navigationItem.hidesBackButton = YES;
    [cancelBtn release];
    
    // ? button
    UIButton * infoButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0, 30.0f)];
    [infoButton setImage:[UIImage imageNamed:@"help.png"] forState:UIControlStateNormal];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HomeButton];
    [HomeButton release];
    HomeButton = nil;
    [infoButton release];
    infoButton = nil;
}

-(void) ExitProtocol: (id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_Question", @"Question")
                                                    message: NSLocalizedString(@"ask_QuitConfirmation", @"Quit? Are you sure?";)
                                                   delegate: self
                                          cancelButtonTitle: NSLocalizedString(@"btn_No", @"No")
                                          otherButtonTitles: NSLocalizedString(@"btn_Yes", @"Yes"), nil];
    alert.tag = 1;
    [alert show];
    [alert release];
    alert = nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex&&alertView.tag==1)
    {
        // exit protocol
        engine.state = ProtocolCancel;
        [engine protocolAbort:NSLocalizedString(@"error_WebCancelledByUser", @"User canceled server request.")];
    }
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_userid", @"Grouping";)
                                                      message:NSLocalizedString(@"help_userid", @"This number on this screen is used to create a unique group of users. Review the numbers on all users' screens, then all users should enter the same lowest number and press 'OK'.")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    [message release];
    message = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.engine startProtocol];
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)dealloc {
	[HintLabel release];
	[LowestID release];
	[AssignedID release];
	[SubmitID release];
    [super dealloc];
}

-(IBAction)SubmitLowestID
{
	int lowest_id = [[LowestID text] intValue];
	if (lowest_id == 0)
	{
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidCommonUserId", @"Please enter a positive integer.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
	}else{
        [LowestID resignFirstResponder];
        self.engine.minID = lowest_id;
        [self.engine sendMinID];
    }
}

@end
