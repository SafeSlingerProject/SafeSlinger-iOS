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

@class SafeSlingerExchange;
@class KeySlingerAppDelegate;

@interface SaveSelectionViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate> {
	UITableView *selectionTable;
    UILabel *Hint;
    UIButton *ImportBtn;
	CFArrayRef contactList;
	SafeSlingerExchange *engine;
	BOOL *selections;
    KeySlingerAppDelegate *delegate;
}

@property (nonatomic, retain) IBOutlet UITableView *selectionTable;
@property (nonatomic, retain) IBOutlet UILabel *Hint;
@property (nonatomic, retain) IBOutlet UIButton *ImportBtn;
@property (nonatomic) CFArrayRef contactList;
@property (nonatomic, retain) SafeSlingerExchange *engine;
@property (nonatomic) BOOL *selections;
@property (nonatomic, assign) KeySlingerAppDelegate *delegate;

-(void) setup: (CFArrayRef)list engine: (SafeSlingerExchange *)anEngine;
-(IBAction) Import;

@end
