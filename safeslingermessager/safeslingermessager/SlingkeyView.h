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

@import UIKit;
@import AddressBook;
@import AddressBookUI;
@import MessageUI;

#import <safeslingerexchange/safeslingerexchange.h>
#import "ContactManageView.h"

@class AppDelegate;

@interface SlingkeyView : UIViewController <UITableViewDelegate, UITableViewDataSource, SafeSlingerDelegate, MFMailComposeViewControllerDelegate> {
    AppDelegate *delegate;
    
    // safeslinger exchange object
    safeslingerexchange *proto;
}

@property (nonatomic, strong) IBOutlet UIButton *ContactChangeBtn;
@property (nonatomic, strong) IBOutlet UITableView *ContactInfoTable;
@property (nonatomic, strong) IBOutlet UIImageView *ContactImage;
@property (nonatomic, strong) IBOutlet UIButton *ExchangeBtn;
@property (nonatomic, strong) IBOutlet UILabel *DescriptionLabel;
@property (nonatomic, strong) NSMutableArray *contact_labels, *contact_values, *contact_selections, *contact_category;
@property (nonatomic, strong) NSMutableDictionary *label_dictionary;
@property (nonatomic, retain) AppDelegate *delegate;
@property (nonatomic, retain) safeslingerexchange *proto;
@property (nonatomic, readwrite) BOOL EndExchangeAlready;
@property (nonatomic, strong) NSMutableArray *GatherList;

@end
