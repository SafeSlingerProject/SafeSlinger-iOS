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
#import <safeslingerexchange/iToast.h>

@interface ContactManageView ()

@end

@implementation ContactManageView

@synthesize delegate, user_actions, contact_index, contact_photos;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    delegate = [[UIApplication sharedApplication]delegate];
    
    // All cache time entries
    self.navigationItem.title = NSLocalizedString(@"title_MyIdentity", @"My Identity");
    user_actions = [NSMutableDictionary dictionary];
    contact_index = [NSMutableArray array];
    contact_photos = [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated
{
    [user_actions removeAllObjects];
    [contact_index removeAllObjects];
    [contact_photos removeAllObjects];
    
    // has contact already
    [self.user_actions addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 NSLocalizedString(@"menu_UseNoContact", @"Use Name Only"), [NSNumber numberWithInteger:UseNameOnly],
                                                 NSLocalizedString(@"menu_CreateNew", @"Create New"), [NSNumber numberWithInteger:AddNew],
                                                 NSLocalizedString(@"menu_UseAnother", @"Use Another"), [NSNumber numberWithInteger:ReSelect],
                                                 nil]];
    
    if(delegate.IdentityNum>0)
    {
        [self.user_actions setObject: NSLocalizedString(@"menu_Edit", @"Edit") forKey:[NSNumber numberWithInteger:EditOld]];
    }
    
    NSString* name_indb = [delegate.DbInstance GetProfileName];
    
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
    for (int i = 0; i < CFArrayGetCount(allPeople); i++)
    {
        ABRecordRef aRecord = CFArrayGetValueAtIndex(allPeople, i);
        if(ABRecordGetRecordType(aRecord) ==  kABPersonType) // this check execute if it is person group
        {
            NSString *firstname = (__bridge NSString*)ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
            NSString *lastname = (__bridge NSString*)ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
            NSString* compositename = [NSString composite_name:firstname withLastName:lastname];
            // firstname and lastname matches
            if([compositename isEqualToString:name_indb])
            {
                [self.user_actions setObject: [NSString stringWithFormat:NSLocalizedString(@"menu_UseContactPerson", @"Use Contact '%@'"),compositename]
                                      forKey:[NSNumber numberWithInteger:index]];
                [self.contact_index addObject:[NSNumber numberWithInteger:ABRecordGetRecordID(aRecord)]];
                
                // Parse Photo
                CFDataRef photo = ABPersonCopyImageData(aRecord);
                if (photo)
                {
                    UIImage *image = [[UIImage imageWithData: (__bridge NSData *)photo]scaleToSize:CGSizeMake(45.0f, 45.0f)];
                    [self.contact_photos addObject: image];
                    CFRelease(photo);
                }else{
                    [self.contact_photos addObject: [UIImage imageNamed: @"blank_contact.png"]];
                }
                index++;
            }
        }
    }
    
    if(allPeople)CFRelease(allPeople);
    if(aBook)CFRelease(aBook);
}

- (void)viewWillDisappear:(BOOL)animated
{
    
}

- (IBAction) DisplayHow: (id)sender
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_MyIdentity", @"Personal Contact")
                                                      message:NSLocalizedString(@"help_identity_menu", @"You may also change personal data about your identity on this screen by tapping on the button with your name. This will display a menu allowing you to Edit your contact, Create New contact, or Use Another contact.")
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback"), nil];
    [message show];
    message = nil;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex)
    {
        [UtilityFunc SendOpts:self];
    }
}

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
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


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [user_actions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ContactOptCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    cell.textLabel.text = [[user_actions allValues]objectAtIndex:indexPath.row];
    cell.detailTextLabel.text = nil;
    NSInteger key = [[[user_actions allKeys]objectAtIndex:indexPath.row]integerValue];
    if(key>=0)
    {
        [cell.imageView setImage:[contact_photos objectAtIndex:key]];
    }
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger key = [[[user_actions allKeys]objectAtIndex:indexPath.row]integerValue];
    
    switch (key) {
        case UseNameOnly:
            delegate.IdentityNum = NonLink;
            // remove contact file if necessary
            [delegate removeContactLink];
            [self performSegueWithIdentifier:@"FinishEditContact" sender:self];
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
            [delegate saveConactDataWithoutChaningName: (int)[[contact_index objectAtIndex:key]integerValue] ];
            [self performSegueWithIdentifier:@"FinishEditContact" sender:self];
            break;
    }
}

-(void) editOldContact
{
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            return;
        }
    });
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, delegate.IdentityNum);
    ABPersonViewController *personView = [[ABPersonViewController alloc] init];
    
    if(person)
    {
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

- (void)ReturnFromEditView
{
    // check name if it existed
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
        }
    });
    
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(aBook, delegate.IdentityNum);
    NSString* FN = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonFirstNameProperty));
    NSString* LN = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonLastNameProperty));
    
    if ((!FN)&&(!LN))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else
    {
        [delegate saveConactData: delegate.IdentityNum Firstname:FN Lastname:LN];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if(aBook)CFRelease(aBook);
}

- (void) addNewContact
{
    ABNewPersonViewController *picker = [[ABNewPersonViewController alloc] init];
    picker.newPersonViewDelegate = self;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void) selectAnotherContact
{
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark ABPeoplePickerNavigationControllerDelegate
-(void) peoplePickerNavigationControllerDidCancel: (ABPeoplePickerNavigationController *)peoplePicker
{
    //user canceled, no new contact selected
    [peoplePicker dismissViewControllerAnimated:YES completion:nil];
}

-(BOOL) peoplePickerNavigationController: (ABPeoplePickerNavigationController *)peoplePicker
	  shouldContinueAfterSelectingPerson: (ABRecordRef)person
{
    // check name field is existed.
    NSString* FN = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonFirstNameProperty));
    NSString* LN = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonLastNameProperty));
    if(!FN&&!LN)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing2", @"This contact is missing a name, please reselect.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }else{
        [delegate saveConactData: ABRecordGetRecordID(person) Firstname:FN Lastname:LN];
        [self performSegueWithIdentifier:@"FinishEditContact" sender:self];
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
	return YES;
}

#pragma mark ABNewPersonViewControllerDelegate methods
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonViewController didCompleteWithNewPerson:(ABRecordRef)person
{
    if (person)
    {
        NSString* FN = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonFirstNameProperty));
        NSString* LN = (__bridge NSString *)(ABRecordCopyValue(person, kABPersonLastNameProperty));
        if (!FN&&!LN)
        {
            [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }else{
            [delegate saveConactData: ABRecordGetRecordID(person) Firstname:FN Lastname:LN];
            [self performSegueWithIdentifier:@"FinishEditContact" sender:self];
        }
    }else{
        [newPersonViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

/*
#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
