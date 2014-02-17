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

#import "SaveSelectionViewController.h"
#import "SafeSlinger.h"
#import "Base64.h"
#import "KeySlingerAppDelegate.h"
#import <AddressBook/AddressBook.h>
#import "iToast.h"
#import "Utility.h"
#import "VersionCheckMarco.h"
#import "ErrorLogger.h"

@implementation SaveSelectionViewController

@synthesize selectionTable, contactList, engine, selections;
@synthesize delegate, Hint, ImportBtn;

-(void) setup: (CFArrayRef)aList engine: (SafeSlingerExchange *)anEngine
{
	self.engine = anEngine;
	self.contactList = aList;
	if (selections != NULL) free(selections);
	self.selections = malloc(sizeof(BOOL) * CFArrayGetCount(contactList));
	for (int i = 0; i < CFArrayGetCount(contactList); i++)
		selections[i] = YES;
	[selectionTable reloadData];
}


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
	self.view.frame = [[UIScreen mainScreen] applicationFrame];
    
    // customized cancel button
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc]initWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(ExitProtocol:)];
    [self.navigationItem setLeftBarButtonItem:cancelBtn];
    self.navigationItem.hidesBackButton = YES;
    [cancelBtn release];
}

- (void)viewWillAppear:(BOOL)animated
{
    [ImportBtn setTitle:NSLocalizedString(@"btn_Import", @"Import") forState: UIControlStateNormal];
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
    
    // setup hint message
    [Hint setText: NSLocalizedString(@"label_SaveInstruct", @"Exchange Complete!  Select member data to save to your Address Book:")];
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_save", @"End Exchange")
                                                      message:NSLocalizedString(@"help_save", @"When finished, the protocol will reveal a list of the identity data exchanged. Select the contacts you wish to save and press 'Import'.";)
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    [message release];
    message = nil;
}

-(void) ExitProtocol: (id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_Question", @"Question")
                                                    message: NSLocalizedString(@"ask_QuitConfirmation", @"Quit? Are you sure?";)
                                                   delegate: self
                                          cancelButtonTitle: NSLocalizedString(@"btn_No", @"No")
                                          otherButtonTitles: NSLocalizedString(@"btn_Yes", @"Yes"), nil];
    alert.tag = 1;
    [alert show];
    [alert release];
    alert = nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex&&alertView.tag==1)
    {
        // do nothing
        engine.state = ProtocolCancel;
        [engine protocolAbort:[NSString stringWithFormat: NSLocalizedString(@"state_SomeContactsImported", @"%@ contacts imported."), 0]];
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

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc {
    if(ImportBtn)[ImportBtn release];
    if(Hint)[Hint release];
	if(selectionTable)[selectionTable release];
	if(contactList)CFRelease(contactList);
	if(selections)free(selections);
	if(engine)[engine release];
    [super dealloc];
}

-(BOOL) dictionary: (CFDictionaryRef)dictA isEqualTo: (CFDictionaryRef)dictB
{
	int aCount = CFDictionaryGetCount(dictA);
	int bCount = CFDictionaryGetCount(dictB);
	if (aCount != bCount)
		return NO;
	
	CFStringRef aKeys[aCount], bKeys[bCount];
	CFStringRef aValues[aCount], bValues[bCount];
	CFDictionaryGetKeysAndValues(dictA, (const void **)&aKeys, (const void **)&aValues);
	CFDictionaryGetKeysAndValues(dictB, (const void **)&bKeys, (const void **)&bValues);
	for (int i = 0; i < aCount; i++)
	{
		if (![(NSString *)aKeys[i] isEqualToString: (NSString *)bKeys[i]] || ![(NSString *)aValues[i] isEqualToString: (NSString *)bValues[i]])
			return NO;
	}
	return YES;
}

-(IBAction) Import
{
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
            return;
        }
    });
    
    int importedcount = 0;
    int savedcount = 0;
    BOOL hasAccountExist, InsertSucess;
    
	CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
    if (selections)
	{
		for (int i = 0; i < CFArrayGetCount(contactList); i++)
		{
			if (selections[i])
			{
                hasAccountExist = NO;
                InsertSucess = NO;
                
                importedcount++;
                [delegate.activityView EnableProgress:NSLocalizedString(@"prog_SavingContactsToKeyDatabase", @"updating key database...") SecondMeesage:nil ProgessBar:YES];
                
                NSData *keyelement = nil;
                NSData *token = nil;
                NSString *comparedtoken = nil;
                
				ABRecordRef aRecord = CFArrayGetValueAtIndex(contactList, i);
                
                NSString *firstname = (NSString*)ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
                NSString *lastname = (NSString*)ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
                if(firstname==nil&&lastname==nil)
                {
                    [[[[iToast makeText: NSLocalizedString(@"error_VcardParseFailure", @"vCard parse failed.")]
                       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                    continue;
                }
                
                // Get SafeSlinger Fields
                ABMultiValueRef allIMPP = ABRecordCopyValue(aRecord, kABPersonInstantMessageProperty);
                for (CFIndex i = 0; i < ABMultiValueGetCount(allIMPP); i++)
                {
                    CFDictionaryRef anIMPP = ABMultiValueCopyValueAtIndex(allIMPP, i);
                    CFStringRef service = CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey);
                    if ([(NSString*)service caseInsensitiveCompare:@"SafeSlinger-PubKey"] == NSOrderedSame)
                    {
                        keyelement = [Base64 decode:(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey)];
                        keyelement = [NSData dataWithBytes:[keyelement bytes] length:[keyelement length]];
                    }else if([(NSString*)service caseInsensitiveCompare:@"SafeSlinger-Push"] == NSOrderedSame)
                    {
                        comparedtoken = (NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey);
                        token = [Base64 decode:comparedtoken];
                    }
                    if(anIMPP!=NULL)CFRelease(anIMPP);
                }
                if(allIMPP!=NULL)CFRelease(allIMPP);
                
                if([keyelement length]==0)
                {
                    [[[[iToast makeText: NSLocalizedString(@"error_AllMembersMustUpgradeBadKeyFormat", @"All members must upgrade, some are using older key formats.")]
                       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                    continue;
                }
                
                if([token length]==0) {
                    [[[[iToast makeText: NSLocalizedString(@"error_AllMembersMustUpgradeBadPushToken", @"All members must upgrade, some are using older push token formats.")]
                       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                    continue;
                }
                
                int devtype = 0, offset = 0, tokenlen = 0;
                const char* p = [token bytes];
                
                devtype = ntohl(*(int *)(p+offset));
                offset += 4;
                
                tokenlen = ntohl(*(int *)(p+offset));
                offset += 4;
                
                NSString* tokenstr = [NSString stringWithCString:[[NSData dataWithBytes:p+offset length:tokenlen]bytes] encoding:NSASCIIStringEncoding];
                tokenstr = [tokenstr substringToIndex:tokenlen];
                
                // get photo if possible
                NSString* imageData = nil;
                CFDataRef photo = ABPersonCopyImageData(aRecord);
                if(photo!=NULL)
                {
                    UIImage* img = [UIImage imageWithData:(NSData *)photo];
                    imageData = [Base64 encode: UIImageJPEGRepresentation(img, 0.3)];
                    CFRelease(photo);
                }
                
                // instead of using name to check existance, using token to check
                NSString* peer = [delegate.DbInstance SearchRecipient:tokenstr];
                DEBUGMSG(@"peer = %@", peer);
                
                
                NSString* name = [NSString vcardnstring:firstname withLastName:lastname];
                if(firstname!=NULL)CFRelease(firstname);
                if(lastname!=NULL)CFRelease(lastname);
                DEBUGMSG(@"add user: %@", name);
                
                // update token
                if(peer!=nil){
                    DEBUGMSG(@"update Token&Key");
                    if(![delegate.DbInstance UpdateToken:tokenstr User:name Dev:devtype Photo:imageData KeyData:keyelement ExchangeOrIntroduction:YES])
                    {
                        [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateRecipientInDB", @"Unable to update the recipient database.")]
                           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                        continue;
                    }
                }else{
                    DEBUGMSG(@"reg Token&Key");
                    if(![delegate.DbInstance RegisterToken:tokenstr User:name Dev:devtype Photo:imageData  KeyData:keyelement ExchangeOrIntroduction:YES])
                    {
                        [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateRecipientInDB", @"Unable to update the recipient database.")]
                           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                        continue;
                    }
                }
                
                [delegate.activityView EnableProgress:NSLocalizedString(@"prog_SavingContactsToAddressBook", @"updating address book...") SecondMeesage:nil ProgessBar:YES];
                
                // update contact database
                if(peer!=nil||name!=nil)
                {
                    // already exist, check contact database
                    for (CFIndex j = 0; j < CFArrayGetCount(allPeople); j++)
                    {
                        ABRecordRef existing = CFArrayGetValueAtIndex(allPeople, j);
                        CFStringRef f = ABRecordCopyValue(existing, kABPersonFirstNameProperty);
                        CFStringRef l = ABRecordCopyValue(existing, kABPersonLastNameProperty);
                        NSString *existingName = [NSString vcardnstring:(NSString*)f withLastName:(NSString*)l];
                        if(f==NULL&l==NULL)
                        {
                            DEBUGMSG(@"existingName is NULL.");
                            continue;
                        }
                        
                        if ([peer isEqualToString: existingName]||[name isEqualToString: existingName])
                        {
                            // check IMPP field
                            ABMultiValueRef allIMPP = ABRecordCopyValue(existing, kABPersonInstantMessageProperty);
                            for (CFIndex i = 0; i < ABMultiValueGetCount(allIMPP); i++)
                            {
                                CFDictionaryRef anIMPP = ABMultiValueCopyValueAtIndex(allIMPP, i);
                                CFStringRef label = CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey);
                                if([(NSString*)label caseInsensitiveCompare:@"SafeSlinger-Push"] == NSOrderedSame)
                                {
                                    CFStringRef ctoken = CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey);
                                    if([comparedtoken isEqualToString:(NSString *)ctoken])
                                    {
                                        DEBUGMSG(@"Has old contact exisitng.");
                                        hasAccountExist = YES;
                                        // remove it
                                        if(!ABAddressBookRemoveRecord(aBook, existing, &error))
                                        {
                                            [[[[iToast makeText: NSLocalizedString(@"error_ContactUpdateFailed", @"Contact update failed.")]
                                               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                                            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"ERROR: Unable to remove the old record. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
                                            if(anIMPP!=NULL)CFRelease(anIMPP);
                                            continue;
                                        }
                                    }
                                }
                                if(anIMPP!=NULL)CFRelease(anIMPP);
                            }
                            if(allIMPP!=NULL)CFRelease(allIMPP);
                        }
                        if(f!=NULL)CFRelease(f);
                        if(l!=NULL)CFRelease(l);
                    }// end of for
                }
                
                ABRecordRef defaultR = ABAddressBookCopyDefaultSource(aBook);
                CFTypeRef sourceType = ABRecordCopyValue(defaultR, kABSourceTypeProperty);
                int STI = [(NSNumber *)sourceType intValue];
                if(sourceType!=NULL)CFRelease(sourceType);
                CFRelease(defaultR);
                
                if (STI==kABSourceTypeLocal) {
                    DEBUGMSG(@"Store to Local One.");
                    InsertSucess = ABAddressBookAddRecord(aBook, aRecord, &error);
                }else
                {
                    DEBUGMSG(@"Store to Non-local sources.");
                    
                    // copy out all fields in the old namecard
                    CFStringRef f = ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
                    CFStringRef l = ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
                    CFDataRef photo = ABPersonCopyImageData(aRecord);
                    
                    CFTypeRef allIMPP = ABRecordCopyValue(aRecord, kABPersonInstantMessageProperty);
                    CFTypeRef allWebpages = ABRecordCopyValue(aRecord, kABPersonURLProperty);
                    CFTypeRef allEmails = ABRecordCopyValue(aRecord, kABPersonEmailProperty);
                    CFTypeRef allAddresses = ABRecordCopyValue(aRecord, kABPersonAddressProperty);
                    CFTypeRef allPhones = ABRecordCopyValue(aRecord, kABPersonPhoneProperty);
                    
                    // handle local records
                    CFArrayRef sources = ABAddressBookCopyArrayOfAllSources(aBook);
                    for (CFIndex i = 0 ; i < CFArrayGetCount(sources); i++) {
                        ABRecordRef currentSource = CFArrayGetValueAtIndex(sources, i);
                        CFTypeRef ST = ABRecordCopyValue(currentSource, kABSourceTypeProperty);
                        int STII = [(NSNumber *)ST intValue];
                        CFRelease(ST);
                        
                        // possible caes, local, mobileMe, iCloud, and suyn with MAC
                        if(!((STII==kABSourceTypeExchange)||(STII==kABSourceTypeExchangeGAL)))
                        {
                            DEBUGMSG(@"STII = %d", STII);
                            ABRecordRef acopy = ABPersonCreateInSource(currentSource);
                            // copy necessary field from aRecord
                            if(f!=NULL) ABRecordSetValue(acopy, kABPersonFirstNameProperty, f, &error);
                            if(l!=NULL) ABRecordSetValue(acopy, kABPersonLastNameProperty, l, &error);
                            if(photo!=NULL) ABPersonSetImageData(acopy, photo, &error);
                            if(allIMPP!=NULL)
                            {
                                if(ABMultiValueGetCount(allIMPP)>0)
                                    ABRecordSetValue(acopy, kABPersonInstantMessageProperty, allIMPP, &error);
                            }
                            
                            if(allWebpages!=NULL)
                            {
                                if(ABMultiValueGetCount(allWebpages)>0)
                                    ABRecordSetValue(acopy, kABPersonURLProperty, allWebpages, &error);
                            }
                            
                            // found a bug when user pickup a incorrect form for phone numbers.
                            if(allPhones!=NULL)
                            {
                                DEBUGMSG(@"%@", allPhones);
                                if(ABMultiValueGetCount(allPhones)>0)
                                {
                                    ABRecordSetValue(acopy, kABPersonPhoneProperty, allPhones, &error);
                                }
                            }
                            
                            if(allAddresses!=NULL)
                            {
                                if(ABMultiValueGetCount(allAddresses)>0)
                                    ABRecordSetValue(acopy, kABPersonAddressProperty, allAddresses, &error);
                            }
                            
                            if(allEmails!=NULL)
                            {
                                if(ABMultiValueGetCount(allEmails)>0)
                                    ABRecordSetValue(acopy, kABPersonEmailProperty, allEmails, &error);
                            }
                            
                            InsertSucess = ABAddressBookAddRecord(aBook, acopy, &error);
                        }
                        //CFRelease(currentSource);
                    }
                    CFRelease(sources);
                    
                    // release fields
                    if(f)CFRelease(f);
                    if(l)CFRelease(l);
                    if(photo)CFRelease(photo);
                    if(allIMPP)CFRelease(allIMPP);
                    if(allWebpages)CFRelease(allWebpages);
                    if(allAddresses)CFRelease(allAddresses);
                    if(allEmails)CFRelease(allEmails);
                    if(allPhones)CFRelease(allPhones);
                }
                
                if(!InsertSucess){
                    [ErrorLogger ERRORDEBUG: @"ERROR: Unable to Add the new record."];
                }
                if(!InsertSucess&!hasAccountExist)
                {
                    [[[[iToast makeText: NSLocalizedString(@"error_ContactInsertFailed", @"Contact insert failed.")]
                       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                }
                
                savedcount++;
            }
		}
	}
    
	if(!ABAddressBookSave(aBook, &error))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveRecipientInDB", @"Unable to save to the recipient database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"ERROR: Unable to Save ABAddressBook. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
    }else{
        NSString* num = nil;
        if(importedcount==savedcount){
            num = [NSString stringWithFormat:@"%d", importedcount];
        }else{
            num = [NSString stringWithFormat:@"%d/%d", savedcount, importedcount];
        }
        NSString* info = [NSString stringWithFormat: NSLocalizedString(@"state_SomeContactsImported", @"%@ contacts imported."), num];
        [[[[iToast makeText: info]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
    if(allPeople!=NULL)CFRelease(allPeople);
	if(aBook!=NULL)CFRelease(aBook);
	
    free(selections);
    [delegate.activityView.view removeFromSuperview];
	[self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark UITableViewDelegate

-(void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath: [tableView indexPathForSelectedRow] animated: NO];
	int row = [indexPath row];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
	if (cell.accessoryType == UITableViewCellAccessoryNone)
	{
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		selections[row] = YES;
	}
	else if (cell.accessoryType == UITableViewCellAccessoryCheckmark)
	{
		cell.accessoryType = UITableViewCellAccessoryNone;
		selections[row] = NO;
	}
}

#pragma mark UITableViewDataSource

-(NSInteger) numberOfSectionsInTableView: (UITableView *)tableView
{
	return 1;
}

-(NSInteger) tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section
{
	return CFArrayGetCount(contactList);
}

-(UITableViewCell *) tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SaveSelectionIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	NSInteger row = [indexPath row];
	ABRecordRef aRecord = CFArrayGetValueAtIndex(contactList, row);
	
    NSString* fn = (NSString*)ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
    NSString* ln = (NSString*)ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
    cell.textLabel.text = [NSString composite_name:fn withLastName:ln];
    [fn release];
    [ln release];
	
	CFDataRef imageData = ABPersonCopyImageData(aRecord);
	if (imageData)
	{
		UIImage *image = [UIImage imageWithData: (NSData *)imageData];
		cell.imageView.image = image;
    	CFRelease(imageData);
	}else{
        [cell.imageView setImage: [UIImage imageNamed:@"blank_contact.png"]];
    }
    
	if (selections[row]) cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else cell.accessoryType = UITableViewCellAccessoryNone;
    
	return cell;
}

@end
