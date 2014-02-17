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

@interface WordListViewController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource, UIAlertViewDelegate> {
    
	NSArray *word_lists, *even_words, *odd_words;
	NSMutableArray *wordlist_labels, *numberlist_labels;
	int correct_index, selected_index;
    KeySlingerAppDelegate* delegate;
    SafeSlingerExchange *engine;
    UILabel *HintLabel, *NumbericHintLabel;
    UIButton *MatchBtn, *NotmatchBtn;
    UISwitch *NumbericSwitch;
    UIPickerView *WordListRoller;
}

@property (nonatomic, retain) IBOutlet UILabel *HintLabel;
@property (nonatomic, retain) IBOutlet UIButton *MatchBtn;
@property (nonatomic, retain) IBOutlet UIButton *NotmatchBtn;
@property (nonatomic, retain) IBOutlet UILabel *NumbericHintLabel;
@property (nonatomic, retain) IBOutlet UISwitch *NumbericSwitch;
@property (nonatomic, retain) IBOutlet UIPickerView *WordListRoller;

@property (nonatomic, retain) NSArray *word_lists, *even_words, *odd_words;
@property (nonatomic, retain) NSMutableArray *wordlist_labels, *numberlist_labels;
@property (nonatomic, retain) SafeSlingerExchange *engine;
@property (nonatomic) int correct_index, selected_index;
@property (nonatomic, assign) KeySlingerAppDelegate *delegate;

-(IBAction) ButtonPressed: (id)sender;
-(IBAction) SwitchNumbericTextMode: (id)sender;
-(void) generateWordList: (NSData*)hash_data;

@end
