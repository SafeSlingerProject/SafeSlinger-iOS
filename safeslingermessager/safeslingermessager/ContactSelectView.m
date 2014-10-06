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

#import <AddressBook/AddressBook.h>
#import <safeslingerexchange/iToast.h>

@interface ContactEntry ()

@end

@implementation ContactEntry
@synthesize fname, lname, photo, pushtoken, keyid, devType, keygenDate, exchangeDate, contact_id, ex_type;

-(NSString*)PrintContact
{
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

@end

@implementation ContactSelectView

@synthesize safeslingers;
@synthesize delegate, UserInfo, showRecent;
@synthesize Hint, SwitchHint;
@synthesize selectedUser;
@synthesize parent;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    // Hints
    Hint = [[UILabel alloc] initWithFrame:CGRectZero];
    Hint.backgroundColor = [UIColor clearColor];
    Hint.opaque = NO;
    Hint.frame = CGRectMake(10.0, 0.0, self.view.frame.size.width-20.0, 80.0);
    Hint.lineBreakMode = NSLineBreakByWordWrapping;
    Hint.numberOfLines = 0;
    
    // Switch
    showRecent = [[UISwitch alloc] initWithFrame: CGRectZero];
    showRecent.frame = CGRectMake(10.0, 30.0, showRecent.frame.size.width, showRecent.frame.size.height);
    [showRecent addTarget: self action: @selector(ShowMostRecently:) forControlEvents: UIControlEventValueChanged];
    
    SwitchHint = [[UILabel alloc] initWithFrame:CGRectZero];
    SwitchHint.backgroundColor = [UIColor clearColor];
    SwitchHint.opaque = NO;
    SwitchHint.frame = CGRectMake(25.0+showRecent.frame.size.width, 25.0, 150.0, 30.0);
    SwitchHint.numberOfLines = 0;
    
    safeslingers = [[NSMutableArray alloc]initWithCapacity:0];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 2.0; //seconds
    lpgr.delegate = self;
    [self.tableView addGestureRecognizer:lpgr];
    
    UserInfo = [[UIAlertView alloc]
                initWithTitle: NSLocalizedString(@"title_RecipientDetail", @"Recipient Detail")
                message:nil
                delegate:self
                cancelButtonTitle: NSLocalizedString(@"btn_Close", @"Close")
                otherButtonTitles: nil];
}

- (IBAction) DisplayHow: (id)sender
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_PickRecipient", @"Recipients")
                                                      message:NSLocalizedString(@"help_PickRecip", @"Contacts with SafeSlinger keys are displayed here, select one to send your message to.")
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

- (void)viewWillAppear:(BOOL)animated
{
    showRecent.on = YES;
    [safeslingers setArray: [delegate.DbInstance LoadRecentRecipients:NO]];
    [self DisplayTitle];
    [self.tableView reloadData];
}

-(void)DisplayTitle
{
    if(ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized)
    {
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
        
        self.navigationItem.title = [NSString stringWithFormat: @"%@(%lu/%ld)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), (unsigned long)[safeslingers count], total];
    }else{
        self.navigationItem.title = [NSString stringWithFormat: @"%@(%lu)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), (unsigned long)[safeslingers count]];
    }
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    
    if (indexPath)
    {
        ContactEntry *sc = [self.safeslingers objectAtIndex:indexPath.row];
        [UserInfo setMessage: [sc PrintContact]];
        [UserInfo show];
    }
}


- (void)viewWillDisappear:(BOOL)animated
{
    if(safeslingers) [safeslingers removeAllObjects];
    safeslingers = nil;
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
    return [safeslingers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ContactCell";
    ContactCellView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    ContactEntry *entry = [self.safeslingers objectAtIndex: indexPath.row];
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
    
    if(entry.ex_type==Exchanged)
        cell.ExchangeLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_exchanged", @"exchanged"), exchangedate];
    else
        cell.ExchangeLabel.text = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"label_introduced", @"introduced"), exchangedate];
    
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
    
    if(entry.photo)
    {
        [cell.UserPhoto setImage: [UIImage imageWithData:entry.photo]];
    }else {
        [cell.UserPhoto setImage: [UIImage imageNamed: @"blank_contact.png"]];
    }
    
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (CGFloat)(98.0f);
}

- (void)ShowMostRecently: (id)sender
{
    // reload
    [safeslingers removeAllObjects];
    if(showRecent.on)
    {
        [safeslingers addObjectsFromArray:[delegate.DbInstance LoadRecentRecipients:NO]];
    }else{
        [safeslingers addObjectsFromArray:[delegate.DbInstance LoadRecipients:NO]];
    }
    [self.tableView reloadData];
}

#pragma mark - Table view delegate
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // create the parent view that will hold header Label
    UIView* customView = nil;
    
    if([safeslingers count]>0) {
        customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 80.0)];
        
        if([self.restorationIdentifier isEqualToString:@"ContactSelectForIntroduce"])
        {
            [Hint setText: NSLocalizedString(@"label_InstSendInvite", @"Pick recipients to introduce securely:")];
        }else if([self.restorationIdentifier isEqualToString:@"ContactSelectForCompose"]){
            [Hint setText: NSLocalizedString(@"label_InstRecipients", @"Pick a recipient to send a message to:")];
        }
        
        // add Switch
        [customView addSubview: showRecent];
        // Add Switch Hint
        [SwitchHint setText:NSLocalizedString(@"label_MostRecentOnly", @"Most recent only")];
        [customView addSubview: SwitchHint];
    }
    else {
        
        customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, self.view.frame.size.width-20.0, 150.0)];
        // no slingers
        [Hint setText: NSLocalizedString(@"label_InstNoRecipients", @"To add recipients, you must first Sling Keys with one or more other users at the same time. You may also send a Sling Keys contact invitation from the menu.")];
    }
    [Hint sizeToFit];
    [customView addSubview: Hint];
    [customView layoutIfNeeded];
    
    return customView;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if([safeslingers count]>0) return 90.0;
    else return 200.0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        ContactEntry *sc = [safeslingers objectAtIndex:indexPath.row];
        [delegate.DbInstance RemoveRecipient: sc.keyid];
        [self.safeslingers removeObjectAtIndex:indexPath.row];
		[self.tableView reloadData];
        [self DisplayTitle];
        
        // show hint to user
        [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_RecipientsDeleted", @"%d recipients deleted."), 1]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        
        // Try to backup
        [delegate.BackupSys RecheckCapability];
        [delegate.BackupSys PerformBackup];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    
    if([self.restorationIdentifier isEqualToString:@"ContactSelectForIntroduce"])
    {
        if(parent)
        {
            IntroduceView* introduction = (IntroduceView*) parent;
            if([introduction EvaluateContact: [safeslingers objectAtIndex: indexPath.row]])
                [introduction SetupContact:[safeslingers objectAtIndex: indexPath.row]];
        }
    }else if([self.restorationIdentifier isEqualToString:@"ContactSelectForCompose"]){
        if(parent)
        {
            ComposeView* compose = (ComposeView*)parent;
            compose.selectedUser = [safeslingers objectAtIndex: indexPath.row];
            [compose UpdateRecipient];
        }
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

@end
