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

#import "MessageView.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"
#import "UniversalDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "MessageDetailView.h"

#import <UAirship.h>
#import <UAPush.h>

@interface MessageView ()

@end

@implementation MessageView

@synthesize MessageList, delegate;
@synthesize b_img;

- (void)viewDidLoad
{
    [super viewDidLoad];
    delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    MessageList = [[NSMutableArray alloc]init];
    b_img = [UIImage imageNamed: @"blank_contact_small.png"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self UpdateThread];
    UIBarButtonItem *addBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action: @selector(createNewThread:)];
    [self.parentViewController.navigationItem setRightBarButtonItem:addBtn];
}

- (void)UpdateThread
{
    // Messages from universal database
    NSMutableDictionary *list = [NSMutableDictionary dictionary];
    
    [delegate.DbInstance GetThreads: list];
    int badgenum = [delegate.UDbInstance UpdateThreadEntries: list];
    if(badgenum>0)
        [self.tabBarItem setBadgeValue:[NSString stringWithFormat:@"%d", badgenum]];
    else
        [self.tabBarItem setBadgeValue:nil];
    
    // Messages from individual database
    [MessageList setArray: [list allValues]];
    
    [self.tableView reloadData];
}

-(IBAction)unwindToThreadView:(UIStoryboardSegue *)unwindSegue
{
    [self viewWillAppear:YES];
}

- (void)createNewThread: (id)sender
{
    [self.tabBarController setSelectedIndex:1];
}

- (void)viewDidUnload
{
    [MessageList removeAllObjects];
    [super viewDidUnload];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    self.parentViewController.navigationItem.title = [NSString stringWithFormat:@"%lu %@",(unsigned long)[MessageList count], NSLocalizedString(@"title_Threads" ,@"Threads")];
    return [MessageList count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if([MessageList count]==0)
        return NSLocalizedString(@"label_InstNoMessages", @"No messages. You may send a message from tapping the 'Compose Message' Button in Home Menu.");
    else
        return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ThreadCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    MsgListEntry *MsgListEntry = [MessageList objectAtIndex:indexPath.row];
    
    // username
    NSString* display = MsgListEntry.keyid;
    NSString* username = nil;
    if([MsgListEntry.keyid isEqualToString:@"UNDEFINED"])
        display = NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown");
    else {
        username = [delegate.DbInstance QueryStringInTokenTableByKeyID: MsgListEntry.keyid Field:@"pid"];
        if(username)
        {
            NSArray* namearray = [[username substringFromIndex:[username rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
            display = [NSString compositeName:[namearray objectAtIndex:1] withLastName:[namearray objectAtIndex:0]];
            [cell.imageView setAlpha: 1.0f];
        }else{
            // disable
            [cell.imageView setAlpha: 0.3f];
        }
    }
    
    // message count
    [cell.textLabel setText: (MsgListEntry.ciphercount==0) ? [NSString stringWithFormat:@"%@ %d", display, MsgListEntry.messagecount] : [NSString stringWithFormat:@"%@ %d (%d)", display, MsgListEntry.messagecount, MsgListEntry.ciphercount]];
    
    // get photo
    NSString* face = [delegate.DbInstance QueryStringInTokenTableByKeyID: MsgListEntry.keyid Field:@"note"];
    [cell.imageView setImage: ([face length]==0) ? b_img : [[UIImage imageWithData: [Base64 decode:face]]scaleToSize:CGSizeMake(45.0f, 45.0f)]];
    
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
    NSDateComponents *components = nil;
    
    NSDate *lastSeen;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: DATABASE_TIMESTR];
    lastSeen = [formatter dateFromString:MsgListEntry.lastSeen];
    
    components = [calendar components:NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond
                             fromDate: lastSeen
                               toDate: [NSDate date]
                              options:0];
    
    [cell.detailTextLabel setText: (components.day==0) ? [NSString ChangeGMT2Local: MsgListEntry.lastSeen GMTFormat:DATABASE_TIMESTR LocalFormat:@"hh:mm a"] : [NSString ChangeGMT2Local: MsgListEntry.lastSeen GMTFormat:DATABASE_TIMESTR LocalFormat:@"MMM dd"]];
    
    return cell;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        MsgListEntry* MsgListEntry = [MessageList objectAtIndex:indexPath.row];
        if([MsgListEntry.keyid isEqual:@"UNDEFINED"])
        {
            if([delegate.UDbInstance DeleteThread: @"UNDEFINED"])
            {
                [MessageList removeObjectAtIndex:indexPath.row];
                [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_MessagesDeleted", @"%d messages deleted."), MsgListEntry.messagecount]]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                
            }else{
                [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateMessageInDB", @"Unable to update the message database.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            }
        }
        else
        {
            if([delegate.DbInstance DeleteThread: MsgListEntry.keyid] && [delegate.UDbInstance DeleteThread: MsgListEntry.keyid])
            {
                [MessageList removeObjectAtIndex:indexPath.row];
                [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_MessagesDeleted", @"%d messages deleted."), MsgListEntry.messagecount]]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                
            }else{
                [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateMessageInDB", @"Unable to update the message database.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            }
        }
        
        [self.tableView reloadData];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier]isEqualToString:@"MessageDetail"])
    {
        // assign entry...
        MessageDetailView *detail = (MessageDetailView*)[segue destinationViewController];
        detail.parentView = self;
        detail.assignedEntry = [MessageList objectAtIndex:[self.tableView indexPathForSelectedRow].row];
    }
}

@end
