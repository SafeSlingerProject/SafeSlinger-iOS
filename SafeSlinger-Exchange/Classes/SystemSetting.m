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

#import "SystemSetting.h"
#import "KeySlingerAppDelegate.h"
#import "AboutPanel.h"
#import "VersionCheckMarco.h"
#import "UAirship.h"
#import "UAPush.h"
#import "SSEngine.h"

@interface SystemSetting ()

@end

@implementation SystemSetting

@synthesize SectionHeader, delegate;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    
    if (self) {
        // Custom initialization
        self.delegate = [[UIApplication sharedApplication]delegate];
        // Custom initialization
        self.SectionHeader = [NSArray arrayWithObjects:
                              NSLocalizedString(@"section_general", @"General"),
                              NSLocalizedString(@"section_backup", @"Backup"),
                              NSLocalizedString(@"section_advanced", @"Advanced"),
                              nil];
        
        if([delegate.DbInstance GetConfig:@"label_ShowHintAtLaunch"]==nil)
        {
            int boolInt = 1; // show hint for exchange
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &boolInt length: sizeof(boolInt)] withTag:@"label_ShowHintAtLaunch"];
        }
        
        if([delegate.DbInstance GetConfig:@"label_RemindBackupDelay"]==nil)
        {
            int boolInt = 1; // show backup hint for exchange
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &boolInt length: sizeof(boolInt)] withTag:@"label_RemindBackupDelay"];
        }
        
        // default 300 seconds.
        if(![delegate.DbInstance GetConfig:@"label_passPhraseCacheTtl"])
        {
            int limit = 300;
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &limit length: sizeof(limit)] withTag:@"label_passPhraseCacheTtl"];
        }
        
        // default time track
        if(![delegate.DbInstance GetConfig:@"time_track"])
        {
            NSTimeInterval period = [[NSDate date]timeIntervalSince1970];
            [delegate.DbInstance InsertOrUpdateConfig: [NSData dataWithBytes: &period length: sizeof(period)] withTag:@"time_track"];
        }
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"menu_Settings", @"Settings");
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.tableView reloadData];
}

- (void)UpdateView
{
    [self.tableView reloadData];
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
        case 0:
            // General Section: Show Tutorial, Passphrase Cache, Change Passphrase, About
            return 4;
            break;
        case 1:
            // Backup Section: Backup URL, Last Backup Request, Last Backup Completed, Last Restore Completed, Backup Reminder 
            return 5;
            break;
        case 2:
            // Advanced Section: Key ID, Token ID
            return 2;
        default:
            return 0;
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height;
    
    switch(indexPath.section)
    {
        case 0:
            // general terms
            height = 60.0f;
            break;
        case 1:
            // general terms for backup
            height = 80.0f;
            break;
        case 2:
            // advanced terms
            height = 80.0f;
            break;
        default:
            height = 60.0f;
            break;
    }
    return height;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [SectionHeader objectAtIndex:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    int booltmp = 0;
    
    // Configure the cell...
    if (indexPath.section == 0) {
        // General Section: Show Tutorial, Passphrase Cache, Change Passphrase, About
        switch (indexPath.row) {
            case 0:
                // Show Tutorial
                cell.textLabel.text = NSLocalizedString(@"menu_ShowTutorial", @"Show Tutorial");
                [[delegate.DbInstance GetConfig:@"label_ShowHintAtLaunch"]getBytes:&booltmp length:sizeof(booltmp)];
                if(booltmp==1)
                {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    cell.detailTextLabel.text = NSLocalizedString(@"btn_Yes", @"Yes");
                }else if(booltmp==0){
                    cell.detailTextLabel.text = NSLocalizedString(@"btn_No", @"No");
                    cell.accessoryType = UITableViewCellAccessoryNone;
                }
                break;
            case 1:
                // Passphrase Cache
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.text = NSLocalizedString(@"label_passPhraseCacheTtl", @"Pass Phrase Cache");
                [[delegate.DbInstance GetConfig:@"label_passPhraseCacheTtl"]getBytes:&booltmp length:sizeof(booltmp)];
                switch (booltmp) {
                    case 0:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_nolimit", @"No Limit");
                        break;
                    case 60:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_1min", @"1 min");
                        break;
                    case 180:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_3mins", @"3 mins");
                        break;
                    case 300:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_5mins", @"5 mins");
                        break;
                    case 600:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_10mins", @"10 mins");
                        break;
                    case 1200:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_20mins", @"20 mins");
                        break;
                    case 2400:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_40mins", @"40 mins");
                        break;
                    case 3600:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_1hour", @"1 hour");
                        break;
                    case 7200:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_2hours", @"2 hours");
                        break;
                    case 14400:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_4hours", @"4 hours");
                        break;
                    case 28800:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_8hours", @"8 hours");
                        break;
                    default:
                        cell.detailTextLabel.text = NSLocalizedString(@"choice_5mins", @"5 mins");
                        break;
                }
                break;
            case 2:
                // Change Passphrase
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.text = NSLocalizedString(@"menu_ChangePassphrase", @"Change Pass Phrase");
                cell.detailTextLabel.text = nil;
                break;
            case 3:
                // About
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.textLabel.text = NSLocalizedString(@"menu_About", @"About");
                cell.detailTextLabel.text = nil;
                break;
            default:
                break;
        }// end of switch
        
    }else if(indexPath.section == 1)
    {
        char* value = NULL;
        // General Section: Show Tutorial, Passphrase Cache, Change Passphrase, About
        switch (indexPath.row) {
            // Backup Section: Backup URL, Last Backup Request, Last Backup Completed, Last Restore Completed, Backup Reminder 
            case 0:
                cell.textLabel.text = NSLocalizedString(@"label_backupURL", @"Backup URL");
                value = (char*)[[delegate.DbInstance GetConfig:@"label_backupURL"]bytes];
                if(value)
                    cell.detailTextLabel.text = [NSString stringWithUTF8String:value];
                else
                    cell.detailTextLabel.text = NSLocalizedString(@"label_None", @"None");
                break;
            case 1:
                cell.textLabel.text = NSLocalizedString(@"label_backupRequestDate", @"Last Backup Request");
                value = (char*)[[delegate.DbInstance GetConfig:@"label_backupRequestDate"]bytes];
                if(value)
                    cell.detailTextLabel.text = [NSString stringWithUTF8String:value];
                else
                    cell.detailTextLabel.text = NSLocalizedString(@"label_None", @"None");
                break;
            case 2:
                cell.textLabel.text = NSLocalizedString(@"label_backupCompleteDate", @"Last Backup Completed");
                value = (char*)[[delegate.DbInstance GetConfig:@"label_backupCompleteDate"]bytes];
                if(value)
                    cell.detailTextLabel.text = [NSString stringWithUTF8String:value];
                else
                    cell.detailTextLabel.text = NSLocalizedString(@"label_None", @"None");
                break;
            case 3:
                cell.textLabel.text = NSLocalizedString(@"label_restoreCompleteDate", @"Last Restore Completed");
                value = (char*)[[delegate.DbInstance GetConfig:@"label_restoreCompleteDate"]bytes];
                if(value)
                    cell.detailTextLabel.text = [NSString stringWithUTF8String:value];
                else
                    cell.detailTextLabel.text = NSLocalizedString(@"label_None", @"None");
                break;
            case 4:
                cell.textLabel.text = NSLocalizedString(@"label_RemindBackupDelay", @"Backup Reminder");
                [[delegate.DbInstance GetConfig:@"label_RemindBackupDelay"]getBytes:&booltmp length:sizeof(booltmp)];
                if(booltmp==1)
                {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    cell.detailTextLabel.text = NSLocalizedString(@"btn_Yes", @"Yes");
                }else if(booltmp==0){
                    cell.detailTextLabel.text = NSLocalizedString(@"btn_No", @"No");
                    cell.accessoryType = UITableViewCellAccessoryNone;
                }
                break;
            default:
                break;
        }// end of switch
        
    }
    else if(indexPath.section == 2)
    {
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = NSLocalizedString(@"label_PublicKeyID", @"Key ID");
                cell.detailTextLabel.text = [SSEngine getSelfKeyID];
                break;
            case 1:
                cell.textLabel.text = NSLocalizedString(@"label_PushTokenID", @"Push Token ID");
                if([UAirship shared].deviceToken)
                {
                    cell.detailTextLabel.text = [UAirship shared].deviceToken;
                }else{
                    cell.detailTextLabel.text = NSLocalizedString(@"iOS_errorpushtoken", @"Push Token is missing.");
                }
                break;
            default:
                break;
        }
    }
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    int boolvalue;
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    
    // Navigation logic may go here. Create and push another view controller.
    if(indexPath.section==0&&indexPath.row==0)
    {
        // Change UICell View
        UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
        if (cell.accessoryType == UITableViewCellAccessoryNone)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.detailTextLabel.text = NSLocalizedString(@"btn_Yes", @"Yes");
            boolvalue = 1;
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &boolvalue length: sizeof(boolvalue)] withTag:@"label_ShowHintAtLaunch"];
        }
        else if (cell.accessoryType == UITableViewCellAccessoryCheckmark)
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.detailTextLabel.text = NSLocalizedString(@"btn_No", @"No");
            boolvalue = 0;
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &boolvalue length: sizeof(boolvalue)] withTag:@"label_ShowHintAtLaunch"];
        }
        [self UpdateView];
    }
    
    if(indexPath.section==0&&indexPath.row==1)
    {
        // pick up time
        TimePicker *timpicker = [[TimePicker alloc] initWithStyle:UITableViewStyleGrouped];
        [delegate.navController pushViewController:timpicker animated:YES];
        [timpicker release];
        timpicker = nil;
    }
    
    if(indexPath.section==0&&indexPath.row==2)
    {
        // pick up time
        delegate.hasAccess = NO;
        delegate.passView.mode = ChangePass;
        [delegate Login];
    }
    
    if(indexPath.section==1&&indexPath.row==4)
    {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath: indexPath];
        if (cell.accessoryType == UITableViewCellAccessoryNone)
        {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            cell.detailTextLabel.text = NSLocalizedString(@"btn_Yes", @"Yes");
            boolvalue = 1;
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &boolvalue length: sizeof(boolvalue)] withTag:@"label_RemindBackupDelay"];
        }
        else if (cell.accessoryType == UITableViewCellAccessoryCheckmark)
        {
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.detailTextLabel.text = NSLocalizedString(@"btn_No", @"No");
            boolvalue = 0;
            [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &boolvalue length: sizeof(boolvalue)] withTag:@"label_RemindBackupDelay"];
        }
        [self UpdateView];
    }
    
    if(indexPath.section==0&&indexPath.row==3)
    {
        // ABout
        AboutPanel *about = nil;
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
        {
            DEBUGMSG(@"<= NSFoundationVersionNumber_iOS_6_1");
            if(IS_4InchScreen)
            {
                about = [[AboutPanel alloc] initWithNibName:@"AboutPanel_4in" bundle:[NSBundle mainBundle]];
            }else{
                about = [[AboutPanel alloc] initWithNibName:@"AboutPanel" bundle:[NSBundle mainBundle]];
            }
            
        }else{
            about = [[AboutPanel alloc] initWithNibName:@"AboutPanel_ip5" bundle:[NSBundle mainBundle]];
        }
        
        [delegate.navController pushViewController:about animated:YES];
        [about release];
        about = nil;
    }

}

@end


@implementation TimePicker

@synthesize cachetimes, delegate, sortkeys;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    // All cache time entries
    self.cachetimes = [NSDictionary dictionaryWithObjectsAndKeys:
                       NSLocalizedString(@"choice_1min", @"1 min"), [NSNumber numberWithInt:60],
                       NSLocalizedString(@"choice_3mins", @"3 mins"), [NSNumber numberWithInt:180],
                       NSLocalizedString(@"choice_5mins", @"5 mins"), [NSNumber numberWithInt:300],
                       NSLocalizedString(@"choice_10mins", @"10 mins"), [NSNumber numberWithInt:600],
                       NSLocalizedString(@"choice_20mins", @"20 mins"), [NSNumber numberWithInt:1200],
                       NSLocalizedString(@"choice_40mins", @"40 mins"), [NSNumber numberWithInt:2400],
                       NSLocalizedString(@"choice_1hour", @"1 hour"), [NSNumber numberWithInt:3600],
                       NSLocalizedString(@"choice_2hours", @"2 hours"), [NSNumber numberWithInt:7200],
                       NSLocalizedString(@"choice_4hours", @"4 hours"), [NSNumber numberWithInt:14400],
                       NSLocalizedString(@"choice_8hours", @"8 hours"), [NSNumber numberWithInt:28800],
                       NSLocalizedString(@"choice_nolimit", @"No Limit"), [NSNumber numberWithInt:0],
                       nil];
    // Sort them
    self.sortkeys = [[cachetimes allKeys]sortedArrayUsingComparator:
                     ^NSComparisonResult(id obj1, id obj2)
                     {
                         if ([obj1 integerValue] > [obj2 integerValue]) {
                             return (NSComparisonResult)NSOrderedDescending;
                         }
                         if ([obj1 integerValue] < [obj2 integerValue]) {
                             return (NSComparisonResult)NSOrderedAscending;
                         }
                         return (NSComparisonResult)NSOrderedSame;
                     }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [cachetimes release];
    cachetimes = nil;
    [sortkeys release];
    sortkeys = nil;
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
    return [sortkeys count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    // Configure the cell...
    cell.textLabel.text = [cachetimes objectForKey:[sortkeys objectAtIndex:indexPath.row]];
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    int period = [[sortkeys objectAtIndex:indexPath.row]integerValue];
    [delegate.DbInstance InsertOrUpdateConfig:[NSData dataWithBytes: &period length: sizeof(period)] withTag:@"label_passPhraseCacheTtl"];
    [delegate.window ResetTimer:[[sortkeys objectAtIndex:indexPath.row]floatValue]];
    [delegate.navController popViewControllerAnimated:YES];
}
     
@end
