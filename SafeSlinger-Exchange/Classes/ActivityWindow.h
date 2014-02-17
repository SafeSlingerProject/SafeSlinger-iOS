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

@interface ActivityWindow : UIViewController {
	UIActivityIndicatorView *indicator;
	UILabel *numberlable, *descriptionlable;
    UIProgressView *progress;
    KeySlingerAppDelegate *delegate;
}

@property (nonatomic, assign) KeySlingerAppDelegate *delegate;
@property (nonatomic, readwrite) BOOL isShow;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *indicator;
@property (nonatomic, retain) IBOutlet UILabel *numberlable;
@property (nonatomic, retain) IBOutlet UILabel *descriptionlable;
@property (nonatomic, retain) IBOutlet UIProgressView *progress;

-(void)EnableProgress: (NSString*)message SecondMeesage:(NSString*)topbar ProgessBar:(BOOL)showflag;
-(void)DisableProgress;
-(void)UpdateProgessBar: (float)rate;
-(void)UpdateProgessMsg: (NSString*)newMessage;

@end
