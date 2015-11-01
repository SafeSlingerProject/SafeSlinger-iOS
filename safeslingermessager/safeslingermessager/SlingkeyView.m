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

#import "SlingkeyView.h"
#import "AppDelegate.h"
#import "SSEngine.h"
#import "Utility.h"
#import "VCardParser.h"
#import "FunctionView.h"
#import "ContactManageView.h"
#import "EndExchangeView.h"

@interface SlingkeyView ()

@end

@implementation SlingkeyView

@synthesize ContactChangeBtn, ExchangeBtn, ContactImage, ContactInfoTable, DescriptionLabel;
@synthesize contact_category, contact_labels, contact_selections, contact_values, label_dictionary;
@synthesize delegate;
@synthesize EndExchangeAlready, GatherList;
@synthesize proto;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    self.contact_labels = [[NSMutableArray alloc] init];
    self.contact_values = [[NSMutableArray alloc] init];
    self.contact_selections = [[NSMutableArray alloc] init];
    self.contact_category = [[NSMutableArray alloc] init];
    self.label_dictionary = [[NSMutableDictionary alloc] init];
    
    // Home, Work, Other tags
    [label_dictionary setObject: @"Home" forKey: (NSString *)kABHomeLabel];
    [label_dictionary setObject: @"Work" forKey: (NSString *)kABWorkLabel];
    [label_dictionary setObject: @"Other" forKey: (NSString *)kABOtherLabel];
    
    // Moible, IPhone, Main, HomeFax, WorkFax, OtherFax, Pager tags
    [label_dictionary setObject: @"Mobile" forKey: (NSString *)kABPersonPhoneMobileLabel];
    [label_dictionary setObject: @"iPhone" forKey: (NSString *)kABPersonPhoneIPhoneLabel];
    [label_dictionary setObject: @"Main" forKey: (NSString *)kABPersonPhoneMainLabel];
    [label_dictionary setObject: @"HomeFAX" forKey: (NSString *)kABPersonPhoneHomeFAXLabel];
    [label_dictionary setObject: @"WorkFAX" forKey: (NSString *)kABPersonPhoneWorkFAXLabel];
    [label_dictionary setObject: @"OtherFAX" forKey: (NSString *)kABPersonPhoneOtherFAXLabel];
    [label_dictionary setObject: @"Pager" forKey: (NSString *)kABPersonPhonePagerLabel];
    
    // kABPersonHomePageLabel
    [label_dictionary setObject: @"HomePage" forKey: (NSString *)kABPersonHomePageLabel];
    
    // safeslinger exchange protocol
    proto = [[safeslingerexchange alloc]init];
	GatherList = [NSMutableArray array];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contactEdited:)
												 name:NSNotificationContactEdited
											   object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Change Title and Help Button
    self.parentViewController.navigationItem.title = NSLocalizedString(@"menu_TagExchange", @"Sling Keys");
    self.parentViewController.navigationItem.hidesBackButton = YES;
    
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.parentViewController.navigationItem setRightBarButtonItem:HomeButton];
    
    DescriptionLabel.text = NSLocalizedString(@"label_Home", @"Check items you wish to share and tap 'Begin Exchange' when others are ready to exchange.");
    DescriptionLabel.adjustsFontSizeToFitWidth = YES;
    [ExchangeBtn setTitle: NSLocalizedString(@"btn_BeginExchangeProximity", @"Begin Exchange") forState:UIControlStateNormal];
    
    if([[NSUserDefaults standardUserDefaults]integerForKey: kShowExchangeHint] == TurnOn) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self performSegueWithIdentifier:@"ShowExchangeHelp" sender:self];
        });
    }
	
    [self processProfile];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)processProfile {
	DEBUGMSG(@"processContactWithID: %d", delegate.IdentityNum);
	
    // clean up
    [contact_labels removeAllObjects];
    [contact_values removeAllObjects];
    [contact_selections removeAllObjects];
    [contact_category removeAllObjects];
    [ContactImage setImage:nil];
    
    //ContactImage.image = nil;
    delegate.IdentityName = [delegate.DbInstance GetProfileName];
    
    switch (delegate.IdentityNum) {
        case NonExist:
            [ContactChangeBtn setTitle:NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown") forState:UIControlStateNormal];
            [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            [ExchangeBtn setEnabled:NO];
            break;
        case NonLink:
            // Read Profile from database
            [ContactChangeBtn setTitle: delegate.IdentityName forState: UIControlStateNormal];
            [ContactImage setImage: [UIImage imageNamed:@"blank_contact"]];
            [ExchangeBtn setEnabled:YES];
            break;
        default:
            [ContactChangeBtn setTitle: delegate.IdentityName forState: UIControlStateNormal];
            if(![self ParseContact:delegate.IdentityNum]) {
                // if permission is disabled
                [ContactImage setImage: [UIImage imageNamed:@"blank_contact"]];
            }
            [ExchangeBtn setEnabled:YES];
            break;
    }
    
    // Update display, for key and token information
    if([[SSEngine getPackPubKeys]length] > 0) {
        [contact_labels addObject: @"SafeSlinger-PubKey"];
        [contact_values addObject: @""];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:IMPP]];
    }
    
    // check with mike here
    if([[NSUserDefaults standardUserDefaults] stringForKey: kPUSH_TOKEN])
    {
        [contact_labels addObject: @"SafeSlinger-Push"];
        [contact_values addObject: @""];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:IMPP]];
    }
    
	//Load the fields read in so far into the selection list
    [self.view setNeedsDisplay];
    [self.ContactInfoTable reloadData];
}

-(IBAction) EditContact {
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if(status == kABAuthorizationStatusNotDetermined) {
        UIAlertController* actionAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                                            message:NSLocalizedString(@"iOS_RequestPermissionContacts", @"You can select your contact card to send your friends and SafeSlinger will encrypt it for you. To enable this feature, you must allow SafeSlinger access to your Contacts when asked.")
                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction* noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_NotNow", @"Not Now")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                
                                                            }];
        UIAlertAction* yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Continue", @"Continue")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                [UtilityFunc TriggerContactPermission];
                                                            }];
        [actionAlert addAction:yesAction];
        [actionAlert addAction:noAction];
        [self presentViewController:actionAlert animated:YES completion:nil];
    } else if(status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted) {
        UIAlertController* actionAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                                             message:[NSString stringWithFormat: NSLocalizedString(@"iOS_contactError", @"Contacts permission is required for securely sharing contact cards. Tap the %@ button for SafeSlinger Contacts permission details."), NSLocalizedString(@"menu_Settings", @"menu_Settings")]
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction* noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_NotNow", @"Not Now")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             
                                                         }];
        UIAlertAction* yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_Settings", @"menu_Settings")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
                                                              NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                              [[UIApplication sharedApplication] openURL:url];
                                                          }];
        [actionAlert addAction:yesAction];
        [actionAlert addAction:noAction];
        [self presentViewController:actionAlert animated:YES completion:nil];
    } else if(status == kABAuthorizationStatusAuthorized) {
        if(delegate.IdentityNum != NonExist) {
            [self performSegueWithIdentifier:@"EditContact" sender:self];
        }
    }
    
}

- (IBAction)BeginExchange {
    // check notification permission
    int flag =[UIApplication sharedApplication].currentUserNotificationSettings.types & (UIUserNotificationTypeBadge | UIUserNotificationTypeAlert);
    if (![[UIApplication sharedApplication] isRegisteredForRemoteNotifications] || flag != (UIUserNotificationTypeBadge | UIUserNotificationTypeAlert))
    {
        UIAlertController* actionAlert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                                             message:[NSString stringWithFormat: NSLocalizedString(@"iOS_notificationError1", @"Notification permission for either alerts or banners, and badge numbers, are required for secure messaging. Tap the %@ button for SafeSlinger Notification permission details."), NSLocalizedString(@"menu_Settings", @"menu_Settings")]
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction* noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             
                                                         }];
        UIAlertAction* yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_Settings", @"menu_Settings")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
                                                              NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                              [[UIApplication sharedApplication] openURL:url];
                                                          }];
        [actionAlert addAction:yesAction];
        [actionAlert addAction:noAction];
        [self presentViewController:actionAlert animated:YES completion:nil];
    }
    
    NSString* vCard;
    if(delegate.IdentityNum==NonLink) {
        // profile only
        NSString* fname = [delegate.DbInstance GetStringConfig:@"Profile_FN"];
        NSString* lname = [delegate.DbInstance GetStringConfig:@"Profile_LN"];
        vCard = [VCardParser vCardWithNameOnly: fname LastName: lname];
    } else if(delegate.IdentityNum>0) {
        // vCard extracted from address book is ready to exchange
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = NULL;
        aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if (!granted) {
            }
        });
        
        ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, delegate.IdentityNum);
        vCard = [VCardParser vCardFromContact: aRecord labels: contact_labels values: contact_values selections: contact_selections category:contact_category];
        if(aBook)CFRelease(aBook);
    }
    
    [proto SetupExchange:self ServerHost:[NSString stringWithFormat:@"%@%@", HTTPURL_PREFIX, HTTPURL_HOST_EXCHANGE] VersionNumber:[delegate getVersionNumber] FirstUse:![[NSUserDefaults standardUserDefaults] boolForKey:kFIRST_USE]];
    [proto BeginExchange: [vCard dataUsingEncoding:NSUTF8StringEncoding]];
}

- (BOOL)ParseContact:(int)contactID {
    // load contact
    if(ABAddressBookGetAuthorizationStatus()!=kABAuthorizationStatusAuthorized) {
        return NO;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef book = NULL;
    book = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
        if (!granted) {
        }
    });
    
	ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(book, contactID);
	if (!aRecord) {
        // error handle
		delegate.IdentityNum = NonExist;
        [ContactChangeBtn setTitle:NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown") forState:UIControlStateNormal];
		if(book)CFRelease(book);
        [ExchangeBtn setEnabled:NO];
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		return NO;
	}
    
    // Parse Photo
    if(ABPersonHasImageData(aRecord)) {
        CFDataRef photo = ABPersonCopyImageDataWithFormat(aRecord, kABPersonImageFormatThumbnail);
        UIImage *image = [UIImage imageWithData: (__bridge NSData *)photo];
        [ContactImage setImage:image];
        
        // update cache image
        NSData* img = (NSData*)UIImageJPEGRepresentation(image, 1.0);
        NSString *encodedPhoto = [img base64EncodedStringWithOptions:0];
        [contact_labels addObject: @"Photo"];
        [contact_values addObject: encodedPhoto];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:Photo]];
        
        CFRelease(photo);
    } else {
        [ContactImage setImage: [UIImage imageNamed:@"blank_contact"]];
    }
    
    // Parse Emails
	ABMutableMultiValueRef email = ABRecordCopyValue(aRecord, kABPersonEmailProperty);
	for (CFIndex i = 0; i < ABMultiValueGetCount(email); i++) {
        CFStringRef emailAddress = ABMultiValueCopyValueAtIndex(email, i);
        CFStringRef eLabel = ABMultiValueCopyLabelAtIndex(email, i);
        NSString *emailLabel = [label_dictionary objectForKey:(__bridge NSString*)eLabel];
        
        if([(__bridge NSString*)emailAddress IsValidEmail]) {
            if(emailLabel) {
                [contact_labels addObject: (NSString*)emailLabel];
			} else if(eLabel!=NULL) {
                [contact_labels addObject: (__bridge NSString*)eLabel];
			} else {
                [contact_labels addObject: @"Other"];
			}
            [contact_values addObject: (__bridge NSString *)emailAddress];
            [contact_selections addObject:[NSNumber numberWithBool:YES]];
            [contact_category addObject:[NSNumber numberWithInt:Email]];
        }
        if(emailAddress)CFRelease(emailAddress);
        if(eLabel)CFRelease(eLabel);
	}
    if(email)CFRelease(email);
    
    // Parse URLs
    ABMutableMultiValueRef webpage = ABRecordCopyValue(aRecord, kABPersonURLProperty);
    for (CFIndex i = 0; i < ABMultiValueGetCount(webpage); i++) {
        CFStringRef url = ABMultiValueCopyValueAtIndex(webpage, i);
        CFStringRef uLabel = ABMultiValueCopyLabelAtIndex(webpage, i);
        NSString *urlLabel = [label_dictionary objectForKey:(__bridge NSString*)uLabel];
        if(urlLabel) {
            [contact_labels addObject: urlLabel];
		} else if(uLabel) {
            [contact_labels addObject: (__bridge NSString*)uLabel];
		} else {
            [contact_labels addObject: @"Other"];
		}
        [contact_values addObject: (__bridge NSString *)url];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:Url]];
        if(url)CFRelease(url);
        if(uLabel)CFRelease(uLabel);
    }
    if(webpage)CFRelease(webpage);
    
    // Parse PhoneNumber
	ABMutableMultiValueRef phone = ABRecordCopyValue(aRecord, kABPersonPhoneProperty);
    for (CFIndex i = 0; i < ABMultiValueGetCount(phone); i++) {
        CFStringRef phoneNumber = ABMultiValueCopyValueAtIndex(phone, i);
        CFStringRef pLabel = ABMultiValueCopyLabelAtIndex(phone, i);
        NSString *phoneLabel = [label_dictionary objectForKey:(__bridge NSString*)pLabel];
        if([(__bridge NSString*)phoneNumber IsValidPhoneNumber]) {
            if(phoneLabel) {
                [contact_labels addObject: phoneLabel];
			} else if(pLabel) {
                [contact_labels addObject: (__bridge NSString*)pLabel];
			} else {
                [contact_labels addObject: @"Other"];
			}
            [contact_values addObject: (__bridge NSString *)phoneNumber];
            [contact_selections addObject:[NSNumber numberWithBool:YES]];
            [contact_category addObject:[NSNumber numberWithInt:PhoneNum]];
        }
        if(phoneNumber)CFRelease(phoneNumber);
        if(pLabel)CFRelease(pLabel);
    }
    if(phone)CFRelease(phone);
    
    // Parse adress
	ABMutableMultiValueRef address = ABRecordCopyValue(aRecord, kABPersonAddressProperty);
	for (CFIndex i = 0; i < ABMultiValueGetCount(address); i++) {
        CFStringRef aLabel = ABMultiValueCopyLabelAtIndex(address, i);
        NSString *addressLabel = [label_dictionary objectForKey:(__bridge NSString*)aLabel];
        
        CFDictionaryRef addressDictionary = ABMultiValueCopyValueAtIndex(address, i);
        CFStringRef street = CFDictionaryGetValue(addressDictionary, kABPersonAddressStreetKey);
        CFStringRef city = CFDictionaryGetValue(addressDictionary, kABPersonAddressCityKey);
        CFStringRef state = CFDictionaryGetValue(addressDictionary, kABPersonAddressStateKey);
        CFStringRef zip = CFDictionaryGetValue(addressDictionary, kABPersonAddressZIPKey);
        CFStringRef country = CFDictionaryGetValue(addressDictionary, kABPersonAddressCountryKey);
        NSMutableString *addressString = [[NSMutableString alloc] init];
        
        if (street)
            [addressString appendFormat: @"%@;", street];
        if (city)
            [addressString appendFormat: @"%@;", city];
        if (state)
            [addressString appendFormat: @"%@;", state];
        if (zip)
            [addressString appendFormat: @"%@;", zip];
        if (country)
            [addressString appendFormat: @"%@", country];
        
        if ([addressString characterAtIndex: [addressString length] - 1] == ';')
        {
            NSRange range;
            range.location = [addressString length] - 1;
            range.length = 1;
            [addressString deleteCharactersInRange: range];
        }
        [addressString replaceOccurrencesOfString: @"\n" withString:@"\\n" options: NSLiteralSearch range: NSMakeRange(0, [addressString length])];
        
        if(addressLabel)
        {
            [contact_labels addObject: addressLabel];
        }else if(aLabel)
        	[contact_labels addObject: (__bridge NSString*)aLabel];
        else
            [contact_labels addObject: @"Other"];
        
        [contact_values addObject: addressString];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:Address]];
        
        if(addressDictionary)CFRelease(addressDictionary);
        if(aLabel)CFRelease(aLabel);
    }
    if(address)CFRelease(address);
    if(book)CFRelease(book);
    
    return YES;
}

- (void)DisplayHow {
    UIAlertController* actionSheet = [UIAlertController alertControllerWithTitle:nil
                                                          message:nil
                                                   preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                             style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction *action) {
                                               
                                           }];
    UIAlertAction* helpAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_Help", @"Help")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
                                             [self performSegueWithIdentifier:@"ShowHelp" sender:self];
                                         }];
    UIAlertAction* feedbackAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                            [UtilityFunc SendOpts:self];
                                                        }];
    // note: you can control the order buttons are shown, unlike UIActionSheet
    [actionSheet addAction:helpAction];
    [actionSheet addAction:feedbackAction];
    [actionSheet addAction:cancelAction];
    [actionSheet setModalPresentationStyle:UIModalPresentationPopover];
    [self presentViewController:actionSheet animated:YES completion:nil];
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

#pragma mark - NSNotification methods

- (void)contactEdited:(NSNotification *)notification {
	if(!notification.userInfo[NSNotificationContactEditedObject]) {
		[self processProfile];
	}
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow] animated: YES];
	NSInteger row = [indexPath row];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
    
    if(cell.tag == 0) {
        switch (cell.accessoryType) {
            case UITableViewCellAccessoryNone:
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                [contact_selections replaceObjectAtIndex:row withObject:[NSNumber numberWithBool:YES]];
                break;
            case UITableViewCellAccessoryCheckmark:
                cell.accessoryType = UITableViewCellAccessoryNone;
                [contact_selections replaceObjectAtIndex:row withObject:[NSNumber numberWithBool:NO]];
                break;
            default:
                break;
        }
    }
}

#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [contact_labels count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ContactFieldIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
	NSInteger row = [indexPath row];
    cell.accessoryType = ([[contact_selections objectAtIndex:row]boolValue] ? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone);
	cell.textLabel.font = [cell.textLabel.font fontWithSize: 13];
    
    NSNumber* cateclass = [contact_category objectAtIndex:row];
    cell.tag = 0;
    switch(cateclass.intValue) {
        case Photo:
            [cell.imageView setImage:[UIImage imageNamed:@"photo.png"]];
            cell.textLabel.text = @"Photo";
            break;
        case Email:
            [cell.imageView setImage:[UIImage imageNamed:@"email.png"]];
            break;
        case Url:
            [cell.imageView setImage:[UIImage imageNamed:@"url.png"]];
            break;
        case PhoneNum:
            [cell.imageView setImage:[UIImage imageNamed:@"phone.png"]];
            break;
        case Address:
            [cell.imageView setImage:[UIImage imageNamed:@"address.png"]];
            break;
        case IMPP:
            [cell.imageView setImage:[UIImage imageNamed:@"impp.png"]];
            cell.tag = -1;
            break;
        default:
            break;
    }
    
    switch(cateclass.intValue) {
        case Photo:
            cell.textLabel.text = @"Photo";
            break;
        case Email:
        case Url:
        case PhoneNum:
        case Address:
        case IMPP:
            cell.textLabel.text = [NSString stringWithFormat: @"%@: %@", [contact_labels objectAtIndex: row], [contact_values objectAtIndex: row]];
            break;
        default:
            break;
    }
    
	return cell;
}

#pragma SafeSlingerDelegate Methods

- (void)EndExchange:(int)status_code ErrorString:(NSString *)error_str ExchangeSet:(NSArray *)exchange_set {
    switch(status_code) {
		case RESULT_EXCHANGE_OK: {
            // parse the exchanged data
            [GatherList removeAllObjects];
            for(NSData* item in exchange_set) {
                NSString *card = [[NSString alloc] initWithData:item encoding:NSUTF8StringEncoding];
                ABRecordRef aRecord = [VCardParser vCardToContact: card];
                if (aRecord) {
                    [GatherList addObject:(__bridge id)(aRecord)];
                }
            }
            [self performSegueWithIdentifier:@"EndExchange" sender:self];
        }
            break;
            
		case RESULT_EXCHANGE_CANCELED: {
            // handle canceled result
            DEBUGMSG(@"Exchange Error: %@", error_str);
            FunctionView *mainview = nil;
            NSArray *stack = [self.navigationController viewControllers];
            for(UIViewController *view in stack) {
                if([view isMemberOfClass:[FunctionView class]]) {
                    mainview = (FunctionView*)view;
                    break;
                }
            }
            [self.navigationController popToViewController:mainview animated:YES];
        }
            break;
            
        default:
            break;
    }
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier]isEqualToString:@"EndExchange"]) {
        // Get destination view
        EndExchangeView *saveView = [segue destinationViewController];
        saveView.contactList = GatherList;
    }
}

@end
