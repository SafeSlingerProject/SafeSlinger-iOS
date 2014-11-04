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

#import "ContactSelectView.h"
#import "Utility.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "ContactCellView.h"
#import "IntroduceView.h"
#import "ComposeView.h"
#import "IntroduceView.h"
#import "FunctionView.h"
#import "BackupCloud.h"

#import <safeslingerexchange/iToast.h>

typedef enum {
	InviteContactActionSheetTextFromContacts = 0,
	InviteContactActionSheetEmailFromContacts,
	InviteContactActionSheetUseAnother
} InviteContactActionSheet;

@interface ContactEntry ()

@end

@implementation ContactEntry
@synthesize fname, lname, photo, pushtoken, keyid, devType, keygenDate, exchangeDate, contact_id, ex_type;

-(NSString*)PrintContact {
    // plaintext
    NSMutableString* detail = [NSMutableString stringWithCapacity:0];
    
    [detail appendFormat:@"Name:%@\n", [NSString composite_name: fname withLastName: lname]];
    [detail appendFormat:@"KeyID:%@\n", keyid];
    [detail appendFormat:@"KeyGenDate:%@\n", keygenDate];
    [detail appendFormat:@"PushToken:%@\n", pushtoken];
    
    switch (ex_type) {
        case Exchanged:
            [detail appendFormat:@"Type: %@\n", NSLocalizedString(@"label_exchanged", @"exchanged")];
            break;
        case Introduced:
            [detail appendFormat:@"Type: %@\n", NSLocalizedString(@"label_introduced", @"introduced")];
            break;
        default:
            break;
    }
    
    [detail appendFormat:@"Exchange(Introduce) Date:%@\n", exchangeDate];
    
    switch (devType) {
        case Android:
            [detail appendString:@"DEV: Android\n"];
            break;
        case iOS:
            [detail appendString:@"DEV: iOS\n"];
            break;
        default:
            [detail appendFormat:@"DEV: %d", devType];
            break;
    }
    
    return detail;
}

@end

@interface ContactSelectView ()

@property (nonatomic) InviteContactActionSheet selectedInviteType;
@property (nonatomic, strong) ABPeoplePickerNavigationController *addressBookController;
@property (nonatomic, strong) NSMutableArray *actionSheetButtons;

@property (nonatomic, strong) NSMutableArray *contacts;
@property (nonatomic, strong) NSMutableArray *filteredContacts;

@end

@implementation ContactSelectView

@synthesize appDelegate;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    appDelegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
	
	[self setupActionSheetButtons];
	[self DisplayTitle];
	
	[_showRecentLabel setText:NSLocalizedString(@"label_MostRecentOnly", @"Most recent only")];
	
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 1.0; //seconds
    lpgr.delegate = self;
    [self.tableView addGestureRecognizer:lpgr];
	
    UserInfo = [[UIAlertView alloc]
                initWithTitle: NSLocalizedString(@"title_RecipientDetail", @"Recipient Detail")
                message:nil
                delegate:self
                cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                otherButtonTitles:NSLocalizedString(@"btn_Close", @"Close"), nil];
	
	_showRecentSwitch.on = YES;
	
	_contacts = [NSMutableArray new];
	[_contacts setArray:[appDelegate.DbInstance LoadRecentRecipients:NO]];
	_filteredContacts = [NSMutableArray new];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillShow:)
												 name:UIKeyboardWillShowNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];
	
	// hack to fix UITableView initially not scrolling on iOS 6
	[self searchBar:_searchBar textDidChange:_searchBar.text];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillShowNotification
												  object:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIKeyboardWillHideNotification
												  object:nil];
}

- (void)setupActionSheetButtons {
	_actionSheetButtons = [NSMutableArray new];
	
	if([MFMessageComposeViewController canSendText]) {
		[_actionSheetButtons addObject:NSLocalizedString(@"menu_ContactInviteSms", nil)];
	}
	
	if([MFMailComposeViewController canSendMail]) {
		[_actionSheetButtons addObject:NSLocalizedString(@"menu_ContactInviteEmail", nil)];
	}
	
	[_actionSheetButtons addObject:NSLocalizedString(@"menu_UseAnother", nil)];
}

- (void)reloadTable {
	[self updateTableViewHeader];
	[self.tableView reloadData];
}

- (void)updateTableViewHeader {
	CGFloat originalHintLabelHeight = CGRectGetHeight(_hintLabel.frame);
	
	if([_contacts count] > 0) {
		if(_filteredContacts.count > 0) {
			_showRecentSwitch.hidden = NO;
			_showRecentLabel.hidden = NO;
			
			if (_contactSelectionMode == ContactSelectionModeCompose) {
				[_hintLabel setText:NSLocalizedString(@"label_InstRecipients", nil)];
			} else {
				[_hintLabel setText: NSLocalizedString(@"label_InstSendInvite", nil)];
			}
			
			[_hintLabel sizeToFit];
			_hintLabelHeightConstraint.constant = CGRectGetHeight(_hintLabel.frame);
		} else {
			_showRecentSwitch.hidden = YES;
			_showRecentLabel.hidden = YES;
			
			[_hintLabel setText: NSLocalizedString(@"label_InstNoRecipientsMatchQuery", nil)];
			
			[_hintLabel sizeToFit];
			_hintLabelHeightConstraint.constant = CGRectGetHeight(_hintLabel.frame);
		}
	} else {
		_showRecentSwitch.hidden = YES;
		_showRecentLabel.hidden = YES;
		
		[_hintLabel setText: NSLocalizedString(@"label_InstNoRecipients", nil)];
		
		[_hintLabel sizeToFit];
		_hintLabelHeightConstraint.constant = CGRectGetHeight(_hintLabel.frame);
	}
	
	CGRect frame = _tableHeaderView.frame;
	frame.size.height += CGRectGetHeight(_hintLabel.frame) - originalHintLabelHeight;
	_tableHeaderView.frame = frame;
	
	self.tableView.tableHeaderView = _tableHeaderView;
}

- (void)DisplayTitle {
    if(ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = NULL;
        
        aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if(!granted) {
            }
        });
        
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
        long total = CFArrayGetCount(allPeople)-1;
        if(allPeople)CFRelease(allPeople);
        if(aBook)CFRelease(aBook);
        
        self.navigationItem.title = [NSString stringWithFormat: @"%@(%lu/%ld)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), (unsigned long)[_contacts count], total];
    } else {
        self.navigationItem.title = [NSString stringWithFormat: @"%@(%lu)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), (unsigned long)[_contacts count]];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    
    if (indexPath) {
        ContactEntry *sc = _filteredContacts[indexPath.row];
        [UserInfo setMessage: [sc PrintContact]];
        [UserInfo show];
    }
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if(buttonIndex!=alertView.cancelButtonIndex) {
		[UtilityFunc SendOpts:self];
	}
}

#pragma mark - Keyboard handling methods

- (void)keyboardWillShow:(NSNotification *)notification {
	self.navigationItem.rightBarButtonItem = _doneButton;
}

- (void)keyboardWillHide:(NSNotification *)notification {
	self.navigationItem.rightBarButtonItem = _infoButton;
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _filteredContacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ContactCell";
    ContactCellView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    ContactEntry *entry = _filteredContacts[indexPath.row];
    cell.NameLabel.text = [NSString composite_name:entry.fname withLastName:entry.lname];
    cell.KeyIDLabel.text = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"label_PublicKeyID", @"Key ID"), entry.keyid];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:DATABASE_TIMESTR];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDate *exchange = [formatter dateFromString: entry.exchangeDate];
    NSDate *keygen = [formatter dateFromString: entry.keygenDate];
    [formatter setDateFormat:@"dd MMM yyyy"];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    NSString* exchangedate = [formatter stringFromDate:exchange];
    NSString* gendate = [formatter stringFromDate:keygen];
    
    cell.KeygenLabel.text = [NSString stringWithFormat: @"%@ %@", NSLocalizedString(@"label_Key", @"Key:"), gendate];
    
	if(entry.ex_type==Exchanged) {
        cell.ExchangeLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_exchanged", @"exchanged"), exchangedate];
	} else {
        cell.ExchangeLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_introduced", @"introduced"), exchangedate];
	}
	
    switch (entry.devType) {
        case Android:
            cell.DeviceLabel.text = NSLocalizedString(@"label_AndroidOS", @"Android");
            break;
        case iOS:
            cell.DeviceLabel.text = NSLocalizedString(@"label_iOS", @"iOS");
            break;
        default:
            cell.DeviceLabel.text = NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown");
            break;
    }
    
    if(entry.photo) {
        [cell.UserPhoto setImage: [UIImage imageWithData:entry.photo]];
    } else {
        [cell.UserPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
    }
    
	return cell;
}

- (IBAction)showRecentValueChanged:(UISwitch *)sender {
    // reload
    [_contacts removeAllObjects];
	[_filteredContacts removeAllObjects];
	
	if(sender.on) {
        [_contacts addObjectsFromArray:[appDelegate.DbInstance LoadRecentRecipients:NO]];
    } else {
        [_contacts addObjectsFromArray:[appDelegate.DbInstance LoadRecipients:NO]];
	}
	
	[_filteredContacts addObjectsFromArray:_contacts];
	
	[self reloadTable];
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        ContactEntry *sc = _filteredContacts[indexPath.row];
        [appDelegate.DbInstance RemoveRecipient: sc.keyid];
        [_filteredContacts removeObjectAtIndex:indexPath.row];
		[_contacts removeObject:sc];
        
        // show hint to user
        [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_RecipientsDeleted", @"%d recipients deleted."), 1]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
		
        // Try to backup
        [appDelegate.BackupSys RecheckCapability];
        [appDelegate.BackupSys PerformBackup];
		
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
		
		if (_contacts.count == 0) {
			[self reloadTable];
		}
		
		[self DisplayTitle];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if(self.delegate) {
		[self.delegate contactSelected:[_filteredContacts objectAtIndex: indexPath.row]];
	}
    
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"menu_ContactInviteSms", nil)]) {
		_selectedInviteType = InviteContactActionSheetTextFromContacts;
		
		[self showAddressBook];
	} else if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"menu_ContactInviteEmail", nil)]) {
		_selectedInviteType = InviteContactActionSheetEmailFromContacts;
		
		[self showAddressBook];
	} else if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"menu_UseAnother", nil)]) {
		UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:[self shortInviteMessage]] applicationActivities:nil];
		[self presentViewController:activityController animated:YES completion:nil];
	}
}

- (void)showAddressBook {
	ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
	
	if(status == kABAuthorizationStatusNotDetermined) {
		UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", nil)
														  message: NSLocalizedString(@"iOS_RequestPermissionContacts", nil)
														 delegate: self
												cancelButtonTitle: NSLocalizedString(@"btn_NotNow", nil)
												otherButtonTitles: NSLocalizedString(@"btn_Continue", nil), nil];
		message.tag = AskPerm;
		[message show];
	} else if(status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
		NSString* buttontitle = nil;
		
		if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
			buttontitle = NSLocalizedString(@"menu_Help", nil);
		} else {
			buttontitle = NSLocalizedString(@"menu_Settings", nil);
		}
		
		UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", nil)
														  message: [NSString stringWithFormat: NSLocalizedString(@"iOS_contactError", nil), buttontitle]
														 delegate: self
												cancelButtonTitle: NSLocalizedString(@"btn_Cancel", nil)
												otherButtonTitles: buttontitle, nil];
		message.tag = HelpContact;
		[message show];
	} else if(status == kABAuthorizationStatusAuthorized) {
		_addressBookController = [[ABPeoplePickerNavigationController alloc] init];
		[_addressBookController setPeoplePickerDelegate:self];
		
		if(_selectedInviteType == InviteContactActionSheetTextFromContacts) {
			[_addressBookController setDisplayedProperties:@[@(kABPersonPhoneProperty)]];
		} else {
			[_addressBookController setDisplayedProperties:@[@(kABPersonEmailProperty)]];
		}
		
		[self presentViewController:_addressBookController animated:YES completion:nil];
	}
}

#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	
	if(buttonIndex != alertView.cancelButtonIndex){
		switch (alertView.tag) {
			case AskPerm:
				[UtilityFunc TriggerContactPermission];
				break;
			case HelpContact:
				if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
					[[UIApplication sharedApplication] openURL:[NSURL URLWithString:kContactHelpURL]];
				} else {
					// iOS8
					NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
					[[UIApplication sharedApplication] openURL:url];
				}
				break;
			default:
				break;
		}
	}
}

#pragma mark - ABPeoplePickerNavigationControllerDelegate methods

- (void)peoplePickerNavigationControllerDidCancel: (ABPeoplePickerNavigationController *)peoplePicker {
	[peoplePicker dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person property: (ABPropertyID)property identifier: (ABMultiValueIdentifier)identifier {
	[self peoplePickerNavigationController:peoplePicker didSelectPerson:person property:property identifier:identifier];
	return NO;
}

- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	UIViewController *viewController;
	
	if(_selectedInviteType == InviteContactActionSheetTextFromContacts) {
		
		ABMultiValueRef phoneProperty = ABRecordCopyValue(person,property);
		NSString *phone = (__bridge NSString *)ABMultiValueCopyValueAtIndex(phoneProperty,identifier);
		
		MFMessageComposeViewController *controller = [[MFMessageComposeViewController alloc] init];
		controller.messageComposeDelegate = self;
		controller.body = [self shortInviteMessage];
		controller.recipients = [NSArray arrayWithObjects:phone, nil];
		
		viewController = controller;
		
	} else if(_selectedInviteType == InviteContactActionSheetEmailFromContacts) {
		
		ABMultiValueRef emailProperty = ABRecordCopyValue(person,property);
		NSString *email = (__bridge NSString *)ABMultiValueCopyValueAtIndex(emailProperty, identifier);
		
		// Email Subject
		NSString *emailTitle = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"title_TextInviteMsg", nil), NSLocalizedString(@"menu_TagExchange", nil)];
		// Email Content
		NSString *messageBody = [self longInviteMessage];
		// To address
		NSArray *toRecipents = [NSArray arrayWithObject:email];
		
		MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
		mc.mailComposeDelegate = self;
		[mc setSubject:emailTitle];
		[mc setMessageBody:messageBody isHTML:NO];
		[mc setToRecipients:toRecipents];
		
		viewController = mc;
	}
	
	[peoplePicker dismissViewControllerAnimated:YES completion:^{
		[self presentViewController:viewController animated:YES completion:nil];
	}];
}

#pragma mark - MFMessageComposeViewControllerDelegate methods

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
	[controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - MFMailComposeViewControllerDelegate methods

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
	switch (result) {
		case MFMailComposeResultCancelled:
		case MFMailComposeResultSaved:
		case MFMailComposeResultSent:
			break;
		case MFMailComposeResultFailed:
			// toast message
			[[[[iToast makeText: NSLocalizedString(@"error_CorrectYourInternetConnection", nil)]
			   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
			break;
		default:
			break;
	}
	
	[self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Invite messages

- (NSString *)shortInviteMessage {
	return [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"label_messageInviteStartMsg", nil), NSLocalizedString(@"label_messageInviteSetupInst", nil), [NSString stringWithFormat:NSLocalizedString(@"label_messageInviteInstall", nil), kHelpURL]];
}

- (NSString *)longInviteMessage {
	return [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n", NSLocalizedString(@"label_messageInviteStartMsg", nil), NSLocalizedString(@"label_messageInviteSetupInst", nil), [NSString stringWithFormat:NSLocalizedString(@"label_messageInviteInstall", nil), kHelpURL]];
}

#pragma mark - UISearchBarDelegate methods

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	[_filteredContacts removeAllObjects];
	
	if(searchText.length == 0) {
		[_filteredContacts addObjectsFromArray:_contacts];
	} else {
		for(ContactEntry *contact in _contacts) {
			NSRange rangeFirstName = [contact.fname rangeOfString:searchText options:NSCaseInsensitiveSearch];
			NSRange rangeLastName = [contact.lname rangeOfString:searchText options:NSCaseInsensitiveSearch];
			
			if(rangeFirstName.length != 0 || rangeLastName.length != 0) {
				[_filteredContacts addObject:contact];
			}
		}
	}
	
	[self reloadTable];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

#pragma mark - IBAction methods

- (IBAction)addContactTouched:(UIButton *)sender {
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"action_NewUserRequest", nil)
															 delegate:self
													cancelButtonTitle:nil
											   destructiveButtonTitle:nil
													otherButtonTitles:nil];
	
	for(NSString *button in _actionSheetButtons) {
		[actionSheet addButtonWithTitle:button];
	}
	actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"btn_Cancel", nil)];
	
	[actionSheet showFromRect:sender.frame inView:self.view animated:YES];
}

- (IBAction)doneButtonTouched:(UIBarButtonItem *)sender {
	[_searchBar resignFirstResponder];
}

- (IBAction)infoButtonTouched:(UIButton *)sender {
	UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_PickRecipient", @"Recipients")
													  message:NSLocalizedString(@"help_PickRecip", @"Contacts with SafeSlinger keys are displayed here, select one to send your message to.")
													 delegate:self
											cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
											otherButtonTitles:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"), nil];
	[message show];
}

#pragma mark - Utils

- (void)showMessage:(NSString *)message withTitle:(NSString *)title {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
													  message:message
													 delegate:self
											cancelButtonTitle:NSLocalizedString(@"btn_OK", nil)
											otherButtonTitles:nil];
	[alert show];
}

@end
