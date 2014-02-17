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

#import "SSContactSelector.h"
#import "MessageComposer.h"
#import "SecureIntroduce.h"
#import <AddressBookUI/AddressBookUI.h>
#import "SSContactCell.h"
#import "KeySlingerAppDelegate.h"
#import "iToast.h"
#import "Utility.h"
#import "VersionCheckMarco.h"
#import "ErrorLogger.h"

@interface SSContactSelector ()

@end

@implementation SSContactEntry
@synthesize fname, lname, photo, hasSlinger, pushtoken, keyid, devType, keygenDate, exchangeDate, contact_id, ex_type;

-(id)init
{
    if(self=[super init])
    {
        
    }
    return self;
}

-(void)dealloc
{
    [fname release]; fname = nil;
    [lname release]; lname = nil;
    [keyid release]; keyid = nil;
    [pushtoken release]; pushtoken = nil;
    [keygenDate release]; keygenDate = nil;
    [exchangeDate release]; exchangeDate = nil;
    if(!photo)[photo release]; photo = nil;
    [super dealloc];
}


@end

@implementation SSContactSelector

@synthesize safeslingers;
@synthesize delegate, MsgOrIntro, alreadyShow, showRecent;
@synthesize Hint,SwitchHint;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // initial array
        self.delegate = [[UIApplication sharedApplication]delegate];
        self.tableView.allowsMultipleSelectionDuringEditing = NO;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // ? button
    UIButton * infoButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0, 30.0f)];
    [infoButton setImage:[UIImage imageNamed:@"info.png"] forState:UIControlStateNormal];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HomeButton];
    [HomeButton release];
    HomeButton = nil;
    [infoButton release];
    infoButton = nil;
    
    // Switch
    showRecent = [[UISwitch alloc] initWithFrame: CGRectZero];
    showRecent.frame = CGRectMake(10.0, 50.0, showRecent.frame.size.width, showRecent.frame.size.height);
    [showRecent addTarget: self action: @selector(ShowMostRecently:) forControlEvents: UIControlEventValueChanged];
    
    // Hints
    Hint = [[UILabel alloc] initWithFrame:CGRectZero];
    Hint.backgroundColor = [UIColor clearColor];
    Hint.opaque = NO;
    Hint.frame = CGRectMake(10.0, 0.0, 300.0, 80.0);
    Hint.lineBreakMode = NSLineBreakByWordWrapping;
    Hint.numberOfLines = 0;
    
    SwitchHint = [[UILabel alloc] initWithFrame:CGRectZero];
    SwitchHint.backgroundColor = [UIColor clearColor];
    SwitchHint.opaque = NO;
    SwitchHint.frame = CGRectMake(15.0+showRecent.frame.size.width, 45.0, 150.0, 30.0);
    SwitchHint.lineBreakMode = NSLineBreakByWordWrapping;
    SwitchHint.numberOfLines = 0;
}


- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_PickRecipient", @"Recipients")
                                                      message:NSLocalizedString(@"help_PickRecip", @"Contacts with SafeSlinger keys are displayed here, select one to send your message to.")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    [message release];
    message = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    // get showRecent preference
    int preference = 0;
    [[delegate.DbInstance GetConfig:@"ShowMostRecently"]getBytes:&preference length:sizeof(preference)];
    if(preference)
    {
        [showRecent setOn:YES];
    }else{
        [showRecent setOn:NO];
    }
    
    // see who is the parent
    UIViewController* root = [[self.delegate.navController viewControllers]objectAtIndex:[[self.delegate.navController viewControllers]count]-2];
    MsgOrIntro = ![[[root class]description]isEqualToString:@"MessageComposer"];
    if(showRecent.on)
        safeslingers = [[NSMutableArray alloc]initWithArray: [delegate.DbInstance LoadRecentRecipients:MsgOrIntro]];
    else
        safeslingers = [[NSMutableArray alloc]initWithArray: [delegate.DbInstance LoadRecipients:MsgOrIntro]];
            
    [self.tableView reloadData];
    [self DisplayTitle];

    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 2.0; //seconds
    lpgr.delegate = self;
    [self.tableView addGestureRecognizer:lpgr];
    [lpgr release];
}

-(void)DisplayTitle
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
        if(!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        }
    });
    
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
    int total = CFArrayGetCount(allPeople)-1;
    if(!allPeople)CFRelease(allPeople);
    if(!aBook)CFRelease(aBook);
    
    self.navigationItem.title = [NSString stringWithFormat: @"%@(%d/%d)", NSLocalizedString(@"title_PickRecipient", @"Recipients"), [safeslingers count], total];
    
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    
    if (indexPath)
    {
        if(!alreadyShow)
        {
            alreadyShow = YES;
            SSContactEntry *sc = [self.safeslingers objectAtIndex:indexPath.row];
            // plaintext
            NSMutableString* detail = [NSMutableString stringWithCapacity:0];
            
            [detail appendFormat:@"Name:%@\n\n", [NSString composite_name:sc.fname withLastName:sc.lname]];
            [detail appendFormat:@"Key ID:\n%@\n\n", sc.keyid];
            [detail appendFormat:@"Token:\n%@\n\n", sc.pushtoken];
            [detail appendFormat:@"KDate:%@\n\n", sc.keygenDate];
            switch (sc.ex_type) {
                case Exchanged:
                    [detail appendFormat:@"Type: %@\n\n", NSLocalizedString(@"label_exchanged", @"exchanged")];
                    break;
                case Introduced:
                    [detail appendFormat:@"Type: %@\n\n", NSLocalizedString(@"label_introduced", @"introduced")];
                    break;
                default:
                    break;
            }
            
            [detail appendFormat:@"EDate:%@\n\n", sc.exchangeDate];
            
            switch (sc.devType) {
                case Android:
                    [detail appendString:@"Dev: Android\n\n"];
                    break;
                case iOS:
                    [detail appendString:@"Dev: iOS\n\n"];
                    break;
                default:
                    break;
            }
            
            [detail appendFormat:@"Public Key:\n%@", [delegate.DbInstance QueryStringInTokenTableByKeyID:sc.keyid Field: @"pkey"]];
            
            UIAlertView *alertUser = [[UIAlertView alloc]
                                      initWithTitle: NSLocalizedString(@"title_RecipientDetail", @"Recipient Detail")
                                      message:detail
                                      delegate:self
                                      cancelButtonTitle: NSLocalizedString(@"btn_Close", @"Close")
                                      otherButtonTitles: nil];
            alertUser.tag = 1;
            
            for (UIView *view in alertUser.subviews) {
                DEBUGMSG(@"class: %@", [view class]);
                if([[view class] isSubclassOfClass:[UILabel class]]) {
                    [((UILabel*)view) setTextAlignment:NSTextAlignmentLeft];
                }
            }
            
            [alertUser show];
            [alertUser release];
            alertUser = nil;
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        case 1:
            alreadyShow = NO;
            break;
        default:
            break;
    }
}


- (void)viewWillDisappear:(BOOL)animated
{
    if(safeslingers){
        [safeslingers removeAllObjects];
        [safeslingers release];
    }
    safeslingers = nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
        SSContactEntry *sc = [self.safeslingers objectAtIndex:indexPath.row];
        [delegate.DbInstance RemoveRecipient: sc.pushtoken];
        [self.safeslingers removeObjectAtIndex:indexPath.row];
		[self.tableView reloadData];
        [self DisplayTitle];
        
        // show hint to user
        [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_RecipientsDeleted", @"%d recipients deleted."), 1]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc
{
    if(safeslingers)[safeslingers release];
    [SwitchHint release];
    [Hint release];
    [showRecent release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.safeslingers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SSContactCell";
    
    SSContactCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"SSContactCell" owner:nil options:nil];
        cell = (SSContactCell *)[nib objectAtIndex:0];
    }
    
    SSContactEntry *entry = [self.safeslingers objectAtIndex: indexPath.row];
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
    [formatter release];
    
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
        [cell.UserPhoto setImage:[UIImage imageWithData:entry.photo]];
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
    int mode = (showRecent.on ? 1: 0);
    DEBUGMSG(@"mode = %d", mode);
    [safeslingers removeAllObjects];
    if(showRecent.on)
    {
        [safeslingers addObjectsFromArray:[delegate.DbInstance LoadRecentRecipients:MsgOrIntro]];
        [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &mode length: sizeof(mode)] withTag:@"ShowMostRecently"];
    }else{
        [safeslingers addObjectsFromArray:[delegate.DbInstance LoadRecipients:MsgOrIntro]];
        [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &mode length: sizeof(mode)] withTag:@"ShowMostRecently"];
    }
    [self.tableView reloadData];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // create the parent view that will hold header Label
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(10.0, 0.0, 300.0, 90.0)];
    
    if([self.safeslingers count]>0) {
        // get showRecent preference
        int preference = 0;
        [[delegate.DbInstance GetConfig:@"ShowMostRecently"]getBytes:&preference length:sizeof(preference)];
        if(preference)
        {
            [showRecent setOn:YES];
        }else{
            [showRecent setOn:NO];
        }
        if(MsgOrIntro)
        {
            [Hint setText: NSLocalizedString(@"label_InstSendInvite", @"Pick recipients to introduce securely:")];
        }else {
            [Hint setText: NSLocalizedString(@"label_InstRecipients", @"Pick a recipient to send a message to:")];
        }
        // add Switch
        [customView addSubview: showRecent];
        // Add Switch Hint
        [SwitchHint setText:NSLocalizedString(@"label_MostRecentOnly", @"Most recent only")];
        [customView addSubview: SwitchHint];
    }
    else {
        // no slingers
        [Hint setText: NSLocalizedString(@"label_InstNoRecipients", @"No recipients. Find another SafeSlinger user nearby and touch the 'Sling Keys' tab to share keys.")];
    }
    [customView addSubview: Hint];
    
    return customView;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 90.0;
}


#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SSContactEntry *entry = [self.safeslingers objectAtIndex: indexPath.row];
    // Navigation logic may go here. Create and push another view controller.
    UIViewController* root = [[self.delegate.navController viewControllers]objectAtIndex:[[self.delegate.navController viewControllers]count]-2];
    if(MsgOrIntro)
    {
        SecureIntroduce *precontroller = (SecureIntroduce*)root;
        [precontroller setRecipient: entry];
    }else {
        MessageComposer *precontroller = (MessageComposer*)root;
        [precontroller setRecipient: entry];
    }
    
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    [self.delegate.navController popViewControllerAnimated:YES];
}

@end
