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

#import "ContactViewController.h"
#import "KeySlingerAppDelegate.h"
#import "Base64.h"
#import "SecureRandom.h"
#import "SSEngine.h"
#import "KeyAssistant.h"
#import "iToast.h"
#import "VersionCheckMarco.h"
#import "Utility.h"
#import "ErrorLogger.h"
#import "VCardParser.h"
#import "Config.h"

#import "UAirship.h"
#import "UAPush.h"

@implementation ContactViewController

@synthesize ContactChangeBtn, ExchangeBtn, ContactImage, ContactInfoTable, DescriptionLabel;
@synthesize contact_category, contact_labels, contact_selections, contact_values, label_dictionary;
@synthesize delegate;
@synthesize helper;
@synthesize isShowAssist;


// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
        self.delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"menu_TagExchange", @"Sling Keys");
    
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
    
    // ? button
    UIButton * infoButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0, 30.0f)];
    [infoButton setImage:[UIImage imageNamed:@"help.png"] forState:UIControlStateNormal];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HomeButton];
    [HomeButton release];
    HomeButton = nil;
    [infoButton release];
    infoButton = nil;
    
    // helper
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if(IS_4InchScreen)
            self.helper = [[KeyAssistant alloc]initWithNibName:@"KeyAssistant_4in" bundle:nil];
        else
            self.helper = [[KeyAssistant alloc]initWithNibName:@"KeyAssistant" bundle:nil];
    }else
    {
        self.helper = [[KeyAssistant alloc]initWithNibName:@"KeyAssistant_ip5" bundle:nil];
    }
}

-(IBAction) ChangeContact
{
    // allow users to pick photos from multiple locations
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle: NSLocalizedString(@"title_MyIdentity", @"My Identity")
                                  delegate: self
                                  cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                  destructiveButtonTitle: nil
                                  otherButtonTitles:
                                  NSLocalizedString(@"menu_Edit", @"Edit"),
                                  NSLocalizedString(@"menu_CreateNew", @"Create New"),
                                  NSLocalizedString(@"menu_UseAnother", @"Use Another"),
                                  nil];
    
    [actionSheet showInView: [self.navigationController view]];
    [actionSheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
    }else if(buttonIndex!=actionSheet.cancelButtonIndex)
    {
        switch(buttonIndex)
        {
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
                break;
        }
    }
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_home", @"Begin Exchange")
                                                      message: [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"help_home", @"To exchange identity data, ensure all users are nearby or on the phone. The 'Begin Exchange' button will exchange only the checked contact data."),
                                                                NSLocalizedString(@"help_identity_menu", @"\n\nYou may also change personal data about your identity on this screen by tapping on the button with your name. This will display a menu allowing you to 'Edit' your contact, 'Create New' contact, or 'Use Another' contact.")]
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    
    [message show];
    [message release];
    message = nil;
}

-(void) editOldContact
{
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            return;
        }
    });
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
    ABPersonViewController *personView = [[ABPersonViewController alloc] init];
    
    personView.allowsEditing = YES;
    personView.personViewDelegate = self;
    personView.displayedPerson = person;
    personView.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"btn_Done", @"Done")
                                                                                   style:UIBarButtonItemStylePlain
                                                                                  target:self
                                                                                  action:@selector(ReturnFromEditView)] ;
    [self.navigationController pushViewController:personView animated:YES];
    [personView release];
    if(aBook)CFRelease(aBook);
}

- (void)ReturnFromEditView
{
    // check name if it existed
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        }
    });
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
    CFStringRef FName = ABRecordCopyValue(person, kABPersonFirstNameProperty);
    CFStringRef LName = ABRecordCopyValue(person, kABPersonLastNameProperty);
    
    if ((!FName)&&(!LName))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        
    }else
    {
        if(FName)CFRelease(FName);
        if(LName)CFRelease(LName);
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    if(aBook)CFRelease(aBook);
    [self processContactWithID:delegate.myID];
}

- (void) addNewContact
{
    [self dismissViewControllerAnimated:NO completion:nil];
    ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
    picker.newPersonViewDelegate = self;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:navigation animated:YES completion:nil];
    [picker release];
    [navigation release];
}

- (void) selectAnotherContact
{
    [self dismissViewControllerAnimated:NO completion:nil];
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}


#pragma mark ABPeoplePickerNavigationControllerDelegate
-(void) peoplePickerNavigationControllerDidCancel: (ABPeoplePickerNavigationController *)peoplePicker
{
    DEBUGMSG(@"peoplePickerNavigationControllerDidCancel");
    //user canceled, no new contact selected
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
	[peoplePicker autorelease];
}

-(BOOL) peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person
{
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
	[peoplePicker autorelease];
    // check name field is existed.
    if ((ABRecordCopyValue(person, kABPersonFirstNameProperty)==NULL)&&(ABRecordCopyValue(person, kABPersonLastNameProperty)==NULL))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing2", @"This contact is missing a name, please reselect.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else{
        delegate.myID = ABRecordGetRecordID(person);
        [delegate saveConactData];
        [self processContactWithID:delegate.myID];
    }
	return NO;
}

-(BOOL) peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person property: (ABPropertyID)property identifier: (ABMultiValueIdentifier)identifier
{
	return NO;
}

#pragma mark ABPersonViewControllerDelegate
-(BOOL) personViewController: (ABPersonViewController *)personViewController shouldPerformDefaultActionForPerson: (ABRecordRef)person property: (ABPropertyID)property identifier: (ABMultiValueIdentifier)identifierForValue
{
	return NO;
}

#pragma mark ABNewPersonViewControllerDelegate methods
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
    if (person)
    {
        if ((ABRecordCopyValue(person, kABPersonFirstNameProperty)==NULL)&&(ABRecordCopyValue(person, kABPersonLastNameProperty)==NULL))
        {
            [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }else{
            delegate.myID = ABRecordGetRecordID(person);
            [delegate saveConactData];
            [self processContactWithID:delegate.myID];
        }
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}


-(void)viewWillAppear:(BOOL)animated
{
    [self processContactWithID: delegate.myID];
    DescriptionLabel.text = NSLocalizedString(@"label_Home", @"Check items you wish to share and tap 'Begin Exchange' when others are ready to exchange.");
    DescriptionLabel.adjustsFontSizeToFitWidth = YES;
    [ExchangeBtn setTitle:NSLocalizedString(@"btn_BeginExchangeProximity", @"Begin Exchange") forState:UIControlStateNormal];
}

- (void) viewDidAppear:(BOOL)animated
{
    // show Assisant if needed
    int v = 0;
    [[delegate.DbInstance GetConfig:@"label_ShowHintAtLaunch"]getBytes:&v length:sizeof(v)];
    BOOL booltmp = ((v == 1) ? YES: NO);
    if(isShowAssist&&booltmp)
    {
        [delegate.navController pushViewController:helper animated:YES];
    }
}

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [contact_category release];
	[contact_labels release];
    [contact_selections release];
    [contact_values release];
	[label_dictionary release];
    [helper release];
    [DescriptionLabel release];
    [ContactChangeBtn release];
	[ContactImage release];
}

- (void)dealloc {
    [super dealloc];
}


-(IBAction) BeginExchange
{
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
    }else{
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = NULL;
        aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if (!granted) {
                [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            }
        });
        
        ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
        delegate.vCardString = [VCardParser vCardFromContact: aRecord labels: contact_labels values: contact_values selections: contact_selections category:contact_category];
        if(aBook)CFRelease(aBook);
        [delegate.navController pushViewController: delegate.exchangeView animated: YES];
    }
}


-(void) processContactWithID: (int)contactID
{
	DEBUGMSG(@"processContactWithID: %d", contactID);
	
    // clean up
    [contact_labels removeAllObjects];
    [contact_values removeAllObjects];
    [contact_selections removeAllObjects];
    [contact_category removeAllObjects];
    
    ContactImage.image = nil;
    
	if (contactID == -1)
    {
        // error handle
        [ContactChangeBtn setTitle:NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown") forState:UIControlStateNormal];
        [ExchangeBtn setEnabled:NO];
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		return;
	}else{
        [ExchangeBtn setEnabled:YES];
    }
	
    // load contact
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef book = NULL;
    book = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
            return;
        }
    });
    
	ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(book, contactID);
	if (aRecord == nil)
	{
        // error handle
		delegate.myID = -1;
        [ContactChangeBtn setTitle:NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown") forState:UIControlStateNormal];
		if(book)CFRelease(book);
        [ExchangeBtn setEnabled:NO];
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		return;
	}
    
    // Parse Firstname and Lastname
	CFStringRef firstName = ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
    CFStringRef lastName = ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
    if (firstName==NULL&&lastName==NULL)
    {
        // error handle
		delegate.myID = -1;
		if(book)CFRelease(book);
        [ExchangeBtn setEnabled:NO];
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
		return;
    }else{
        [ContactChangeBtn setTitle: [NSString composite_name:(NSString*)firstName withLastName: (NSString*)lastName] forState: UIControlStateNormal];
        if(firstName)CFRelease(firstName);
        if(lastName)CFRelease(lastName);
    }
    
    // Parse Photo
	CFDataRef photo = ABPersonCopyImageData(aRecord);
	if (photo)
	{	
		UIImage *image = [[UIImage imageWithData: (NSData *)photo]scaleToSize:CGSizeMake(45.0f, 45.0f)];
		[ContactImage setImage:image];
		
        // update cache image
        delegate.SelfPhotoCache = [(NSData*)UIImageJPEGRepresentation(image, 0.9)retain];
        
		NSString *encodedPhoto = [Base64 encode: delegate.SelfPhotoCache];
        [contact_labels addObject: @"Photo"];
		[contact_values addObject: encodedPhoto];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:Photo]];
        
        CFRelease(photo);
	}else{
        [ContactImage setImage: [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"blank_contact" ofType:@"png"]]];
    }
    
    // Parse Emails
	ABMutableMultiValueRef email = ABRecordCopyValue(aRecord, kABPersonEmailProperty);
	for (CFIndex i = 0; i < ABMultiValueGetCount(email); i++)
    {
        CFStringRef emailAddress = ABMultiValueCopyValueAtIndex(email, i);
        CFStringRef eLabel = ABMultiValueCopyLabelAtIndex(email, i);
        NSString *emailLabel = [label_dictionary objectForKey:(NSString*)eLabel];
        
        if([(NSString*)emailAddress IsValidEmail])
        {
            if(emailLabel)
            {
                [contact_labels addObject: (NSString*)emailLabel];
                [emailLabel release];
            }else if(eLabel!=NULL)
                [contact_labels addObject: (NSString*)eLabel];
            else
                [contact_labels addObject: @"Other"];
            [contact_values addObject: (NSString *)emailAddress];
            [contact_selections addObject:[NSNumber numberWithBool:YES]];
            [contact_category addObject:[NSNumber numberWithInt:Email]];
        }
        if(emailAddress)CFRelease(emailAddress);
        if(eLabel)CFRelease(eLabel);
	}
    if(email)CFRelease(email);
    
    // Parse URLs
    ABMutableMultiValueRef webpage = ABRecordCopyValue(aRecord, kABPersonURLProperty);
    for (CFIndex i = 0; i < ABMultiValueGetCount(webpage); i++)
    {
        CFStringRef url = ABMultiValueCopyValueAtIndex(webpage, i);
        CFStringRef uLabel = ABMultiValueCopyLabelAtIndex(webpage, i);
        NSString *urlLabel = [label_dictionary objectForKey:(NSString*)uLabel];
        
        if(urlLabel)
        {
            [contact_labels addObject: urlLabel];
            [urlLabel release];
        }else if(uLabel)
            [contact_labels addObject: (NSString*)uLabel];
        else
            [contact_labels addObject: @"Other"];
        [contact_values addObject: (NSString *)url];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:Url]];
        if(url)CFRelease(url);
        if(uLabel)CFRelease(uLabel);
    }
    if(webpage)CFRelease(webpage);
    
    // Parse PhoneNumber
	ABMutableMultiValueRef phone = ABRecordCopyValue(aRecord, kABPersonPhoneProperty);
    for (CFIndex i = 0; i < ABMultiValueGetCount(phone); i++)
    {
        CFStringRef phoneNumber = ABMultiValueCopyValueAtIndex(phone, i);
        CFStringRef pLabel = ABMultiValueCopyLabelAtIndex(phone, i);
        NSString *phoneLabel = [label_dictionary objectForKey:(NSString*)pLabel];
        
        if([(NSString*)phoneNumber IsValidPhoneNumber])
        {
            if(phoneLabel)
            {
                [contact_labels addObject: phoneLabel];
                [phoneLabel release];
            }else if(pLabel)
                [contact_labels addObject: (NSString*)pLabel];
            else
                [contact_labels addObject: @"Other"];
            
            [contact_values addObject: (NSString *)phoneNumber];
            [contact_selections addObject:[NSNumber numberWithBool:YES]];
            [contact_category addObject:[NSNumber numberWithInt:PhoneNum]];
        }
        if(phoneNumber)CFRelease(phoneNumber);
        if(pLabel)CFRelease(pLabel);
    }
    if(phone)CFRelease(phone);
    
    // Parse adress
	ABMutableMultiValueRef address = ABRecordCopyValue(aRecord, kABPersonAddressProperty);
	for (CFIndex i = 0; i < ABMultiValueGetCount(address); i++)
    {
        CFStringRef aLabel = ABMultiValueCopyLabelAtIndex(address, i);
        NSString *addressLabel = [label_dictionary objectForKey:(NSString*)aLabel];
        
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
            [addressLabel release];
        }else if(aLabel)
        	[contact_labels addObject: (NSString*)aLabel];
        else
            [contact_labels addObject: @"Other"];
        
        [contact_values addObject: addressString];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:Address]];
        
        if(addressDictionary)CFRelease(addressDictionary);
        if(aLabel)CFRelease(aLabel);
        [addressString release];
    }
    if(address)CFRelease(address);
    
    // for key and token
    if([[SSEngine getPackPubKeys]length]>0)
    {
        [contact_labels addObject: @"SafeSlinger-PubKey"];
        [contact_values addObject: @""];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:IMPP]];
    }
    
    if([UAirship shared].deviceToken)
    {
        [contact_labels addObject: @"SafeSlinger-Push"];
        [contact_values addObject: @""];
        [contact_selections addObject:[NSNumber numberWithBool:YES]];
        [contact_category addObject:[NSNumber numberWithInt:IMPP]];
    }
    
	//Load the fields read in so far into the selection list
	[ContactInfoTable reloadData];
    
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
    [ExchangeBtn setHidden:NO];
    [delegate saveConactData];
    
	if(book)CFRelease(book);
}


#pragma mark UITableViewDelegate
-(void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow] animated: YES];
	int row = [indexPath row];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
    
    if(cell.tag == 0)
    {
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
-(NSInteger) tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section
{
	return [contact_labels count];
}

-(UITableViewCell *) tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ContactFieldIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	NSInteger row = [indexPath row];
    cell.accessoryType = ([[contact_selections objectAtIndex:row]boolValue] ? UITableViewCellAccessoryCheckmark: UITableViewCellAccessoryNone);
	cell.textLabel.font = [cell.textLabel.font fontWithSize: 13];
    
    NSNumber* cateclass = [contact_category objectAtIndex:row];
    cell.tag = 0;
    switch(cateclass.intValue)
    {
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
    
    switch(cateclass.intValue)
    {
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

@end
