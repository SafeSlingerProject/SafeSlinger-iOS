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
#import <safeslingerexchange/safeslingerexchange.h>

#define _NEWLINE @"\n"
#define SAFESLINGER_DEBUG

@interface DemoViewController : UIViewController <UITextFieldDelegate, SafeSlingerDelegate>
{
    // safeslinger exchange object
    safeslingerexchange *proto;
}

@property (nonatomic, readwrite) CGRect originalFrame;
@property (nonatomic, readwrite) CGFloat textfieldOffset;
@property (nonatomic, strong) IBOutlet UITextView *infoPanel;
@property (nonatomic, strong) IBOutlet UIButton *exchangeButton;
@property (nonatomic, strong) IBOutlet UITextField *hostField;
@property (nonatomic, strong) IBOutlet UITextField *secretData;
@property (nonatomic, strong) IBOutlet UILabel *hostLabel;
@property (nonatomic, strong) IBOutlet UILabel *secretLabel;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;

@property (nonatomic, retain) safeslingerexchange *proto;

-(IBAction)BegineExchange:(id)sender;
-(IBAction)ShowHelp:(id)sender;

@end
