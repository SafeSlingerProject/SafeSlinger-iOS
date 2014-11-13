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

#import "ContactManageView.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "ComposeView.h"
#import "SlingkeyView.h"
#import "FunctionView.h"
#import <safeslingerexchange/iToast.h>

@interface ContactManageView ()

@end

@implementation ContactManageView

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // All cache time entries
    user_actions = [NSMutableDictionary dictionary];
    contact_index = [NSMutableArray array];
    contact_photos = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [user_actions removeAllObjects];
    [contact_index removeAllObjects];
    [contact_photos removeAllObjects];
	
    // has contact already
	[user_actions addEntriesFromDictionary:@{@(UseNameOnly): NSLocalizedString(@"menu_UseNoContact", nil),
												  @(AddNew): NSLocalizedString(@"menu_CreateNew", nil),
												  @(ReSelect): NSLocalizedString(@"menu_UseAnother", nil)}];
    
	
	NSString *nameInDatabase;
	
	if(_editingContact) {
		self.navigationItem.title = NSLocalizedString(@"title_RecipientDetail", nil);
		if(_editingContact.recordId > 0) {
			[user_actions setObject:NSLocalizedString(@"menu_Edit", nil) forKey:@(EditOld)];
		}
		
		nameInDatabase = [NSString compositeName:_editingContact.firstName withLastName:_editingContact.lastName];
	} else {
		self.navigationItem.title = NSLocalizedString(@"title_MyIdentity", nil);
		if(_appDelegate.IdentityNum > 0) {
			[user_actions setObject:NSLocalizedString(@"menu_Edit", nil) forKey:@(EditOld)];
		}
		
		nameInDatabase = [_appDelegate.DbInstance GetProfileName];
	}
	
    ABAddressBookRef aBook = NULL;
    CFErrorRef error = NULL;
    __block BOOL _grant = YES;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error){
        if(!granted) {
            _grant = granted;
        }
    });
    
    int index = 0;
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
    for (int i = 0; i < CFArrayGetCount(allPeople); i++) {
        ABRecordRef aRecord = CFArrayGetValueAtIndex(allPeople, i);
		if(ABRecordGetRecordType(aRecord) ==  kABPersonType) { // this check execute if it is person group
            NSString *firstname = (__bridge NSString*)ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
            NSString *lastname = (__bridge NSString*)ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
            NSString* compositename = [NSString compositeName:firstname withLastName:lastname];
			
            // firstname and lastname matches
            if([compositename isEqualToString:nameInDatabase]) {
                [user_actions setObject: [NSString stringWithFormat:NSLocalizedString(@"menu_UseContactPerson", nil),compositename]
                                      forKey:@(index)];
                [contact_index addObject:@(ABRecordGetRecordID(aRecord))];
                
                // Parse Photo
                if(ABPersonHasImageData(aRecord)) {
                    CFDataRef photo = ABPersonCopyImageDataWithFormat(aRecord, kABPersonImageFormatThumbnail);
                    UIImage *image = [UIImage imageWithData: (__bridge NSData *)photo];
                    [contact_photos addObject:image];
                    CFRelease(photo);
                } else {
                    [contact_photos addObject:[UIImage imageNamed: @"blank_contact.png"]];
                }
                
                index++;
            }
        }
    }
    
    if(allPeople)CFRelease(allPeople);
    if(aBook)CFRelease(aBook);
}

- (IBAction)DisplayHow:(id)sender {
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_MyIdentity", @"Personal Contact")
                                                      message:NSLocalizedString(@"help_identity_menu", @"You may also change personal data about your identity on this screen by tapping on the button with your name. This will display a menu allowing you to Edit your contact, Create New contact, or Use Another contact.")
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"), nil] show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex!=alertView.cancelButtonIndex) {
        [UtilityFunc SendOpts:self];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    switch (result) {
        case MFMailComposeResultCancelled:
        case MFMailComposeResultSaved:
        case MFMailComposeResultSent:
            break;
        case MFMailComposeResultFailed:
            // toast message
            [[[[iToast makeText: NSLocalizedString(@"error_CorrectYourInternetConnection", @"Internet not available, check your settings.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            break;
        default:
            break;
    }
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return user_actions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ContactOptCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    cell.textLabel.text = [[user_actions allValues]objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = nil;
    NSInteger key = [[[user_actions allKeys]objectAtIndex:indexPath.row]integerValue];
    if(key >= 0) {
        [cell.imageView setImage:contact_photos[key]];
    }
    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger key = [[[user_actions allKeys]objectAtIndex:indexPath.row]integerValue];
    
    switch (key) {
        case UseNameOnly:
			[self updateContact:nil];
            [self.navigationController popViewControllerAnimated:YES];
            break;
        case EditOld:
            [self editOldContact];
            break;
        case AddNew:
            [self addNewContact];
            break;
        case ReSelect:
            [self selectAnotherContact];
            break;
        default:
            // other contacts with the same name
			[self updateContact:[self getPersonFromAddressBook:(int)[contact_index[key] integerValue]]];
            [self.navigationController popViewControllerAnimated:YES];
            break;
    }
}

- (void)editOldContact {
	ABRecordRef person = [self getPersonFromAddressBook:_editingContact ? _editingContact.recordId : _appDelegate.IdentityNum];
    ABPersonViewController *personView = [[ABPersonViewController alloc] init];
    
    if(person) {
        personView.personViewDelegate = self;
        personView.allowsEditing = YES;
        personView.displayedPerson = person;
        personView.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_Done", @"Done")
                                                                                       style:UIBarButtonItemStylePlain
                                                                                      target:self
                                                                                      action:@selector(ReturnFromEditView)];
        [self.navigationController pushViewController:personView animated:YES];
    }
}

- (ABRecordRef)getPersonFromAddressBook:(ABRecordID)personID {
	CFErrorRef error = NULL;
	ABAddressBookRef aBook = NULL;
	
	aBook = ABAddressBookCreateWithOptions(NULL, &error);
	ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
		if (!granted) {
			return;
		}
	});
	
	return ABAddressBookGetPersonWithRecordID(aBook, personID);
}

- (void)ReturnFromEditView {
    // check name if it existed
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
        }
    });
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, _appDelegate.IdentityNum);
	
	if([self updateContact:person]){
        FunctionView *main = nil;
        for (UIViewController *view in [self.navigationController childViewControllers]) {
            if([view isMemberOfClass:[FunctionView class]]) {
                main = (FunctionView*)view;
                break;
            }
        }
        [self.navigationController popToViewController:main animated: YES];
    }
    if(aBook)CFRelease(aBook);
}

- (void)addNewContact {
    ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
    picker.newPersonViewDelegate = self;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)selectAnotherContact
{
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark ABPeoplePickerNavigationControllerDelegate

- (void)peoplePickerNavigationControllerDidCancel: (ABPeoplePickerNavigationController *)peoplePicker {
    //user canceled, no new contact selected
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person {
	if([self updateContact:person]) {
        [peoplePicker dismissViewControllerAnimated:YES completion:nil];
        [self.navigationController popViewControllerAnimated:YES];
    }
	return NO;
}

- (BOOL)peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson: (ABRecordRef)person property: (ABPropertyID)property identifier: (ABMultiValueIdentifier)identifier {
    return NO;
}

- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController*)peoplePicker didSelectPerson:(ABRecordRef)person {
    DEBUGMSG(@"didSelectPerson");
    if (person) {
		if([self updateContact:person]) {
            [self.navigationController popViewControllerAnimated:YES];
        }
    } else {
        [peoplePicker dismissViewControllerAnimated:YES completion:nil];
    }
}


#pragma mark - ABPersonViewControllerDelegate

- (BOOL)personViewController:(ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifierForValue {
	return YES;
}

#pragma mark - ABNewPersonViewControllerDelegate methods

- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person {
    if (person) {
		if([self updateContact:person]) {
			[newPersonViewController dismissViewControllerAnimated:YES completion:nil];
			[self.navigationController popViewControllerAnimated:YES];
		}
    } else {
        [newPersonViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Utility methods

- (BOOL)updateContact:(ABRecordRef)contact {
	BOOL contactUpdated = NO;
	
	if(contact) {
		NSString *firstName = (__bridge NSString *)(ABRecordCopyValue(contact, kABPersonFirstNameProperty));
		NSString *lastName = (__bridge NSString *)(ABRecordCopyValue(contact, kABPersonLastNameProperty));
		
		if(!firstName && !lastName) {
			[[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
			   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
			return NO;
		}
		
		if(_editingContact) {
			_editingContact.firstName = firstName;
			_editingContact.lastName = lastName;
			_editingContact.recordId = ABRecordGetRecordID(contact);
			
			if(ABPersonHasImageData(contact)) {
				CFDataRef imgData = ABPersonCopyImageDataWithFormat(contact, kABPersonImageFormatThumbnail);
				UIImage *image = [UIImage imageWithData:(__bridge NSData *)imgData];
				_editingContact.photo = UIImageJPEGRepresentation([image scaleToSize:CGSizeMake(45.0f, 45.0f)], 0.9);
				CFRelease(imgData);
			} else {
				_editingContact.photo = nil;
			}
			
			[_appDelegate.DbInstance updateContactDetails:_editingContact];
		} else {
			[_appDelegate saveConactData:ABRecordGetRecordID(contact) Firstname:firstName Lastname:lastName];
		}
		
		contactUpdated = YES;
	} else {
		if(_editingContact) {
			_editingContact.photo = nil;
			[_appDelegate.DbInstance updateContactDetails:_editingContact];
		} else {
			[_appDelegate removeContactLink];
		}
		
		contactUpdated = YES;
	}
	
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	if(_editingContact) {
		[userInfo setObject:_editingContact forKey:NSNotificationContactEditedObject];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NSNotificationContactEdited object:nil userInfo:userInfo];
	
	return contactUpdated;
}

@end
