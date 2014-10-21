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
#import <MessageUI/MessageUI.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

@class AppDelegate;
@class ContactEntry;

@interface ContactEntry : NSObject

@property (nonatomic, strong) NSString *fname, *lname, *keyid, *pushtoken, *keygenDate, *exchangeDate;
@property (nonatomic, strong) NSData *photo;
@property (nonatomic, readwrite) int devType, contact_id, ex_type;

-(NSString*)PrintContact;

@end



@protocol ContactSelectViewDelegate <NSObject>

- (void)contactSelected:(ContactEntry *)contact;

@end


typedef enum {
	ContactSelectionModeCompose,
	ContactSelectionModeIntroduce
} ContactSelectionMode;


@interface ContactSelectView : UITableViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate, UIActionSheetDelegate, ABPeoplePickerNavigationControllerDelegate, MFMessageComposeViewControllerDelegate, UIAlertViewDelegate>
{
    // used for show peers, each entry is a SSContactEntry object
    UIAlertView *UserInfo;
}

@property (nonatomic, retain) AppDelegate *appDelegate;
@property (nonatomic, strong) NSMutableArray *safeslingers;
@property (nonatomic, strong) UIAlertView *UserInfo;
@property (nonatomic, strong) ContactEntry *selectedUser;

@property (weak, nonatomic) IBOutlet UIView *tableHeaderView;
@property (weak, nonatomic) IBOutlet UILabel *hintLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *hintLabelHeightConstraint;
@property (weak, nonatomic) IBOutlet UISwitch *showRecentSwitch;
@property (weak, nonatomic) IBOutlet UILabel *showRecentLabel;
@property (weak, nonatomic) IBOutlet UIButton *addContactButton;

@property (weak, nonatomic) id<ContactSelectViewDelegate> delegate;
@property ContactSelectionMode contactSelectionMode;

- (IBAction) DisplayHow: (id)sender;

@end
