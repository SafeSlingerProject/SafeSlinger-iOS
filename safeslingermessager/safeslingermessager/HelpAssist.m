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

#import "HelpAssist.h"

@interface HelpAssist ()

@end

@implementation HelpAssist

@synthesize HelpView;

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
    
    self.navigationItem.title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"app_name", @"SafeSlinger"), NSLocalizedString(@"menu_Help", @"Help")];
    
    // load the assist view
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    // add key exhange assist information
    NSString *htmlString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"help" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_1" withString: [NSString stringWithFormat:@"%@ (%@)",  NSLocalizedString(@"label_step_1", @"Step 1"),  NSLocalizedString(@"menu_TagExchange", @"Sling Keys")]];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"label_step_2" withString: [NSString stringWithFormat:@"%@ (%@)",  NSLocalizedString(@"label_step_2", @"Step 2"),  NSLocalizedString(@"menu_TagComposeMessage", @"Compose")]];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"title_SecureIntroduction" withString:NSLocalizedString(@"title_SecureIntroduction", @"Secure Introduction")];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"menu_TagListMessages" withString:NSLocalizedString(@"menu_TagListMessages", @"Messages")];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_home" withString:NSLocalizedString(@"help_home", @"To exchange identity data, ensure all users are nearby or on the phone. The Begin Exchange button will exchange only the checked contact data.")];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_identity_menu" withString:NSLocalizedString(@"help_identity_menu", @"You may also change personal data about your identity on this screen by tapping on the button with your name. This will display a menu allowing you to Edit your contact, Create New contact, or Use Another contact.")];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_Send" withString:NSLocalizedString(@"help_Send", @"This screen allows you to select some data and a recipient to send to. Simply press Send when ready.")];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_Messages" withString:NSLocalizedString(@"help_Messages", @"This screen displays all past messages, and attachments that are still available for download.")];
    
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"help_SecureIntroduction" withString:NSLocalizedString(@"help_SecureIntroduction", @"This screen allows you to select two people you have slung keys with before to securely send their keys to each other. Simply press Introduce when ready.")];
    
    [HelpView loadHTMLString:htmlString baseURL:baseURL];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
