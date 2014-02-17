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

#import "ActivityWindow.h"
#import "KeySlingerAppDelegate.h"

@implementation ActivityWindow

@synthesize indicator, numberlable, descriptionlable, progress, delegate, isShow;


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.view.frame = [[UIScreen mainScreen] applicationFrame];
    delegate = [[UIApplication sharedApplication]delegate];
	[indicator startAnimating];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

-(void)EnableProgress: (NSString*)message SecondMeesage:(NSString*)topbar ProgessBar:(BOOL)showflag
{
    isShow = YES;
    self.view.frame = CGRectMake(20, 90, 280, 300);
	numberlable.text = topbar;
	descriptionlable.text = message;
    if(showflag){
        progress.progress = 0.0f;
        [progress setHidden:NO];
    }
    [delegate.window addSubview:delegate.activityView.view];
}

-(void)DisableProgress
{
    isShow = NO;
    progress.progress = 0.0f;
    [progress setHidden:YES];
    [self.view removeFromSuperview];
}

-(void)UpdateProgessBar: (float)rate
{
    numberlable.text = [NSString stringWithFormat: @"%d/100%%", (int)(rate*100)];
    progress.progress = rate;
}

-(void)UpdateProgessMsg: (NSString*)newMessage
{
    descriptionlable.text = newMessage;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (void)dealloc {
	[indicator release];
	[numberlable release];
	[descriptionlable release];
    [progress release];
    [super dealloc];
}


@end
