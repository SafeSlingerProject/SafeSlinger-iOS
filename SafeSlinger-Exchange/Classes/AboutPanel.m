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

#import "AboutPanel.h"
#import "KeySlingerAppDelegate.h"

@interface AboutPanel ()

@end

@implementation AboutPanel

@synthesize infoLabel, delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // display information on About  UI
    self.navigationItem.title = NSLocalizedString(@"title_About", @"About");
    NSString* msg1 = [NSString stringWithFormat: NSLocalizedString(@"text_About", @"%@ \n\nSafeSlinger is designed to easily share identity data, in person or over the phone, authenticated, private, and intact. \n\nFeatures: \n- Easily exchange contact information with others \n- Securely sling texts, photos, anything! \n- Strong cryptography protects your information \n\nemail: %@ \nweb: %@"), [NSString stringWithFormat: @"%@ v%@", NSLocalizedString(@"app_name", @"SafeSlinger"), delegate.getVersionNumber], @"safeslingerapp@gmail.com", @"www.cylab.cmu.edu/safeslinger"];
    NSString* msg2 = [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"text_LanguagesProvidedBy", @"Languages provided by:"), NSLocalizedString(@"app_TranslatorName", @"Michael Farb")];
    
    [infoLabel setText: [NSString stringWithFormat:@"%@\n\n%@\n%@", msg1, msg2, NSLocalizedString(@"text_Requirements", @"Requirements:\n1. Must be installed on a minimum of 2 devices.\n2. An Internet connection must be active.")]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
