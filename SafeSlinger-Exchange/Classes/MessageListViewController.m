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

#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <assert.h>

#import <MobileCoreServices/UTType.h>
#import "MessageListViewController.h"
#import "KeySlingerAppDelegate.h"
#import "Base64.h"
#import "VCardParser.h"
#import "ActivityWindow.h"
#import "iToast.h"
#import "sha3.h"
#import "Utility.h"
#import "VersionCheckMarco.h"
#import "MessageEntryViewViewController.h"

#import "UAirship.h"
#import "UAPush.h"

#import "SSEngine.h"
#import "ErrorLogger.h"

@implementation MessageListViewController

@synthesize MessageList, delegate;
@synthesize b_img;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.delegate = [[UIApplication sharedApplication]delegate];
        self.tableView.allowsMultipleSelectionDuringEditing = NO;
        _ThreadLock  = [[NSLock alloc] init];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [MessageList setArray:[delegate.DbInstance LoadMessageThreads]];
    BOOL hasNewToken = NO;
    
    // Update message in the database if new receipts are available 
    for(MsgListEntry *entry in MessageList)
    {
        if([entry.username length]==LENGTH_KEYID&&[entry.token length]==LENGTH_KEYID)
        {
            // try to get the related token if possible
            NSString* ptoken = [delegate.DbInstance QueryStringInTokenTableByKeyID:entry.token Field:@"ptoken"];
            NSString* pid = [delegate.DbInstance QueryStringInTokenTableByKeyID:entry.token Field:@"pid"];
            if(ptoken&&pid)
            {
                NSArray* namearray = [[pid substringFromIndex:[pid rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
                pid = [NSString composite_name:[namearray objectAtIndex:1] withLastName:[namearray objectAtIndex:0]];
                [delegate.DbInstance UpdateMessagesWithToken: entry.token ReplaceUsername:pid ReplaceToken:ptoken];
                hasNewToken = YES;
            }
        }
    }
    
    // reload messages from database if necessary
    if(hasNewToken){
        [MessageList setArray:[delegate.DbInstance LoadMessageThreads]];
        [[[[iToast makeText: NSLocalizedString(@"label_MsgSendUpdate", @"My updated SafeSlinger credentials are attached.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationLong] show];
    }
    [self.tableView reloadData];
}

- (void)FetchSingleMessage: (NSString*)encodeNonce
{
    if ([_ThreadLock tryLock])
    {
        _NumNewThreadMsg = MsgCount = 0;
        // Add single nonce
        _MsgNonces = [NSMutableDictionary dictionary];
        if(MsgFinish) free(MsgFinish);
        MsgFinish = malloc(sizeof(int) * 1);
        MsgCount = 1;
        [_MsgNonces setObject:[NSNumber numberWithInt:0] forKey:encodeNonce];
        MsgFinish[0] = InitFetch;
        // Download messages
        [self DownloadMessages];
    }
}

-(void)FetchMessageNonces
{
    if([_ThreadLock tryLock]) {
        
        _NumNewThreadMsg = MsgCount = 0;
        
        NSMutableData *pktdata = [[NSMutableData alloc] init];
        //E1: Version (4bytes)
        int version = htonl([delegate getVersionNumberByInt]);
        [pktdata appendBytes: &version length: 4];
        NSString* token = [[UAPush shared]deviceToken];
        //E2: Token_len (4bytes)
        int len = htonl([token length]);
        [pktdata appendBytes: &len length: 4];
        //E3: Token
        [pktdata appendBytes:[token cStringUsingEncoding: NSUTF8StringEncoding] length: [token lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        //E4: count of query, 50 by default
        len = htonl(50);
        [pktdata appendBytes: &len length: 4];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETNONCESBYTOKEN]];
        // Default timeout
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
        [request setURL: url];
        [request setHTTPMethod: @"POST"];
        [request setHTTPBody: pktdata];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
         {
             if(error)
             {
                 [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                           [error localizedDescription],
                                           [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
                 
                 if(error.code==NSURLErrorTimedOut)
                 {
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self ToastMessageOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerNotResponding", @"No response from server."), [error localizedDescription]]];
                         [_ThreadLock unlock];
                     });
                 }else{
                     // general errors
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self ToastMessageOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                         [_ThreadLock unlock];
                     });
                 }
             }else{
                 
                 if([data length]==0)
                 {
                     // should not happen, no related error message define now
                     [delegate.activityView DisableProgress];
                     [_ThreadLock unlock];
                 }else
                 {
                     // start parsing data
                     const char *msgchar = [data bytes];
                     if(ntohl(*(int *)msgchar) == 0)
                     {
                         // Error Message
                         NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                         [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"error_msg = %@", error_msg]];
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self ToastMessageOnUI:error_msg];
                             [_ThreadLock unlock];
                         });
                     }else if(ntohl(*(int *)(msgchar+4))==1)
                     {
                         // Received Nonce Count
                         int noncecnt = ntohl(*(int *)(msgchar+8));
                         DEBUGMSG(@"Received Nonce Count: %d", noncecnt);
                         
                         if(noncecnt>0) {
                             // length check
                             _MsgNonces = [NSMutableDictionary dictionary];
                             if(MsgFinish) free(MsgFinish);
                             MsgFinish = malloc(sizeof(int) * noncecnt);
                             
                             // shift
                             int noncelen = 0;
                             msgchar = msgchar+12;
                             MsgCount = noncecnt;
                             for(int i=0;i<noncecnt;i++)
                             {
                                 noncelen = ntohl(*(int *)msgchar);
                                 msgchar = msgchar+4;
                                 NSString* encodeNonce = [[NSString alloc]
                                                          initWithData:[NSData dataWithBytes:(const unichar *)msgchar length:noncelen]
                                                          encoding:NSUTF8StringEncoding];
                                 encodeNonce = [encodeNonce stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                 msgchar = msgchar+noncelen;
                                 [_MsgNonces setObject:[NSNumber numberWithInt:i] forKey:encodeNonce];
                                 MsgFinish[i] = InitFetch;
                             }
                             // Download messages in a for loop
                             [self DownloadMessages];
                         }else{
                             // noncecnt ==0
                             DEBUGMSG(@"No available messages.");
                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                 [delegate.activityView DisableProgress];
                                 [_ThreadLock unlock];
                                 [[UAPush shared] setBadgeNumber:0];
                             });
                         }
                     }else{
                         // should not happen, in case while network has problem..
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [delegate.activityView DisableProgress];
                             [_ThreadLock unlock];
                         });
                     }
                 }
             }
             [pktdata release];
         }];
    }
    
}

-(void)DownloadMessages
{
    for(NSString* nonce in [_MsgNonces allKeys])
    {
        NSData* decodenonce = [Base64 decode:[nonce cStringUsingEncoding:NSUTF8StringEncoding] length:[nonce lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        if([decodenonce length]==NONCELEN)
        {
            if(![delegate.DbInstance CheckMessage:decodenonce])
            {
                // Received one
                [self DownloadMessage: decodenonce EncodeNonce:nonce];
            }else{
                MsgFinish[[[_MsgNonces objectForKey:nonce]integerValue]] = AlreadyExist;   // already download
            }
        }else{
            MsgFinish[[[_MsgNonces objectForKey:nonce]integerValue]] = NonceError;  // error case
        }
    }
    [self CheckQueriedMessages];
}

-(void)DownloadMessage: (NSData*)nonce EncodeNonce:(NSString*)cnonce
{
    [delegate.activityView EnableProgress:NSLocalizedString(@"prog_RequestingMessage", @"requesting encrypted message...") SecondMeesage:@"" ProgessBar:NO];
    
    NSMutableData *pktdata = [[NSMutableData alloc] init];
    //E1: Version (4bytes)
    int version = htonl([delegate getVersionNumberByInt]);
    [pktdata appendBytes: &version length: 4];
    //E2: ID_length (4bytes)
    int len = htonl([nonce length]);
    [pktdata appendBytes: &len length: 4];
    //E3: ID (random nonce)
    [pktdata appendData:nonce];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETMSG]];
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    int index = [[_MsgNonces objectForKey:cnonce]integerValue];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if(error)
         {
             MsgFinish[index] = NetworkFail; // service is unavaible
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             if(error.code==NSURLErrorTimedOut)
             {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self ToastMessageOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self ToastMessageOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                 });
             }
         }else{
             
             if ([data length] > 0 )
             {
                 // start parsing data
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Succeeded! Received %d bytes of data",[data length]);
                 DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                 if (ntohl(*(int *)msgchar) > 0)
                 {
                     // Send Response
                     DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                     DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                     // Received Encrypted Message
                     int msglen = ntohl(*(int *)(msgchar+8));
                     if(msglen<=0)
                     {
                         MsgFinish[index] = NetworkFail;
                         // display error
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self ToastMessageOnUI:NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
                         });
                     }else{
                         MsgFinish[index] = Downloaded;
                         NSData* cipher = [NSData dataWithBytes:(msgchar+12) length:msglen];
                         NSArray* EncryptPkt = [NSArray arrayWithObjects: nonce, cipher, nil];
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self SaveSecureMessage:EncryptPkt];
                         });
                     }
                 }else if(ntohl(*(int *)msgchar) == 0)
                 {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                     if([[NSString stringWithUTF8String: msgchar+4] hasSuffix:@"MessageNotFound"])
                     {
                         // expired one
                         MsgFinish[index] = Expired;
                     }else{
                         MsgFinish[index] = NetworkFail;
                     }
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self ToastMessageOnUI:error_msg];
                     });
                 }
             }
             
             dispatch_async(dispatch_get_main_queue(), ^(void) {
                 [self CheckQueriedMessages];
             });
         }
         [pktdata release];
     }];
}

-(void)CheckQueriedMessages
{
    // chekc all messages are processed
    BOOL all_processed = YES;
    for(int i=0;i<MsgCount;i++)
        if(MsgFinish[i]==InitFetch)all_processed = NO;
    
    if(all_processed) {
        
        [delegate.activityView DisableProgress];
        DEBUGMSG(@"IconBadgeNumber = %d", [[UIApplication sharedApplication]applicationIconBadgeNumber]);
        
        int _NumExpiredMsg = 0, _NumBadMsg = 0, _NumSafeMsg = 0;
        
        for(int i=0;i<MsgCount;i++)
        {
            switch (MsgFinish[i]) {
                case Expired:
                    _NumExpiredMsg++;
                    break;
                case NonceError:
                case NetworkFail:
                    _NumBadMsg++;
                    break;
                case Downloaded:
                    _NumSafeMsg++;
                    break;
                default:
                    break;
            }
        }
        DEBUGMSG(@"%d %d %d", _NumExpiredMsg, _NumBadMsg, _NumSafeMsg);
        
        // insert expired messages
        for(int i=0;i<_NumExpiredMsg;i++)
        {
            NSMutableData* ranSeed = [NSMutableData dataWithCapacity:NONCELEN];
            for( unsigned int i = 0 ; i < NONCELEN/4 ; ++i )
            {
                u_int32_t randomBits = arc4random();
                [ranSeed appendBytes:(void*)&randomBits length:4];
            }
            MsgEntry* newmsg = [[MsgEntry alloc]initSecureMessage:ranSeed UserName:@"UNDEFINED" Token:@"UNDEFINED" Message:nil SecureM:Encrypted SecureF:Encrypted];
            [delegate.DbInstance InsertMessage:newmsg];
            [newmsg release];
        }
        
        if(_NumExpiredMsg>0)
            [[[[iToast makeText: NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        
        [[UAPush shared] setBadgeNumber:0];
        
        if(![[delegate.navController topViewController]isEqual:delegate.msgDetail])
        {
            if(_NumSafeMsg>0)
            {
                NSString *info = nil;
                if(_NumSafeMsg==1)
                    info = NSLocalizedString(@"title_NotifyFileAvailable", @"SafeSlinger Message Available");
                else
                    info = [NSString stringWithFormat:NSLocalizedString(@"title_NotifyMulFileAvailable", @"%d SafeSlinger Messages Available"), _NumSafeMsg];
                [[[[iToast makeText: info]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                if([[delegate.navController topViewController]isEqual:delegate.mainView])
                {
                    [delegate.navController pushViewController:delegate.msgList animated:YES];
                }else if([[delegate.navController topViewController]isEqual:delegate.msgList])
                {
                    [self ReloadTable];
                }
            }
        }else{
            // top view is message detail
            if(_NumNewThreadMsg>0)
            {
                [delegate.msgDetail ReloadTable];
                [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"label_ClickForNMsgs", @"Touch to review your %d messages"), _NumNewThreadMsg]]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            }
        }
        
        _NumNewThreadMsg = 0;
        [_ThreadLock unlock];
    }
}

-(void)SaveSecureMessage: (NSArray*)EncryptPkt
{
    NSData* nonce = [EncryptPkt objectAtIndex:0];
    NSData* cipher = [EncryptPkt objectAtIndex:1];
    
    if(![[sha3 Keccak256Digest:cipher]isEqualToData: nonce])
    {
        [ErrorLogger ERRORDEBUG:@"ERROR: Received Message Digest Error."];
        // display error
        [self ToastMessageOnUI: NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
    }else{
        
        NSString *keyid = [SSEngine ExtractKeyID: cipher];
        NSString* keystring = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"pkey"];
        
        if(!keystring)
        {
            // cannot find a key pair, store for further use
            MsgEntry* newmsg = [[MsgEntry alloc]initSecureMessage:nonce UserName:keyid Token:keyid Message:cipher SecureM:Encrypted SecureF:Encrypted];
            if(![delegate.DbInstance InsertMessage:newmsg])
            {
                [self ToastMessageOnUI: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")];
            }
            [newmsg release];
        }else{
            // save to database
            NSString* username = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"pid"];
            NSString* tokenid = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"ptoken"];
            NSArray* namearray = [[username substringFromIndex:[username rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
            username = [NSString composite_name:[namearray objectAtIndex:1] withLastName:[namearray objectAtIndex:0]];
            MsgEntry* newmsg = [[MsgEntry alloc]initSecureMessage:nonce UserName:username Token:tokenid Message:cipher SecureM:Encrypted SecureF:Encrypted];
            
            if(![delegate.DbInstance InsertMessage:newmsg])
            {
                [self ToastMessageOnUI: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")];
            }
            [newmsg release];
            if([[delegate.navController topViewController]isEqual:delegate.msgDetail]&&[delegate.msgDetail IsCurrentThread:tokenid])
            {
                _NumNewThreadMsg++;
            }
        }
    }
}

- (void)ToastMessageOnUI:(NSString*)error
{
    [delegate.activityView DisableProgress];
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    MessageList = [[NSMutableArray alloc]init];
    b_img = [[UIImage imageNamed: @"blank_contact_small.png"]retain];
    
    // new thread button
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(CreateNewThred)];
    [self.navigationItem setRightBarButtonItem:addButton];
    [addButton release];
    addButton = nil;
}


- (void)CreateNewThred
{
    // teach user to check email if he/she needed
    [delegate.navController popViewControllerAnimated: NO];
    MessageComposer *composer = nil;
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)
    {
        if(IS_4InchScreen)
        {
            composer = [[MessageComposer alloc] initWithNibName:@"MessageComposer_4in" bundle:[NSBundle mainBundle]];
        }else{
            composer = [[MessageComposer alloc] initWithNibName:@"MessageComposer" bundle:[NSBundle mainBundle]];
        }
    }
    else{
        composer = [[MessageComposer alloc] initWithNibName:@"MessageComposer_ip5" bundle:[NSBundle mainBundle]];
    }
    
    [delegate.navController pushViewController:composer animated:YES];
    [composer release];
    composer = nil;
}


-(void)ReloadTable
{
    [MessageList setArray:[delegate.DbInstance LoadMessageThreads]];
    [self.tableView reloadData];
}

- (void)viewDidUnload
{
    [MessageList removeAllObjects];
    [MessageList release];
    MessageList = nil;
    [b_img release];    
    [super viewDidUnload];
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
    // Return the number of rows in the section.
    self.navigationItem.title = [NSString stringWithFormat:@"%d %@",[MessageList count], NSLocalizedString(@"title_Threads" ,@"Threads")];
    return [MessageList count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if([MessageList count]==0)
        return NSLocalizedString(@"label_InstNoMessages", @"No messages. You may send a message from tapping the 'Compose Message' Button in Home Menu.");
    else
        return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 70.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    // multiple line mode
    cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.detailTextLabel.numberOfLines = cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    
    MsgListEntry *MsgListEntry = [MessageList objectAtIndex:indexPath.row];
    
    // username
    NSString* display = MsgListEntry.username;
    if([MsgListEntry.token isEqualToString:@"UNDEFINED"])
        display = NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown");
    
    // message count
    [cell.textLabel setText: (MsgListEntry.ciphercount==0) ? [NSString stringWithFormat:@"%@ %d", display, MsgListEntry.messagecount] : [NSString stringWithFormat:@"%@ %d (%d)", display, MsgListEntry.messagecount, MsgListEntry.ciphercount]];
    
    // get photo
    NSString* face = [[delegate.DbInstance QueryStringInTokenTableByToken: MsgListEntry.token Field:@"note"]retain];
    [cell.imageView setImage: ([face length]==0) ? b_img : [[UIImage imageWithData: [Base64 decode:face]]scaleToSize:CGSizeMake(45.0f, 45.0f)]];
    
    // active or inactive
    NSString* pid = [delegate.DbInstance QueryStringInTokenTableByToken:MsgListEntry.token Field:@"pid"];
    [cell.imageView setAlpha: (pid==nil) ? 0.3f : 1.0f];
    
    
    NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSDateComponents *components = nil;
    
    NSDate *lastSeen;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: DATABASE_TIMESTR];
    lastSeen = [formatter dateFromString:MsgListEntry.lastSeen];
    [formatter release];
    
    components = [calendar components:NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit
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
        
        if([delegate.DbInstance DeleteThread:MsgListEntry.token])
        {
            [MessageList removeObjectAtIndex:indexPath.row];
            [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_MessagesDeleted", @"%d messages deleted."), MsgListEntry.messagecount]]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [self.tableView reloadData];
        }else{
            [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateMessageInDB", @"Unable to update the message database.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
    }
}


#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MsgListEntry* MsgListEntry = [MessageList objectAtIndex:indexPath.row];
    [delegate.msgDetail AssignedEntry: MsgListEntry];
    [delegate.navController pushViewController:delegate.msgDetail animated:YES];
}


- (void)dealloc
{
    if(MsgFinish) free(MsgFinish);
    if(_MsgNonces)[_MsgNonces release];
    if(_ThreadLock)[_ThreadLock release];
    [super dealloc];
}

@end
