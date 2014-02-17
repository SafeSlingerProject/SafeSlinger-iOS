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
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

@class KeySlingerAppDelegate;
@class KeyAssistant;

@interface ContactViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate, ABPeoplePickerNavigationControllerDelegate, ABPersonViewControllerDelegate, ABNewPersonViewControllerDelegate>
{
    // UI Componenets
    KeyAssistant *helper;
	UIButton *ContactChangeBtn;
    UIButton *ExchangeBtn;
	UITableView *ContactInfoTable;
	UIImageView *ContactImage;
    UILabel *DescriptionLabel;
	
    // data structures for vCard
	NSMutableDictionary *label_dictionary;
    NSMutableArray *contact_labels, *contact_values, *contact_category, *contact_selections;
	
	BOOL isShowAssist;
    KeySlingerAppDelegate *delegate;
}

@property (nonatomic, retain) KeyAssistant *helper;
@property (nonatomic, retain) IBOutlet UIButton *ContactChangeBtn;
@property (nonatomic, retain) IBOutlet UITableView *ContactInfoTable;
@property (nonatomic, retain) IBOutlet UIImageView *ContactImage;
@property (nonatomic, retain) IBOutlet UIButton *ExchangeBtn;
@property (nonatomic, retain) IBOutlet UILabel *DescriptionLabel;

@property (nonatomic, retain) NSMutableArray *contact_labels, *contact_values, *contact_selections, *contact_category;
@property (nonatomic, retain) NSMutableDictionary *label_dictionary;

@property (nonatomic, retain) KeySlingerAppDelegate *delegate;
@property (nonatomic, readwrite) BOOL isShowAssist;

// Action method when user presses Exchange Button
-(IBAction) BeginExchange;
// Action method when user presses Contact Button
-(IBAction) ChangeContact;

@end
