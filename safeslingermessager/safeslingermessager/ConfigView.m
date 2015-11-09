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

#import "ConfigView.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "SSEngine.h"
#import "Utility.h"
#import "ErrorLogger.h"
#import "BackupCloud.h"
#import "TimePicker.h"
#import "MessageDecryptor.h"

@interface ConfigView ()

@end

@implementation ConfigView

@synthesize SectionHeader, delegate;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)InstallDefaultSetting
{
    // Default
    if([[NSUserDefaults standardUserDefaults] integerForKey: kPasshpraseCacheTime]==Unregistered)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:300 forKey: kPasshpraseCacheTime];
    }
    
    if([[NSUserDefaults standardUserDefaults] integerForKey: kAutoDecryptOpt]==Unregistered)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey: kAutoDecryptOpt];
    }
    
    if([[NSUserDefaults standardUserDefaults] integerForKey: kRemindBackup]==Unregistered)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey: kRemindBackup];
    }
    
    if([[NSUserDefaults standardUserDefaults] integerForKey: kShowExchangeHint]==Unregistered)
    {
        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey: kShowExchangeHint];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Custom initialization
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    // Custom initialization
    SectionHeader = [NSArray arrayWithObjects:
                     NSLocalizedString(@"title_passphrase", @"Passphrase"),
                     NSLocalizedString(@"section_general", @"General"),
                     NSLocalizedString(@"section_backup", @"Backup"),
                     NSLocalizedString(@"title_About", @"About"),
                     NSLocalizedString(@"section_advanced", @"Advanced"),
                     nil];
    
    [self InstallDefaultSetting];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.parentViewController.navigationItem.rightBarButtonItem = nil;
    self.parentViewController.navigationItem.title = NSLocalizedString(@"menu_Settings", @"Settings");
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // do backup before leave the view
    [delegate.BackupSys RecheckCapability];
    [delegate.BackupSys PerformBackup];
}

- (void)UpdateView
{
    [self.tableView reloadData];
}

- (void)UpdateSingleCell: (NSIndexPath*)cell
{
    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:cell, nil] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
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
    return [SectionHeader count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case PassphraseSec:
            // Logout, Change Passphrase, Manage Passphrase, Passphrase Cache
            return PassphraseSetCnt;
            break;
        case GeneralSec:
            return GeneralSetCnt;
            break;
        case BackupSec:
            return BackupSetCnt;
            break;
        case AboutSec:
            // About
            return AboutSetCnt;
            break;
        case AdvanceSec:
            return AdvanceSetCnt;
            break;
        default:
            return 0;
            break;
    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80.0f;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [SectionHeader objectAtIndex:section];
}

- (NSString*)GetTimeLabel: (NSInteger)TimeUnit
{
    NSString* tl = nil;
    
    switch (TimeUnit) {
        case -1:
            tl = NSLocalizedString(@"choice_nolimit", @"No Limit");
            break;
        case 60:
            tl = NSLocalizedString(@"choice_1min", @"1 min");
            break;
        case 180:
            tl = NSLocalizedString(@"choice_3mins", @"3 mins");
            break;
        case 300:
            tl = NSLocalizedString(@"choice_5mins", @"5 mins");
            break;
        case 600:
            tl = NSLocalizedString(@"choice_10mins", @"10 mins");
            break;
        case 1200:
            tl = NSLocalizedString(@"choice_20mins", @"20 mins");
            break;
        case 2400:
            tl = NSLocalizedString(@"choice_40mins", @"40 mins");
            break;
        case 3600:
            tl = NSLocalizedString(@"choice_1hour", @"1 hour");
            break;
        case 7200:
            tl = NSLocalizedString(@"choice_2hours", @"2 hours");
            break;
        case 14400:
            tl = NSLocalizedString(@"choice_4hours", @"4 hours");
            break;
        case 28800:
            tl = NSLocalizedString(@"choice_8hours", @"8 hours");
            break;
        default:
            break;
    }
    
    return tl;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SettingItemCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    
    switch (indexPath.section) {
        case PassphraseSec:
        {
            switch (indexPath.row) {
                case ChangePass:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"menu_ChangePassphrase", @"Change Passphrase");
                    break;
                case ManagePass:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"menu_ManagePassphrases", @"Manage Passphrases");
                    break;
                case PassCache:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"label_passPhraseCacheTtl", @"Pass Phrase Cache");
                    NSInteger cache_time = [[NSUserDefaults standardUserDefaults]integerForKey: kPasshpraseCacheTime];
                    cell.detailTextLabel.text = [self GetTimeLabel:cache_time];
                    break;
                default:
                    break;
            }
        }
            break;
        case GeneralSec:
        {
            switch (indexPath.row) {
                case UserFirstName :
                    cell.textLabel.text = NSLocalizedString(@"label_FirstName", @"First Name");
                    cell.detailTextLabel.text = [delegate.DbInstance GetStringConfig: @"Profile_FN"];
                    break;
                case UserLastName:
                    cell.textLabel.text = NSLocalizedString(@"label_LastName", @"Last Name");
                    cell.detailTextLabel.text = [delegate.DbInstance GetStringConfig: @"Profile_LN"];
                    break;
                case ShowTutorial:
                    // Show Tutorial
                    cell.textLabel.text = NSLocalizedString(@"menu_ShowTutorial", @"Show Tutorial");
                    cell.detailTextLabel.text = NSLocalizedString(@"label_summary_show_tutorial", @"Show a tutorial before attemping to Sling Keys.");
                    if([[NSUserDefaults standardUserDefaults]integerForKey: kShowExchangeHint]==TurnOn)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }else{
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
                default:
                    break;
            }
        }
            break;
        case BackupSec:
        {
            switch (indexPath.row) {
                    
                case BackupReminder:
                {
                    cell.textLabel.text = NSLocalizedString(@"label_RemindBackupDelay", @"Backup Reminder");
                    cell.detailTextLabel.text = NSLocalizedString(@"label_summary_remind_backup_delay", @"Receive notification when backup is offline.");
                    if([[NSUserDefaults standardUserDefaults] integerForKey:kRemindBackup]==TurnOn)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }else{
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                }
                    break;
                case BackupURL:
                {
                    cell.textLabel.text = NSLocalizedString(@"label_backupURL", @"Backup URL");
                    NSString* url = [[NSUserDefaults standardUserDefaults]stringForKey: kBackupURL];
                    cell.detailTextLabel.text = ((url == nil) ? NSLocalizedString(@"label_None", @"None") : url);
                }
                    break;
                case LastBackupRequest:
                {
                    cell.textLabel.text = NSLocalizedString(@"label_backupRequestDate", @"Last Backup Request");
                    NSString* BackupReqDate = [[NSUserDefaults standardUserDefaults]stringForKey: kBackupReqDate];
                    cell.detailTextLabel.text = ((BackupReqDate == nil) ? NSLocalizedString(@"label_None", @"None") : BackupReqDate);
                }
                    break;
                case LastBackupComplete:
                {
                    cell.textLabel.text = NSLocalizedString(@"label_backupCompleteDate", @"Last Backup Completed");
                    NSString* BackupCplDate = [[NSUserDefaults standardUserDefaults]stringForKey: kBackupCplDate];
                    cell.detailTextLabel.text = ((BackupCplDate == nil) ? NSLocalizedString(@"label_None", @"None") : BackupCplDate);
                }
                    break;
                case LastRestoreComplete:
                {
                    cell.textLabel.text = NSLocalizedString(@"label_restoreCompleteDate", @"Last Restore Completed");
                    NSString* RestoreDate = [[NSUserDefaults standardUserDefaults]stringForKey: kRestoreDate];
                    cell.detailTextLabel.text = ((RestoreDate == nil) ? NSLocalizedString(@"label_None", @"None") : RestoreDate);
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case AboutSec:
        {
            switch (indexPath.row) {
                case About:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"menu_About", @"About");
                    cell.detailTextLabel.text = [delegate getVersionNumber];
                    break;
                case LicenseURL:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"menu_License", @"License");
                    cell.detailTextLabel.text = nil;
                    break;
                case PrivacyURL:
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"menu_PrivacyPolicy", @"Privacy Policy");
                    cell.detailTextLabel.text = nil;
                    break;
                default:
                    break;
            }
        }
            break;
        case AdvanceSec:
        {
            switch (indexPath.row)
            {
                case AutoDecrypt:
                    cell.textLabel.text = NSLocalizedString(@"menu_auto_decrypt", @"Auto-decrypt");
                    cell.detailTextLabel.text = NSLocalizedString(@"label_summary_auto_decrypt", @"Automatically decrypt messages when logged in.");
                    if([[NSUserDefaults standardUserDefaults] integerForKey:kAutoDecryptOpt]==TurnOn)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }else{
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
					
                case KeyID:
                    cell.textLabel.text = NSLocalizedString(@"label_PublicKeyID", @"Key ID");
                    cell.detailTextLabel.text = [SSEngine getSelfKeyID];
                    break;
                case PushToken:
                {
                    cell.textLabel.text = NSLocalizedString(@"label_PushTokenID", @"Push Registration ID");
                    NSString* hex_token = [[NSUserDefaults standardUserDefaults] stringForKey: kPUSH_TOKEN];
                    if(hex_token)
                    {
                        cell.detailTextLabel.text = hex_token;
                    }else{
                        cell.detailTextLabel.text = NSLocalizedString(@"iOS_errorpushtoken", @"Push Token is missing.");
                    }
                }
                    break;
                default:
                    break;
            }
        }
            break;
        default:
            break;
    }
    
    
    return cell;
}

- (void)ManagePassphraseDialog
{
    int DB_KEY_INDEX = (int)[[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY];
    NSArray *keyarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY];
    NSArray *infoarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_LIST];
    NSMutableString* msg = [NSMutableString string];
    
    if(DB_KEY_INDEX==([keyarr count]-1)){
        [msg appendFormat: NSLocalizedString(@"label_WarnManagePassOnlyRecentDeleted", @"Only keys generated more recently than yours, generated on %@, may be deleted."), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat: @"yyyy-MM-dd HH:mm:ss"]];
        
        [msg appendString: @"\n"];
        [msg appendString: NSLocalizedString(@"label_WarnManagePassNoMoreRecent", @"There are no more recent keys than yours.")];
    }else{
        [msg appendFormat: NSLocalizedString(@"label_WarnManagePassOnlyRecentDeleted", @"Only keys generated more recently than yours, generated on %@, may be deleted."), [NSString ChangeGMT2Local:[SSEngine getSelfGenKeyDate] GMTFormat:DATABASE_TIMESTR LocalFormat: @"yyyy-MM-dd HH:mm:ss"]];
        [msg appendString: @"\n"];
        [msg appendString: NSLocalizedString(@"label_WarnManagePassFollowsAreRecent", @"The following keys will be deleted:")];
        
        for(int i=DB_KEY_INDEX+1; i<[infoarr count]; i++)
        {
            [msg appendString: @"\n"];
            [msg appendString: [infoarr objectAtIndex: i]];
        }
    }
    
    // for case NotPermDialog
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"menu_ManagePassphrases", @"Manage Passphrases")
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    if(DB_KEY_INDEX<([keyarr count]-1)){
        UIAlertAction* delAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_DeleteKeys", @"Delete Keys")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action){
                                                             [self DeleteNewerKeys];
                                                         }];
        [alert addAction:delAction];
    }
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * action){
                                                         
                                                     }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)DeleteNewerKeys
{
    int DB_KEY_INDEX = (int)[[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY];
    NSArray *keyarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY];
    NSArray *infoarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_LIST];
    
    NSMutableArray *new_keyarr = [NSMutableArray arrayWithArray:keyarr];
    NSMutableArray *new_infoarr = [NSMutableArray arrayWithArray:infoarr];
    
    NSFileManager *fs = [NSFileManager defaultManager];
    NSError *err;
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    
    for(int i=DB_KEY_INDEX+1; i<[infoarr count]; i++)
    {
        [indexes addIndex:i];
        NSString *floc = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent: [NSString stringWithFormat:@"%@-%d.db", DATABASE_NAME, i]];
        
        if([fs fileExistsAtPath:floc])[fs removeItemAtPath:floc error:&err];
        if(err) [ErrorLogger ERRORDEBUG: [err debugDescription]];
    }
    
    [new_keyarr removeObjectsAtIndexes:indexes];
    [new_infoarr removeObjectsAtIndexes:indexes];
    
    [[NSUserDefaults standardUserDefaults] setObject:new_keyarr forKey: kDB_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:new_infoarr forKey: kDB_LIST];
    
    // Modify key strucutres, do backup
    [delegate.BackupSys RecheckCapability];
    [delegate.BackupSys PerformBackup];
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    
    switch (indexPath.section) {
        case PassphraseSec:
        {
            switch (indexPath.row) {
                case ChangePass:
                    // Change Passphrase
                    [self performSegueWithIdentifier: @"UpdatePassphrase" sender:self];
                    break;
                case ManagePass:
                    // Remove old keys
                    [self ManagePassphraseDialog];
                    break;
                case PassCache:
                    // Select Passphrase cache time
                    [self performSegueWithIdentifier:@"PickTime" sender:self];
                    break;
                default:
                    break;
            }
        }
            break;
        case GeneralSec:
        {
            switch (indexPath.row) {
                case UserFirstName :
                case UserLastName:
                {
                    // Popup AlertView
                    NSString *title = nil;
                    NSString *first = [delegate.DbInstance GetStringConfig:@"Profile_FN"];
                    NSString *last = [delegate.DbInstance GetStringConfig:@"Profile_LN"];
                    
                    BOOL isFirstName = NO;
                    if(indexPath.row==UserFirstName){
                        title = NSLocalizedString(@"label_FirstName", @"First Name");
                        isFirstName = YES;
                    }else if(indexPath.row==UserLastName)
                        title = NSLocalizedString(@"label_LastName", @"Last Name");
                    
                    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                        textField.placeholder = title;
                        if(isFirstName) textField.text = first;
                        else textField.text = last;
                    }];
                    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                                           style:UIAlertActionStyleCancel
                                                                         handler:^(UIAlertAction * action) {
                                                                             // nothing
                                                                         }];
                    
                    UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"btn_OK", @"OK")
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * action) {
                                                                         NSString *modified = ((UITextField*)alert.textFields.firstObject).text;
                                                                         if(isFirstName)
                                                                         {
                                                                             if([modified length]>0){
                                                                                 if(![first isEqualToString:modified]){
                                                                                     [delegate saveConactData:delegate.IdentityNum Firstname:modified Lastname:last];
                                                                                     [self UpdateSingleCell:indexPath];
                                                                                 }
                                                                             }else{
                                                                                 // length = 0
                                                                                 if(last){
                                                                                     // update with NULL fistname
                                                                                     [delegate saveConactData:delegate.IdentityNum Firstname:nil Lastname:last];
                                                                                     [self UpdateSingleCell:indexPath];
                                                                                 }else
                                                                                     [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
                                                                                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                                                                             }
                                                                         }else{
                                                                             if([modified length]>0){
                                                                                 if (![last isEqualToString:modified]){
                                                                                     [delegate saveConactData:delegate.IdentityNum Firstname:first Lastname:modified];
                                                                                     [self UpdateSingleCell:indexPath];
                                                                                 }
                                                                             }else{
                                                                                 // length = 0
                                                                                 if(first){
                                                                                     // update with NULL lastname
                                                                                     [delegate saveConactData:delegate.IdentityNum Firstname:first Lastname:nil];
                                                                                     [self UpdateSingleCell:indexPath];
                                                                                 }else
                                                                                     [[[[iToast makeText: NSLocalizedString(@"error_ContactNameMissing", @"This contact is missing a name, please edit.")]
                                                                                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                                                                             }
                                                                         }
                                                                     }];
                    [alert addAction:okAction];
                    [alert addAction:cancelAction];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                    break;
                case ShowTutorial:
                {
                    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
                    if (cell.accessoryType == UITableViewCellAccessoryNone)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey:kShowExchangeHint];
                    }
                    else if (cell.accessoryType == UITableViewCellAccessoryCheckmark)
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        [[NSUserDefaults standardUserDefaults] setInteger:TurnOff forKey:kShowExchangeHint];
                    }
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case BackupSec:
        {
            switch (indexPath.row) {
                case BackupReminder:
                {
                    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
                    if (cell.accessoryType == UITableViewCellAccessoryNone)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey: kRemindBackup];
                    }
                    else if (cell.accessoryType == UITableViewCellAccessoryCheckmark)
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey: kRemindBackup];
                    }
                }
                    break;
                case BackupURL:
                case LastBackupRequest:
                case LastBackupComplete:
                case LastRestoreComplete:
                default:
                    // do nothing
                    break;
            }
        }
            break;
        case AboutSec:
        {
            switch (indexPath.row) {
                case About:
                    [self performSegueWithIdentifier: @"DisplayAbout" sender:self];
                    break;
                case PrivacyURL:
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: kPrivacyURL]];
                    break;
                case LicenseURL:
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: kLicenseURL]];
                    break;
                default:
                    break;
            }
        }
            break;
        case AdvanceSec:
        {
            switch (indexPath.row) {
                case AutoDecrypt:
                {
                    UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
                    if (cell.accessoryType == UITableViewCellAccessoryNone)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                        [[NSUserDefaults standardUserDefaults] setInteger:TurnOn forKey:kAutoDecryptOpt];
						[MessageDecryptor tryToDecryptAll];
                    }
                    else if (cell.accessoryType == UITableViewCellAccessoryCheckmark)
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        [[NSUserDefaults standardUserDefaults] setInteger:TurnOff forKey:kAutoDecryptOpt];
                    }
                }
                    break;
                case KeyID:
                case PushToken:
                default:
                    // do nothing
                    break;
            }
        }
            break;
        default:
            break;
    }
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"PickTime"])
    {
        TimePicker* dest = (TimePicker*)segue.destinationViewController;
        dest.selectValue = [[NSUserDefaults standardUserDefaults]integerForKey: kPasshpraseCacheTime];
        dest.parent = self;
    }
}

@end
