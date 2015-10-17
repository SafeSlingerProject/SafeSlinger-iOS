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

#import "ContactSelectView.h"
#import "Utility.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "ContactCellView.h"
#import "IntroduceView.h"
#import "IntroduceView.h"
#import "FunctionView.h"
#import "BackupCloud.h"

#import <safeslingerexchange/iToast.h>

typedef enum {
	InviteContactActionSheetTextFromContacts = 0,
	InviteContactActionSheetEmailFromContacts,
	InviteContactActionSheetUseAnother
} InviteContactActionSheet;

@interface ContactSelectView ()

@property (nonatomic) InviteContactActionSheet selectedInviteType;
@property (nonatomic, strong) ABPeoplePickerNavigationController *addressBookController;
@property (nonatomic, strong) NSMutableArray *actionSheetButtons;

@property (nonatomic, strong) NSMutableArray *contacts;
@property (nonatomic, strong) NSMutableArray *filteredContacts;

@property (nonatomic) NSUInteger selectedContactIndex;

@end

@implementation ContactSelectView

- (void)viewDidLoad {
    [super viewDidLoad];
    
	_appDelegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
	
	[self setupActionSheetButtons];
	
	[_showRecentLabel setText:NSLocalizedString(@"label_MostRecentOnly", @"Most recent only")];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 2.0; //seconds
    lpgr.delegate = self;
    [self.tableView addGestureRecognizer:lpgr];
	
	_showRecentSwitch.on = YES;
	
	_contacts = [NSMutableArray new];
	[_contacts setArray:[_appDelegate.DbInstance LoadRecentRecipients:NO]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contactEdited:)
												 name:NSNotificationContactEdited
											   object:nil];

	_filteredContacts = [NSMutableArray new];
    [self displayTitle];
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

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (void)displayTitle {
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
        
        self.navigationItem.title = [NSString stringWithFormat:@"%@(%lu/%ld)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), (unsigned long)[_contacts count], total];
    } else {
        self.navigationItem.title = [NSString stringWithFormat:@"%@(%lu)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), (unsigned long)[_contacts count]];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
	if(gestureRecognizer.state != UIGestureRecognizerStateBegan) {
		return;
	}
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    
    if (indexPath) {
        ContactEntry *sc = _filteredContacts[indexPath.row];
		_selectedContactIndex = [_contacts indexOfObject:sc];
		
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_RecipientDetail", @"Recipient Detail")
                                                                       message:[sc printContact]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* closeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action){
                                                                 
                                                             }];
        [alert addAction:closeAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
	if([segue.identifier isEqualToString:@"EditContactSegue"]) {
		ContactManageView *viewController = (ContactManageView *)segue.destinationViewController;
		viewController.editingContact = _contacts[_selectedContactIndex];
	}
}

#pragma mark - NSNotification methods

- (void)contactEdited:(NSNotification *)notification {
	if(notification.userInfo[NSNotificationContactEditedObject]) {
		[self reloadTable];
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
    cell.NameLabel.text = [NSString compositeName:entry.firstName withLastName:entry.lastName];
	
	cell.contactInfoButton.tag = indexPath.row;
    
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
    
	if(entry.exchangeType == Exchanged) {
        cell.ExchangeLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_exchanged", @"exchanged"), exchangedate];
	} else {
        cell.ExchangeLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_introduced", @"introduced"), exchangedate];
	}
	
    switch (entry.devType) {
        case Android_C2DM:
        case Android_GCM:
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
        [_contacts addObjectsFromArray:[_appDelegate.DbInstance LoadRecentRecipients:NO]];
    } else {
        [_contacts addObjectsFromArray:[_appDelegate.DbInstance LoadRecipients:NO]];
	}
	
	[_filteredContacts addObjectsFromArray:_contacts];
	
	[self reloadTable];
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        ContactEntry *contact = _filteredContacts[indexPath.row];
        [_appDelegate.DbInstance RemoveRecipient:contact.keyId];
        [_filteredContacts removeObjectAtIndex:indexPath.row];
		[_contacts removeObject:contact];
        
        // show hint to user
        [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_RecipientsDeleted", @"%d recipients deleted."), 1]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
		
        // Try to backup
        [_appDelegate.BackupSys RecheckCapability];
        [_appDelegate.BackupSys PerformBackup];
		
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
        if (_contactSelectionMode == ContactSelectionModeIntroduce) {
            [_delegate contactDeleted:contact];
        }
		
		if (_contacts.count == 0) {
			[self reloadTable];
		}
		
		[self displayTitle];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if(self.delegate) {
		[self.delegate contactSelected:[_filteredContacts objectAtIndex: indexPath.row]];
	}
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)showAddressBook {
	ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
	
	if(status == kABAuthorizationStatusNotDetermined) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", nil)
                                                                       message:NSLocalizedString(@"iOS_RequestPermissionContacts", nil)
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_NotNow", nil)
                                                              style:UIAlertActionStyleCancel
                                                            handler:^(UIAlertAction * action){
                                                                
                                                            }];
        UIAlertAction* contAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Continue", nil)
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action){
                                                                [UtilityFunc TriggerContactPermission];
                                                            }];
        [alert addAction:contAction];
        [alert addAction:cancelAction];
        [self presentViewController:alert animated:YES completion:nil];
	} else if(status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", nil)
                                                                       message:[NSString stringWithFormat: NSLocalizedString(@"iOS_contactError", nil), NSLocalizedString(@"menu_Settings", nil)]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", nil)
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * action){
                                                                 [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                                                             }];
        UIAlertAction* setAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_Settings", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action){
                                                               [UtilityFunc TriggerContactPermission];
                                                           }];
        [alert addAction:setAction];
        [alert addAction:cancelAction];
        [self presentViewController:alert animated:YES completion:nil];
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
			NSRange rangeFirstName = [contact.firstName rangeOfString:searchText options:NSCaseInsensitiveSearch];
			NSRange rangeLastName = [contact.lastName rangeOfString:searchText options:NSCaseInsensitiveSearch];
			
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
    UIAlertController* actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"action_NewUserRequest", nil)
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", nil)
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction *action) {
                                                               
                                                           }];
    UIAlertAction* SmsAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_ContactInviteSms", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             _selectedInviteType = InviteContactActionSheetTextFromContacts;
                                                             [self showAddressBook];
                                                         }];
    UIAlertAction* EmailAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_ContactInviteEmail", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             _selectedInviteType = InviteContactActionSheetEmailFromContacts;
                                                             [self showAddressBook];
                                                         }];
    UIAlertAction* AnotherAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_UseAnother", nil)
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                            UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:[NSArray arrayWithObject:[self shortInviteMessage]] applicationActivities:nil];
                                                            [self presentViewController:activityController animated:YES completion:nil];
                                                        }];
    
    [actionSheet addAction:cancelAction];
    [actionSheet addAction:SmsAction];
    [actionSheet addAction:EmailAction];
    [actionSheet addAction:AnotherAction];
    [actionSheet setModalPresentationStyle:UIModalPresentationPopover];
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (IBAction)doneButtonTouched:(UIBarButtonItem *)sender {
	[_searchBar resignFirstResponder];
}

- (IBAction)infoButtonTouched:(UIButton *)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_PickRecipient", @"Recipients")
                                                                   message:NSLocalizedString(@"help_PickRecip", @"Contacts with SafeSlinger keys are displayed here, select one to send your message to.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* closeAciton = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action){
                                                         
                                                     }];
    UIAlertAction* feedbackAciton = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action){
                                                         [UtilityFunc SendOpts:self];
                                                     }];
    [alert addAction:closeAciton];
    [alert addAction:feedbackAciton];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)contactInfoButtonTouched:(UIButton *)sender {
	_selectedContactIndex = sender.tag;
	[self performSegueWithIdentifier:@"EditContactSegue" sender:self];
}

#pragma mark - Utils
- (void)showMessage:(NSString *)message withTitle:(NSString *)title {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAciton = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_OK", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action){
                                                             
                                                         }];
    
    [alert addAction:okAciton];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
