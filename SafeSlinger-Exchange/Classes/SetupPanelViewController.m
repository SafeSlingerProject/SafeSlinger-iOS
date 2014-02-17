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

#import "SetupPanelViewController.h"
#import "KeySlingerAppDelegate.h"
#import "SSEngine.h"
#import "BackupCloud.h"
#import "iToast.h"
#import "VersionCheckMarco.h"
#import "Utility.h"

#import "UAirship.h"
#import "UAPush.h"

#import "ErrorLogger.h"

@interface SetupPanelViewController ()

@end

@implementation SetupPanelViewController

@synthesize delegate;
@synthesize phonefield, Lnamefield, Fnamefield, emailfield, ptypeBtn, etypeBtn, backinfo, instruction;
@synthesize etypes, ptypes, index, select_1, select_2, id_dummy;
@synthesize label1, label2, label3, recoverytry;
@synthesize HelpBtn;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        delegate = [[UIApplication sharedApplication]delegate];
        BGQueue = dispatch_queue_create("safeslinger.background.queue", NULL);
        self.etypes = [NSDictionary dictionaryWithObjectsAndKeys:
                       NSLocalizedString(@"label_hometag", @"home"), @"_$!<Home>!$_",
                       NSLocalizedString(@"label_worktag", @"work"), @"_$!<Work>!$_",
                       NSLocalizedString(@"label_othertag", @"other"), @"_$!<Other>!$_",
                       nil];
        
        self.ptypes =  [NSDictionary dictionaryWithObjectsAndKeys:
                        NSLocalizedString(@"label_mobiletag", @"mobile"), @"_$!<Mobile>!$_",
                        @"iPhone", @"iPhone",
                        NSLocalizedString(@"label_hometag",@"home"), @"_$!<Home>!$_",
                        NSLocalizedString(@"label_worktag", @"work"), @"_$!<Work>!$_",
                        NSLocalizedString(@"label_othertag", @"other"), @"_$!<Other>!$_",
                        nil];
        _originalFrame = self.view.frame;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.title = NSLocalizedString(@"title_find", @"Setup");
    // Do any additional setup after loading the view from its nib.
    [ptypeBtn setTitle:[[ptypes allValues] objectAtIndex:3] forState:UIControlStateNormal];
    select_1 = 3;
    [etypeBtn setTitle:[[etypes allValues] objectAtIndex:0] forState:UIControlStateNormal];
    select_2 = 0;
    [instruction setText:NSLocalizedString(@"label_FindInstruct", "Choose the data you wish to represent you. Your data can only be sent to other contacts, securely, at the time of your choosing.")];
    instruction.adjustsFontSizeToFitWidth = YES;
    [label1 setText:NSLocalizedString(@"label_ContactName", @"Your Name")];
    [label2 setText:NSLocalizedString(@"label_ContactPhone", @"Your Phone")];
    [label3 setText:NSLocalizedString(@"label_ContactEmail", @"Your Email")];
    [Fnamefield setPlaceholder:NSLocalizedString(@"label_FirstName", @"First Name")];
    [Lnamefield setPlaceholder:NSLocalizedString(@"label_LastName", @"Last Name")];
    [phonefield setPlaceholder:NSLocalizedString(@"label_ContactPhone", @"Your Phone")];
    [emailfield setPlaceholder:NSLocalizedString(@"label_ContactEmail", @"Your Email")];
    
    // ? button
    UIButton* infoButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0, 30.0f)];
    [infoButton setImage:[UIImage imageNamed:@"help.png"] forState:UIControlStateNormal];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    HelpBtn = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HelpBtn];
    [infoButton release];
    infoButton = nil;
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc]
                                       initWithTitle:NSLocalizedString(@"btn_Done", @"Done")
                                       style:UIBarButtonItemStyleDone
                                       target:self
                                       action:@selector(createProfile)];
    self.navigationItem.leftBarButtonItem = rightBarButton;
    [rightBarButton release];
    
    if(delegate.backtool.CloudEnabled){
        backinfo.text = NSLocalizedString(@"label_iCloudEnable", @"SafeSlinger iCloud is enabled. Tap the 'Done' button when finished.");
    }else {
        backinfo.text = NSLocalizedString(@"label_TouchToConfigureBackupSettings", @"You may optionally enable SafeSlinger iCloud backup in iOS Settings. Tap the 'Done' button when finished.");
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [emailfield resignFirstResponder];
    [phonefield resignFirstResponder];
    [Fnamefield resignFirstResponder];
    [Lnamefield resignFirstResponder];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShown:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [emailfield resignFirstResponder];
    [phonefield resignFirstResponder];
    [Fnamefield resignFirstResponder];
    [Lnamefield resignFirstResponder];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)keyboardWillShown:(NSNotification *)notification
{
    // make it scrollable
    UIScrollView *tempScrollView=(UIScrollView *)self.view;
    tempScrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height*1.5);
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    UIScrollView *tempScrollView=(UIScrollView *)self.view;
    tempScrollView.contentSize=CGSizeMake(_originalFrame.size.width,_originalFrame.size.height);
}

- (void)createProfile
{
    [emailfield resignFirstResponder];
    [phonefield resignFirstResponder];
    [Fnamefield resignFirstResponder];
    [Lnamefield resignFirstResponder];
    
    // check name fields
    if([Fnamefield.text length]==0&&[Lnamefield.text length]==0)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return;
    }
    
    // check if the same information appearing in contact book
    self.id_dummy = [self CheckIdentityExist];
    DEBUGMSG(@"user contact id = %d", id_dummy);
    
    if(self.id_dummy>=0)
    {
        // check key file existing
        if(![SSEngine checkCredentialExist])
        {
            // genkey first, locked all components
            [self SetComponentsLocked:YES];
            [delegate.activityView EnableProgress:NSLocalizedString(@"prog_GeneratingKey", @"generating key, this can take a while...") SecondMeesage:@"" ProgessBar:YES];
            [delegate.activityView UpdateProgessBar:0.0f];
            
            dispatch_async(BGQueue, ^(void) {
                [self GenKeyBackground];
            });
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self MoveProgress];
            });
            
        }else{
            // goto genkeydone
            [self buildPassphrase];
        }
    }
}

-(void)SetComponentsLocked:(BOOL)lock
{
    etypeBtn.enabled = ptypeBtn.enabled = emailfield.enabled = Fnamefield.enabled = Lnamefield.enabled = phonefield.enabled = !lock;
}

- (void)GenKeyBackground
{
    if([SSEngine GenKeyPairForENC]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [delegate.activityView UpdateProgessBar:0.79f];
        });
    }
    if([SSEngine GenKeyPairForSIGN]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [delegate.activityView UpdateProgessBar:0.99f];
        });
    }
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [delegate.activityView DisableProgress];
        [self SetComponentsLocked:NO];
        [self buildPassphrase];
    });
}

- (void)buildPassphrase
{
    if(id_dummy==0) {
        // add a new contact
        [self AddNewContact];
    }else{
        // update contact information
        [self UpdateContact:id_dummy];
    }
    delegate.myID = id_dummy;
    [delegate saveConactData];
    [delegate CheckIdentity];
    // Start Passphrase Setup
    [delegate.navController popToRootViewControllerAnimated:YES];
    [delegate Login];
}

- (void) MoveProgress {
    float actual = [delegate.activityView.progress progress];
    if (actual < 0.94) {
        [delegate.activityView UpdateProgessBar:actual + 0.06];
        [NSTimer scheduledTimerWithTimeInterval:4.0f target:self selector:@selector(MoveProgress) userInfo:nil repeats:NO];
    }
}

-(void) AddNewContact
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
            return;
        }
    });
    
    ABRecordRef aRecord = ABPersonCreate();
	if(aRecord){
        // add new fileds
        if(Fnamefield.text.length>0) ABRecordSetValue(aRecord, kABPersonFirstNameProperty, Fnamefield.text, &error);
        if(Lnamefield.text.length>0) ABRecordSetValue(aRecord, kABPersonLastNameProperty, Lnamefield.text, &error);
        if(emailfield.text.length>0)
        {
            ABMutableMultiValueRef allEmails = ABMultiValueCreateMutable(kABMultiStringPropertyType);
            ABMultiValueAddValueAndLabel(allEmails, (CFStringRef)emailfield.text, (CFStringRef)[[etypes allKeys]objectAtIndex:select_2], nil);
            ABRecordSetValue(aRecord, kABPersonEmailProperty, allEmails, &error);
            if(allEmails)CFRelease(allEmails);
        }
        if(phonefield.text.length>0)
        {
            ABMutableMultiValueRef allPhones = ABMultiValueCreateMutable(kABMultiStringPropertyType);
            ABMultiValueAddValueAndLabel(allPhones, (CFStringRef)phonefield.text, (CFStringRef)[[ptypes allKeys]objectAtIndex:select_1], nil);
            ABRecordSetValue(aRecord, kABPersonPhoneProperty, allPhones, &error);
            if(allPhones)CFRelease(allPhones);
        }
        // add VCard and update database
        if(!ABAddressBookAddRecord(aBook, aRecord, &error))
        {
            [[[[iToast makeText: NSLocalizedString(@"error_ContactInsertFailed", @"Contact insert failed.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Unable to Add the new record. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
        }
    }
    
	if(!ABAddressBookSave(aBook, &error)) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Unable to save ABAddressBook. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
        [[[[iToast makeText: NSLocalizedString(@"error_contactCreationFailure", @"Contact creation failed.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
    id_dummy = ABRecordGetRecordID(aRecord);
	if(aBook)CFRelease(aBook);
}

-(void) UpdateContact:(NSInteger)contactID
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
            return;
        }
    });
    
	ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, contactID);
	if(aRecord){
        // update
        if(Fnamefield.text.length>0)
            ABRecordSetValue(aRecord, kABPersonFirstNameProperty, Fnamefield.text, &error);
        if(Lnamefield.text.length>0)
            ABRecordSetValue(aRecord, kABPersonLastNameProperty, Lnamefield.text, &error);
        
        if(emailfield.text.length>0)
        {
            ABMultiValueRef emailfiels = ABRecordCopyValue(aRecord, kABPersonEmailProperty);
            ABMutableMultiValueRef multiEmail = ABMultiValueCreateMutableCopy(emailfiels);
            
            BOOL repeat = NO;
            for(int j=0; j<ABMultiValueGetCount(emailfiels) ; j++)
            {
                CFStringRef label = ABMultiValueCopyLabelAtIndex(emailfiels, j);
                if([[[etypes allKeys]objectAtIndex:select_2]isEqualToString:(NSString*)label])
                {
                    ABMultiValueReplaceValueAtIndex(multiEmail, emailfield.text, j);
                    repeat = YES;
                }
                if(label!=NULL)CFRelease(label);
            }
            if(!repeat) ABMultiValueAddValueAndLabel(multiEmail, emailfield.text, (CFStringRef)[[etypes allKeys]objectAtIndex:select_2], NULL);
            ABRecordSetValue(aRecord, kABPersonEmailProperty, multiEmail, &error);
            
            if(multiEmail)CFRelease(multiEmail);
            if(emailfiels)CFRelease(emailfiels);
        }
        
        if(phonefield.text.length>0)
        {
            ABMultiValueRef phonefields = ABRecordCopyValue(aRecord, kABPersonPhoneProperty);
            ABMutableMultiValueRef multiPhone = ABMultiValueCreateMutableCopy(phonefields);
            BOOL repeat = NO;
            for(int j=0; j<ABMultiValueGetCount(phonefields) ; j++)
            {
                CFStringRef label = ABMultiValueCopyLabelAtIndex(phonefields, j);
                if([[[ptypes allKeys]objectAtIndex:select_1]isEqualToString:(NSString*)label])
                {
                    ABMultiValueReplaceValueAtIndex(multiPhone, phonefield.text, j);
                    repeat = YES;
                }
                if(label)CFRelease(label);
            }
            if(!repeat) ABMultiValueAddValueAndLabel(multiPhone, phonefield.text, (CFStringRef)[[ptypes allKeys]objectAtIndex:select_1], NULL);
            ABRecordSetValue(aRecord, kABPersonPhoneProperty, multiPhone, &error);
            if(multiPhone)CFRelease(multiPhone);
            if(phonefields)CFRelease(phonefields);
        }
    }
    
	if(!ABAddressBookSave(aBook, &error)) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Unable to save ABAddressBook. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
        [[[[iToast makeText: NSLocalizedString(@"error_ContactUpdateFailed", @"Contact update failed.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }
    
	if(aBook)CFRelease(aBook);
}

- (ABRecordID)CheckIdentityExist
{
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return -1;
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
    
    ABRecordID retperson = 0;
    NSMutableArray *match_ppl = [NSMutableArray arrayWithCapacity:0];
    
	CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
	for (int i = 0; i < CFArrayGetCount(allPeople); i++)
    {
        ABRecordRef aRecord = CFArrayGetValueAtIndex(allPeople, i);
        if(ABRecordGetRecordType(aRecord) ==  kABPersonType) // this check execute if it is person group
        {
            NSString *firstname = (NSString*)ABRecordCopyValue(aRecord, kABPersonFirstNameProperty);
            NSString *lastname = (NSString*)ABRecordCopyValue(aRecord, kABPersonLastNameProperty);
            // firstname and lastname matches
            if([firstname isEqualToString:Fnamefield.text]&&[lastname isEqualToString:Lnamefield.text])
                [match_ppl addObject:aRecord];
            [firstname release];
            [lastname release];
        }
    }
    
    NSCountedSet *countset = [NSCountedSet setWithArray:match_ppl];
    if(emailfield.text.length>0)
    {
        for (int i = 0; i < [match_ppl count]; i++)
        {
            ABRecordRef aRecord = [match_ppl objectAtIndex:i];
            // check email field
            ABMultiValueRef emailfiels = ABRecordCopyValue(aRecord, kABPersonEmailProperty);
            for(int j=0; j<ABMultiValueGetCount(emailfiels) ; j++)
            {
                CFStringRef type = ABMultiValueCopyLabelAtIndex(emailfiels, j);
                CFStringRef value = ABMultiValueCopyValueAtIndex(emailfiels, j);
                // email type & value matches
                if([[[etypes allKeys]objectAtIndex:select_2]isEqualToString:(NSString*)type]&&[emailfield.text isEqualToString: (NSString*)value])
                {
                    // weight+1
                    [countset addObject:aRecord];
                }
                if(type)CFRelease(type);
                if(value)CFRelease(value);
            }
            if(emailfiels)CFRelease(emailfiels);
        }
    }
    
    if(phonefield.text.length>0)
    {
        for (int i = 0; i < [match_ppl count]; i++)
        {
            ABRecordRef aRecord = [match_ppl objectAtIndex:i];
            // check phone field
            ABMultiValueRef phonefields = ABRecordCopyValue(aRecord, kABPersonPhoneProperty);
            for(int j=0; j<ABMultiValueGetCount(phonefields) ; j++)
            {
                CFStringRef type = ABMultiValueCopyLabelAtIndex(phonefields, j);
                CFStringRef value = ABMultiValueCopyValueAtIndex(phonefields, j);
                
                if([[[ptypes allKeys]objectAtIndex:select_1]isEqualToString:(NSString*)type])
                {
                    // same fields, check values
                    NSString *convertNumber1 = [(NSString*)value stringByReplacingOccurrencesOfString:@"[^0-9]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [(NSString*)value length])];
                    NSString *convertNumber2 = [phonefield.text stringByReplacingOccurrencesOfString:@"[^0-9]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [phonefield.text length])];
                    // weight+2
                    if([convertNumber1 isEqualToString:convertNumber2])
                    {
                        [countset addObject:aRecord];
                        [countset addObject:aRecord];
                    }
                }
                if(type)CFRelease(type);
                if(value)CFRelease(value);
            }
            if(phonefields)CFRelease(phonefields);
        }
    }
    
    if([match_ppl count]>=1){
        int high = 0;
        ABRecordRef aHighRecord = nil;
        // check who is the highest record
        for(id Object in countset)
        {
            int tmp = [countset countForObject:Object];
            if(tmp>=high) {
                high = tmp;
                aHighRecord = Object;
            }
        }
        retperson = ABRecordGetRecordID(aHighRecord);
    }
    
    if(allPeople!=NULL)CFRelease(allPeople);
    if(aBook!=NULL)CFRelease(aBook);
    
    return retperson;
}

- (IBAction)pickEmailType: (id)button
{
    index = [(UIButton*)button tag];
    // from file sharing folder
    TypeChooser *chooser = [[TypeChooser alloc] initWithNibName: @"GeneralTableView" bundle:nil typeArray:[etypes allValues] parent:self];
    [delegate.navController pushViewController:chooser animated:YES];
    [chooser release];
    chooser = nil;
}

- (IBAction)pickPhoneType: (id)button
{
    index = [(UIButton*)button tag];
    // from file sharing folder
    TypeChooser *chooser = [[TypeChooser alloc] initWithNibName: @"GeneralTableView" bundle:nil typeArray:[ptypes allValues] parent:self];
    [delegate.navController pushViewController:chooser animated:YES];
    [chooser release];
    chooser = nil;
}

- (void)SetField: (int)Index
{
    [emailfield resignFirstResponder];
    [phonefield resignFirstResponder];
    [Fnamefield resignFirstResponder];
    [Lnamefield resignFirstResponder];
    
    if(index){
        // email field
        select_2 = Index;
        [etypeBtn setTitle:[[etypes allValues]objectAtIndex:Index] forState:UIControlStateNormal];
    }else{
        select_1 = Index;
        [ptypeBtn setTitle:[[ptypes allValues]objectAtIndex:Index] forState:UIControlStateNormal];
    }
}

- (void)GrebCopyFromCloud
{
    // check iCloud backup existing
    [delegate.backtool RecheckCapability];
    if(delegate.backtool.CloudEnabled){
        // try to recovery from the backup file automatically
        [delegate.backtool iCloudQuery:NO];
        // lock all components
        [self SetComponentsLocked: YES];
        [delegate.activityView EnableProgress:NSLocalizedString(@"prog_SearchingForBackup", @"searching for backup...") SecondMeesage:@"" ProgessBar:NO];
    }else {
        // no backup capability
        [[[[iToast makeText: NSLocalizedString(@"error_BackupNotFound", @"No backup to restore.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
}

- (void)DisplayHow
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"title_find", @"Setup")
                                                      message:NSLocalizedString(@"help_find", @"Use this screen to set your name, phone, and email to exchange with others. Tap the 'Done' button when finished.")
                                                     delegate:nil
                                            cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                            otherButtonTitles:nil];
    [message show];
    [message release];
    message = nil;
}

- (void)NotifyFromBackup:(BOOL)result
{
    [self SetComponentsLocked: NO];
    [delegate.activityView DisableProgress];
    
    if(result)
    {
        DEBUGMSG(@"Backup okay.");
        [[[[iToast makeText: NSLocalizedString(@"state_BackupRestored", @"Backup restored.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [delegate saveConactData];
        [delegate CheckIdentity];
        delegate.passView.mode = NormalLogin;
        [delegate.navController popToRootViewControllerAnimated:YES];
        [delegate Login];
    }else{
        DEBUGMSG(@"Try again to grab the backup from iCloud...");
        if(recoverytry<=MAX_BACKUP_RETRY)
        {
            [self GrebCopyFromCloud];
            recoverytry++;
        }
        else{
            [[[[iToast makeText: NSLocalizedString(@"error_BackupNotFound", @"No backup to restore.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    dispatch_release(BGQueue);
    [super dealloc];
}

#pragma UITextFieldDelegate Methods
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    
}
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    
}
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return NO;
}

@end


@implementation TypeChooser

@synthesize typelist, delegate, parent;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil typeArray:(NSArray*)items parent:(SetupPanelViewController*)parentpanel
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.typelist = [NSMutableArray arrayWithArray:items];
        self.parent = parentpanel;
        self.delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // init the array
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(void) dealloc
{
    parent = nil;
    if(typelist)[typelist release];
    typelist = nil;
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // load all files in Share folder
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.typelist removeAllObjects];
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
    return [typelist count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    // Configure the cell...
    cell.textLabel.text = (NSString*)[self.typelist objectAtIndex:indexPath.row];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [parent SetField: indexPath.row];
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    // Navigation logic may go here. Create and push another view controller.
    [self.delegate.navController popViewControllerAnimated:YES];
}

@end

