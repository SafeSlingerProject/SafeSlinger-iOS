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

#import "FunctionView.h"
#import "VCardParser.h"
#import "RegistrationHandler.h"
#import "SSEngine.h"
#import "AppDelegate.h"

@interface FunctionView ()

@end

@implementation FunctionView

@synthesize LogoutBtn;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tappedRightButton:)];
    [swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tappedLeftButton:)];
    [swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [self.view addGestureRecognizer:swipeRight];
    
    [LogoutBtn setTitle:NSLocalizedString(@"menu_Logout", @"Logout")];
    
    UITabBarItem *item = [self.viewControllers objectAtIndex: 0];
    [item setTitle: NSLocalizedString(@"menu_TagListMessages", @"Messages")];
    item = [self.viewControllers objectAtIndex: 1];
    [item setTitle: NSLocalizedString(@"menu_TagComposeMessage", @"Compose")];
    item = [self.viewControllers objectAtIndex: 2];
    [item setTitle: NSLocalizedString(@"menu_TagExchange", @"Sling Keys")];
    item = [self.viewControllers objectAtIndex: 3];
    [item setTitle: NSLocalizedString(@"menu_Introduction", @"Introduction")];
    item = [self.viewControllers objectAtIndex: 4];
    [item setTitle: NSLocalizedString(@"menu_Settings", @"Settings")];
}

- (void)viewWillAppear:(BOOL)animated
{
    // check iCloud capability
    id currentiCloudToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
    if([[NSUserDefaults standardUserDefaults] integerForKey: kRemindBackup]==TurnOn && !currentiCloudToken)
    {
        // notifiy user to enable it
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                          message:NSLocalizedString(@"ask_BackupDisabledRemindLater", @"Backup is disabled. Do you want to adjust backup settings and keep this reminder?")
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"btn_Remind", @"Remind")
                                                otherButtonTitles:NSLocalizedString(@"btn_NotRemind", @"Forget"), nil];
        [message show];
        message = nil;
    }
    // Update registration if necessary
    [self registerDeviceInfo];
}

- (void)registerDeviceInfo
{
    RegistrationHandler *handler = [[RegistrationHandler alloc]init];
    NSString* hex_token = [[NSUserDefaults standardUserDefaults] stringForKey: kPUSH_TOKEN];
    int ver = [(AppDelegate*)[[UIApplication sharedApplication]delegate]getVersionNumberByInt];
    NSString* hex_subtoken = [SSEngine getSelfSubmissionToken];
    NSString* hex_keyid = [SSEngine getSelfKeyID];
    DEBUGMSG(@"%@ %@ %@", hex_token, hex_subtoken, hex_keyid);
    if(hex_token && hex_subtoken && hex_keyid)
    {
        DEBUGMSG(@"do registration.");
        [handler registerToken: hex_subtoken DeviceHex: hex_token KeyHex: hex_keyid ClientVer: ver];
    }
}

- (IBAction)Logout:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:TurnOff forKey: kRemindBackup];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    
}

- (void)tappedRightButton:(id)sender
{
    NSUInteger selectedIndex = [self selectedIndex];
    [self setSelectedIndex:selectedIndex + 1];
}

- (void)tappedLeftButton:(id)sender
{
    NSUInteger selectedIndex = [self selectedIndex];
    [self setSelectedIndex:selectedIndex - 1];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
