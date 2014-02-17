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

#import "KeyAssistant.h"
#import "KeySlingerAppDelegate.h"

@interface KeyAssistant ()

@end

@implementation KeyAssistant

@synthesize helpView, hintLabel, displaySwitch, dismissBtn;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

-(IBAction)SwitchChanged
{
    int tmpvalue = (displaySwitch.on==YES ? 1 : 0);
    [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &tmpvalue length: sizeof(tmpvalue)]  withTag:@"label_ShowHintAtLaunch"];
}

-(IBAction)CloseHelp
{
    [delegate.navController popViewControllerAnimated:YES];
    delegate.contactView.isShowAssist = NO;
}

- (void)viewDidLoad
{
    // comment these codes because resources are not commited now.
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    
    self.navigationItem.title = NSLocalizedString(@"title_ExchangeWalkthrough", @"Sling Keys Assistant");
    hintLabel.text = NSLocalizedString(@"label_ShowHintAtLaunch", @"Show this hint next time.");
    [dismissBtn setTitle:NSLocalizedString(@"btn_Continue", @"Continue") forState:UIControlStateNormal];
    
    // load the assist view
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    // add key exhange assist information
    NSString *htmlString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"help" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_1" withString:NSLocalizedString(@"label_step_1", @"Step 1")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_2" withString:NSLocalizedString(@"label_step_2", @"Step 2")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_3" withString:NSLocalizedString(@"label_step_3", @"Step 3")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_4" withString:NSLocalizedString(@"label_step_4", @"Step 4")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_5" withString:NSLocalizedString(@"label_step_5", @"Step 5")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_home" withString:NSLocalizedString(@"help_home", @"To exchange identity data, ensure all users are nearby or on the phone. The 'Begin Exchange' button will exchange only the checked contact data.")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_size" withString:NSLocalizedString(@"help_size", @"Select the number of people who are attempting to exchange data together and press 'OK'.")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_userid" withString:NSLocalizedString(@"help_userid", @"This number on this screen is used to create a unique group of users. Review the numbers on all users' screens, then all users should enter the same lowest number and press 'OK'.")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_verify" withString:NSLocalizedString(@"help_verify", @"Now, you must match one of these 3-word phrases with all users. Every user must must select the same common phrase, and press 'Next'.")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_save" withString:NSLocalizedString(@"help_save", @"When finished, the protocol will reveal a list of the identity data exchanged. Select the contacts you wish to save and press 'Import'.")];
    [helpView loadHTMLString:htmlString baseURL:baseURL];
    self.navigationItem.hidesBackButton = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
