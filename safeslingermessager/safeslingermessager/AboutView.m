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

#import "AboutView.h"
#import "AppDelegate.h"

@interface AboutView ()

@end

@implementation AboutView

@synthesize InfoLabel;

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
    
    // display information on About  UI
    self.navigationItem.title = NSLocalizedString(@"title_About", @"About");
    self.navigationItem.rightBarButtonItem = nil;
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    NSString* msgHead = [NSString stringWithFormat: @"%@ v%@", NSLocalizedString(@"app_name", @"SafeSlinger"), delegate.getVersionNumber];
    NSString* msgAbout = NSLocalizedString(@"text_About", @"SafeSlinger is designed to easily share identity data, in person or over the phone, authenticated, private, and intact.");
    NSString* msgAbFeat = NSLocalizedString(@"text_AboutFeat", @"Features:");
    NSString* msgAb1 = NSLocalizedString(@"text_About1", @"Easily exchange contact information with others");
    NSString* msgAb2 = NSLocalizedString(@"text_About2", @"Securely sling texts, photos, anything!");
    NSString* msgAb3 = NSLocalizedString(@"text_About3", @"Strong cryptography protects your information");
    NSString* msgEmail = [NSString stringWithFormat: NSLocalizedString(@"text_AboutEmail", @"email: %@"), @"safeslingerapp@gmail.com"];
    NSString* msgWeb = [NSString stringWithFormat: NSLocalizedString(@"text_AboutWeb", @"web: %@"), @"www.cylab.cmu.edu/safeslinger"];
    NSString* msgSrc = [NSString stringWithFormat: NSLocalizedString(@"text_SourceCodeRepo", @"open source: %@"), @"github.com/safeslingerproject"];
    NSString* msgReq = NSLocalizedString(@"text_Requirements", @"Requirements:");
    NSString* msgReq1 = NSLocalizedString(@"text_Requirements1", @"Must be installed on a minimum of 2 devices.");
    NSString* msgReq2 = NSLocalizedString(@"text_Requirements2", @"An Internet connection must be active.");
    NSString* msgProg = NSLocalizedString(@"text_DevelopedBy", @"Developed by:");
    NSString* msgDevs = NSLocalizedString(@"app_DeveloperName", @"Bruno Nunes\nGurtej Singh Chandok\nJason Lee\nManish Burman\nMichael W Farb (Android Lead)\nVinay Ramkrishnan\nYue-Hsun Lin (iOS Lead)\n");
    NSString* msgLang = NSLocalizedString(@"text_LanguagesProvidedBy", @"Languages provided by:");
    NSString* msgTran = NSLocalizedString(@"app_TranslatorName", @"Adrian Perrig\nAkira Yamada\nAlbert Stroucken\nElli Fragkaki\nEmmanuel Owusu\nIrina Fudrow\nJens Höfflinger\nMichael Stroucken\nNicolas Christin\nSteve Matsumoto\nYeon Yim\nYue-Hsun Lin\n");
    
    [InfoLabel setText: [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n- %@\n- %@\n- %@\n\n%@\n1. %@\n2. %@\n\n%@\n%@\n%@\n\n%@\n%@\n%@\n%@", msgHead, msgAbout, msgAbFeat, msgAb1, msgAb2, msgAb3, msgReq, msgReq1, msgReq2, msgEmail, msgWeb, msgSrc, msgLang, msgTran, msgProg, msgDevs]];
    [InfoLabel sizeToFit];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
