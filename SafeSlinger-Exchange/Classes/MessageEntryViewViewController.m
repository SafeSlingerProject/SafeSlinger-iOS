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

#import "MessageEntryViewViewController.h"
#import "KeySlingerAppDelegate.h"
#import "SafeSlinger.h"
#import "Utility.h"
#import "sha3.h"
#import "VersionCheckMarco.h"
#import "SSEngine.h"
#import "IntroWindow.h"
#import "ErrorLogger.h"
#import "VCardParser.h"

@implementation MessageEntryViewViewController

@synthesize messages, delegate, b_img, thread_img, assignedEntry;
@synthesize InstandMessageField, InstandMessageBtn, intro_Window;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        delegate = [[UIApplication sharedApplication]delegate];
        self.tableView.allowsMultipleSelectionDuringEditing = NO;
        BackGroundQueue = dispatch_queue_create("safeslinger.background.queue", NULL);
        _ThreadLock  = [[NSLock alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    b_img = [[UIImage imageNamed: @"blank_contact_small.png"]retain];
    messages = [[NSMutableArray alloc]init];
    _previewer = [[QLPreviewController alloc] init];
    [_previewer setDataSource:self];
    [_previewer setDelegate:self];
    [_previewer setCurrentPreviewItemIndex:0];
    
    // preparefor introduction
    intro_Window = [[IntroWindow alloc] initWithNibName: @"IntroWindow" bundle: nil];
	intro_Window.view.frame = CGRectMake(40, 70, 250, 320);
	intro_Window.view.layer.cornerRadius = 10.0;
    
    // message box
    InstandMessageField = [[UITextField alloc] initWithFrame:CGRectMake(10, 5, self.view.frame.size.width*0.7, MsgBoxHieght)];
    [InstandMessageField setBorderStyle:UITextBorderStyleBezel];
    InstandMessageField.placeholder = NSLocalizedString(@"label_ComposeHint", @"Compose Message");
    InstandMessageField.font = [UIFont systemFontOfSize: 14];
    InstandMessageField.backgroundColor = [UIColor whiteColor];
    InstandMessageField.clearButtonMode = UITextFieldViewModeUnlessEditing;
    [InstandMessageField setDelegate:self];
    
    // message button
    InstandMessageBtn = [[UIButton buttonWithType:UIButtonTypeRoundedRect]retain];
    [InstandMessageBtn addTarget:self action:@selector(sendInstantMessage:) forControlEvents:UIControlEventTouchDown];
    [InstandMessageBtn setTitle:NSLocalizedString(@"btn_SendFile", @"Send") forState:UIControlStateNormal];
    InstandMessageBtn.frame = CGRectMake(self.view.frame.size.width*0.7+25, 5, self.view.frame.size.width*0.2, MsgBoxHieght);
    
    // install customized menu
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self
                                          action:@selector(customizedMenu:)];
    lpgr.minimumPressDuration = 1.0; //seconds
    lpgr.delegate = self;
    [self.view addGestureRecognizer:lpgr];
}

- (void)viewDidUnload
{
    [messages removeAllObjects];
    [messages release];
    [b_img release];
    [thread_img release];
    [assignedEntry release];
    [_previewer release];
    [InstandMessageField release];
    [InstandMessageBtn release];
    [intro_Window release];
    [super viewDidUnload];
}

- (void)AssignedEntry: (MsgListEntry*)UserEntry
{
    // assign or re-assign
    if(assignedEntry) [assignedEntry release];
    assignedEntry = [UserEntry retain];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //for unknown thread
    if([assignedEntry.token isEqualToString:@"UNDEFINED"])
    {
        [delegate.DbInstance UpdateUndefinedThread];
    }
    
    // load message
    NSString* faceraw = [delegate.DbInstance QueryStringInTokenTableByToken: assignedEntry.token Field:@"note"];
    if([faceraw length]>0)
    {
        thread_img = [[[UIImage imageWithData:[Base64 decode:faceraw]]scaleToSize:CGSizeMake(45.0f, 45.0f)]retain];
    }else{
        thread_img = nil;
    }
    [messages removeAllObjects];
    [messages setArray:[delegate.DbInstance LoadThreadMessage: assignedEntry.token]];
    [self.tableView reloadData];
}

-(void)sendInstantMessage:(id)sender
{
    if([InstandMessageField isFirstResponder])[InstandMessageField resignFirstResponder];
    
    if([InstandMessageField.text length]>0)
    {
        [InstandMessageBtn setEnabled:NO];
        [self sendSecureText: InstandMessageField.text];
    }
}

- (void)sendSecureText: (NSString*)msgbody
{
    NSData* packnonce = nil;
    NSMutableData* pktdata = nil;
    int DevType = [delegate.DbInstance GetDEVTypeByToken: assignedEntry.token];
    
    NSURL *url = nil;
    switch (DevType) {
        case Android:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTANDROIDMSG]];
            break;
        case iOS:
            url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTIOSMSG]];
            break;
        default:
            break;
    }
    if(!url){
        [InstandMessageBtn setEnabled:YES];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [delegate.activityView EnableProgress:NSLocalizedString(@"prog_encrypting", @"encrypting...") SecondMeesage:@"" ProgessBar:NO];
        });
    });
    
    pktdata = [[NSMutableData alloc]initWithCapacity:0];
    packnonce = [SSEngine BuildCipher:assignedEntry.username Token:assignedEntry.token Message:msgbody Attach:nil RawFile:nil MIMETYPE:nil Cipher:pktdata];
    
    // Default timeout
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
    [request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: pktdata];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [delegate.activityView UpdateProgessMsg: NSLocalizedString(@"prog_FileSent", @"message sent, awaiting response...")];
        });
    });
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if(error)
         {
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Internet Connection failed. Error - %@ %@",
                        [error localizedDescription],
                        [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             if(error.code==NSURLErrorTimedOut)
             {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [[[[iToast makeText: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")]
                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]]
                        setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // start parsing data
                 DEBUGMSG(@"Succeeded! Received %d bytes of data",[data length]);
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
                 if (ntohl(*(int *)msgchar) > 0)
                 {
                     // Send Response
                     DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
                     DEBUGMSG(@"Send Message Response: %s", msgchar+8);
                     // Save to Database
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self SaveText:packnonce];
                     });
                 }else if(ntohl(*(int *)msgchar) == 0)
                 {
                     // Error Message
                     NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
                     DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self PrintErrorOnUI:error_msg];
                     });
                 }
             }
         }
         [pktdata release];
         [delegate.activityView DisableProgress];
         [InstandMessageBtn setEnabled:YES];
     }];
}

-(void)SaveText: (NSData*)msgid
{
    MsgEntry *NewMsg = [[MsgEntry alloc]
                        initPlainTextMessage:msgid
                        UserName:assignedEntry.username
                        Token:assignedEntry.token
                        Message:InstandMessageField.text
                        Photo:nil
                        FileName:nil
                        FileType:nil
                        FIleData:nil];
    if([delegate.DbInstance InsertMessage: NewMsg])
    {
        // reload the view
        [[[[iToast makeText: NSLocalizedString(@"state_FileSent", @"Message sent.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [self ReloadTable];
    }else{
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveMessageInDB", @"Unable to save to the message database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    [NewMsg release];
    InstandMessageField.text = nil;
}


- (void)PrintErrorOnUI:(NSString*)error
{
    [InstandMessageBtn setEnabled:YES];
    [delegate.activityView DisableProgress];
    [[[[iToast makeText: error]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    InstandMessageField.text = nil;
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
{
    UIView* header = nil;
    if([delegate.DbInstance SearchRecipient:assignedEntry.token])
    {
        header = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, MsgBoxHieght)] autorelease];
        [header addSubview:InstandMessageField];
        [header addSubview:InstandMessageBtn];
    }
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
{
    if([delegate.DbInstance SearchRecipient:assignedEntry.token])
        return MsgBoxHieght+10.0f;
    else
        return 0.0f;
}

- (void)viewWillDisappear:(BOOL)animated
{
    if(delegate.activityView.isShow)[_ThreadLock unlock];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    assignedEntry.ciphercount = [delegate.DbInstance ThreadCipherCount: assignedEntry.token];
    assignedEntry.messagecount = [delegate.DbInstance ThreadMessageCount: assignedEntry.token];
    
    NSString* displayName = assignedEntry.username;
    if([displayName isEqualToString:@"UNDEFINED"]) displayName = NSLocalizedString(@"label_undefinedTypeLabel", @"Unknown");
    
    if(assignedEntry.ciphercount==0)
        self.navigationItem.title = [NSString stringWithFormat:@"%@ %d", displayName, assignedEntry.messagecount];
    else
        self.navigationItem.title = [NSString stringWithFormat:@"%@ %d (%d)", displayName, assignedEntry.messagecount, assignedEntry.ciphercount];
    return [messages count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if([messages count]==0)
        return NSLocalizedString(@"label_InstNoMessages", @"No messages. You may send a message from tapping the 'Compose Message' Button in Home Menu.");
    else
        return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat totalheight = 0.0f;
    MsgEntry* msg = [messages objectAtIndex:indexPath.row];
    if(msg.smsg)
    {
        totalheight = 60.0f;
    }else{
        totalheight += 62.0f;
        if([msg.msgbody length]>0)
        {
            totalheight += [[NSString stringWithUTF8String: [msg.msgbody bytes]]
                            sizeWithFont:[UIFont systemFontOfSize:12] constrainedToSize:CGSizeMake(300, CGFLOAT_MAX)].height;
        }
        if(msg.attach) totalheight += 56.0f;
    }
    return totalheight;
}


#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
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
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont systemFontOfSize:14];
    
    cell.imageView.image = nil;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    cell.textLabel.text = nil;
    
    if([assignedEntry.token isEqualToString:@"UNDEFINED"])
    {
        MsgEntry* msg = [messages objectAtIndex:indexPath.row];
        [cell.imageView setImage:b_img];
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.text = NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.");
        
        // Display Time
        NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
        NSDateComponents *components = nil;
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [formatter setDateFormat: DATABASE_TIMESTR];
        NSDate *cDate = [formatter dateFromString:msg.cTime];
        [formatter release];
        
        components = [calendar components:NSDayCalendarUnit
                                 fromDate: cDate
                                   toDate: [NSDate date]
                                  options:0];
        // for efficiency
        if(components.day>0){
            cell.detailTextLabel.text = [NSString ChangeGMT2Local: msg.cTime GMTFormat:DATABASE_TIMESTR LocalFormat:@"MMM dd"];
        }else{
            cell.detailTextLabel.text = [NSString ChangeGMT2Local: msg.cTime GMTFormat:DATABASE_TIMESTR LocalFormat:@"hh:mm a"];
        }
        
    }else{
        MsgEntry* msg = [messages objectAtIndex:indexPath.row];
        if(msg.smsg==Encrypted)
        {
            // encrypted message
            cell.textLabel.textColor = [UIColor blueColor];
            cell.textLabel.text = NSLocalizedString(@"label_TapToDecryptMessage", @"Tap to decrypt");
        }else{
            NSMutableString* msgText = [NSMutableString stringWithCapacity:0];
            // plaintext message
            cell.detailTextLabel.textColor = [UIColor grayColor];
            
            // new thread, show picture
            if(msg.dir==ToMsg){
                // To message
                UIImageView *imageView = nil;
                if([delegate.SelfPhotoCache length]>0)
                    imageView = [[UIImageView alloc] initWithImage:[UIImage imageWithData: delegate.SelfPhotoCache]];
                else
                    imageView = [[UIImageView alloc] initWithImage:b_img];
                cell.accessoryView = imageView;
                [imageView release];
            }else{
                // From message
                if(thread_img)
                    [cell.imageView setImage:thread_img];
                else
                    [cell.imageView setImage:b_img];
            }
            
            // Display Time
            NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
            NSDateComponents *components = nil;
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            [formatter setDateFormat: DATABASE_TIMESTR];
            NSDate *cDate = [formatter dateFromString:msg.cTime];
            [formatter release];
            
            components = [calendar components:NSDayCalendarUnit
                                     fromDate: cDate
                                       toDate: [NSDate date]
                                      options:0];
            // for efficiency
            if(components.day>0){
                [msgText appendString:[NSString ChangeGMT2Local: msg.cTime GMTFormat:DATABASE_TIMESTR LocalFormat:@"MMM dd"]];
            }else{
                [msgText appendString:[NSString ChangeGMT2Local: msg.cTime GMTFormat:DATABASE_TIMESTR LocalFormat:@"hh:mm a"]];
            }
            cell.detailTextLabel.text = msgText;
            
            // set as empty string
            [msgText setString:@""];
            NSString* textbody = nil;
            if([msg.msgbody length]>0)
                textbody = [[[NSString alloc] initWithData:msg.msgbody encoding:NSUTF8StringEncoding] autorelease];
            if(textbody)
                [msgText appendString:textbody];
            
            cell.textLabel.textColor = [UIColor blackColor];
            
            if(msg.attach){
                if(msg.sfile) {
                    
                    FileInfo *fio = [delegate.DbInstance GetFileInfo:msg.msgid];
                    // display file size
                    NSDate *plus1day = [cDate dateByAddingTimeInterval:60*60*24];
                    components = [calendar components:NSHourCalendarUnit|NSMinuteCalendarUnit
                                             fromDate:[NSDate date]
                                               toDate:plus1day
                                              options:0];
                    // display file expiration time
                    if(components.minute<=0||components.hour<=0)
                    {
                        // negative, expired
                        cell.textLabel.textColor = [UIColor redColor];
                        [msgText appendFormat:@"\n%@", NSLocalizedString(@"label_expired", @"expired")];
                    }else{
                        [msgText appendFormat: @"\n%@:\n%@ (%@)", NSLocalizedString(@"label_TapToDownloadFile", @"Tap to download file"), fio.FName, [NSString CalculateMemorySize:fio.FSize]];
                        [msgText appendFormat:@"\n(%@: %@ %@)",
                         NSLocalizedString(@"label_expiresIn", @"expires in"),
                         [NSString stringWithFormat:NSLocalizedString(@"label_hours", @"%d hrs"), components.hour],
                         [NSString stringWithFormat:NSLocalizedString(@"label_minutes", @"%d min"), components.minute]
                         ];
                    }
                    [fio release];
                }else {
                    [msgText appendFormat: @"\n%@:\n%@", NSLocalizedString(@"label_TapToOpenFile", @"Tap to open file"), msg.fname];
                }
            }
            cell.textLabel.text = msgText;
        }
    }
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        MsgEntry* entry = [messages objectAtIndex:indexPath.row];
        if([delegate.DbInstance DeleteMessage: entry.msgid])
        {
            [messages removeObjectAtIndex:indexPath.row];
            [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_MessagesDeleted", @"%d messages deleted."), 1]]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [self.tableView reloadData];
        }else{
            [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateMessageInDB", @"Unable to update the message database.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
    }
}

#pragma mark - UITextFieldDelegate       
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    // became first responder
    textField.text = @"";
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    // return YES to allow editing to stop and to resign first responder status. NO to disallow the editing session to end
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    // may be called if forced even if shouldEndEditing returns NO (e.g. view removed from window) or endEditing:YES called
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // return NO to not change text
    return YES;
}

/*
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // called when clear button pressed. return NO to ignore (no notifications)
    return NO;
}
*/

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // called when 'return' key pressed. return NO to ignore.
    [textField resignFirstResponder];
    return NO;
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (BOOL)IsCurrentThread: (NSString*)token
{
    return [assignedEntry.token isEqualToString:token];
}

-(void)UpdateTableEntry: (NSArray*)entries
{
    // load message
    [messages setArray:[delegate.DbInstance LoadThreadMessage: assignedEntry.token]];
    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:entries withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
}

-(void)ReloadTable
{
    // load message
    [messages setArray:[delegate.DbInstance LoadThreadMessage: assignedEntry.token]];
    [self.tableView reloadData];
}

- (void)dealloc {
    dispatch_release(BackGroundQueue);
    [_ThreadLock release];
    [super dealloc];
}


#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if([assignedEntry.token isEqualToString:@"UNDEFINED"]) return;
    
    MsgEntry* entry = [messages objectAtIndex:indexPath.row];
    if(entry.smsg==Encrypted)
    {
        if([self.tableView cellForRowAtIndexPath:indexPath].tag!=-1&&[_ThreadLock tryLock])
        {
            [delegate.activityView EnableProgress:NSLocalizedString(@"prog_decrypting", @"decrypting...") SecondMeesage:@"" ProgessBar:NO];
            dispatch_async(BackGroundQueue, ^(void) {
                [self DecryptMessage: entry WithIndex: indexPath];
            });
        }
    }
    else if(entry.attach&&(entry.sfile==Encrypted))
    {
        if([self.tableView cellForRowAtIndexPath:indexPath].tag!=-1)
        {
            // check expired time again
            NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            [formatter setDateFormat: DATABASE_TIMESTR];
            NSDate *plus1day = [[formatter dateFromString:entry.cTime] dateByAddingTimeInterval:60*60*24];
            [formatter release];
            NSDateComponents *components = [calendar components: NSHourCalendarUnit|NSMinuteCalendarUnit
                                                       fromDate: [NSDate date]
                                                         toDate: plus1day
                                                        options:0];
            
            if(components.minute<=0||components.hour<=0)
            {
                // negative, expired
            }else if([_ThreadLock tryLock])
            {
                // not expired
                FileInfo *f = [delegate.DbInstance GetFileInfo:entry.msgid];
                [delegate.activityView EnableProgress:NSLocalizedString(@"prog_RequestingFile", @"requesting encrypted file...") SecondMeesage:@"" ProgessBar:NO];
                [self DownloadFile:entry.msgid WithIndex: indexPath];
                [f release];
            }
        }
    }else if(entry.attach&&(!entry.sfile))
    {
        FileInfo *fio = [delegate.DbInstance GetFileInfo: entry.msgid];
        if([fio.FExt isEqualToString:@"SafeSlinger/SecureIntroduce"])
        {
            // secure introduce capability
            self.tRecord = [VCardParser vCardToContact: [NSString stringWithCString:[[delegate.DbInstance QueryInMsgTableByMsgID:entry.msgid Field:@"fbody"]bytes] encoding:NSUTF8StringEncoding]];
            
            UIImage* face = nil;
            if(ABPersonHasImageData(_tRecord))
            {
                // use Thumbnail image
                face = [[UIImage imageWithData:(NSData *)ABPersonCopyImageDataWithFormat(_tRecord, kABPersonImageFormatThumbnail)]scaleToSize:CGSizeMake(45.0f, 45.0f)];
            }else{
                face = b_img;
            }
            
            NSString* introducer;
            CFStringRef firstName = ABRecordCopyValue(_tRecord, kABPersonFirstNameProperty);
            CFStringRef lastName = ABRecordCopyValue(_tRecord, kABPersonLastNameProperty);
            introducer = [NSString composite_name:(NSString*)firstName withLastName:(NSString*)lastName];
            if(firstName)CFRelease(firstName);
            if(lastName)CFRelease(lastName);
            
            if(!introducer)
            {
                [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
                   setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
            }else{
                [self DisplayUserInfo:[[NSString alloc] initWithData:[delegate.DbInstance QueryInMsgTableByMsgID:entry.msgid Field:@"sender"]encoding:NSUTF8StringEncoding] Invite:introducer Photo:face];
            }
            
        }else {
            
            // general data, open by preview
            NSData* attchData = [delegate.DbInstance QueryInMsgTableByMsgID:entry.msgid Field:@"fbody"];
            BOOL success;
            NSString* tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:fio.FName];
            if([[NSFileManager defaultManager] fileExistsAtPath: tmpfile])
            {
                success = [attchData writeToFile: tmpfile atomically:YES];
            }else {
                success = [[NSFileManager defaultManager] createFileAtPath: tmpfile contents:attchData attributes:nil];
            }
            
            // start preview
            if(success&&![[self.navigationController topViewController]isEqual:_previewer])
            {
                DEBUGMSG(@"start preview.");
                _preview_cache_page = [NSURL fileURLWithPath: tmpfile];
                [_previewer reloadData];
                [self.navigationController pushViewController: _previewer animated:YES];
            }
        }
        [fio release];
    }
}

-(void) DisplayUserInfo: (NSString*)invitee Invite:(NSString*)inviter Photo:(UIImage*)faceImg
{
    // show dialog
    [intro_Window.Title setText:NSLocalizedString(@"title_SecureIntroductionInvite", @"Secure Introduction Invitation!")];
    [intro_Window.LabelA setText:NSLocalizedString(@"label_Me", @"Me")];
    [intro_Window.LabelB setText:[NSString stringWithFormat:@"%@\n%@",
                                  NSLocalizedString(@"label_safeslingered", @"(SafeSlinger Direct Exchange)"),
                                  invitee]];
    [intro_Window.LabelC setText:inviter];
    [intro_Window.FacePhoto setImage:faceImg];
    [intro_Window.AcceptBtn setTitle:NSLocalizedString(@"btn_Accept", @"Accept") forState:UIControlStateNormal];
    [intro_Window.RefuseBtn setTitle:NSLocalizedString(@"btn_Refuse", @"Refuse") forState:UIControlStateNormal];
    
    [intro_Window.AcceptBtn addTarget:self action:@selector(BeginImport:) forControlEvents:UIControlEventTouchUpInside];
    [intro_Window.RefuseBtn addTarget:self action:@selector(CancelImport:) forControlEvents:UIControlEventTouchUpInside];
    
    // display
    [delegate.window addSubview:intro_Window.view];
    [intro_Window becomeFirstResponder];
}


-(void)CancelImport: (id)sender
{
    if(_tRecord)CFRelease(_tRecord);
    [intro_Window resignFirstResponder];
    [intro_Window.view removeFromSuperview];
}

-(void)BeginImport: (id)sender
{
    [intro_Window resignFirstResponder];
    [intro_Window.view removeFromSuperview];
    if(_tRecord)
    {
        NSString *retcnt = [NSString stringWithFormat:@"%d", [self AddNewContact:_tRecord]];
        // show dialog
        [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_SomeContactsImported", @"%@ contacts imported."), retcnt]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        CFRelease(_tRecord);_tRecord = NULL;
    }else{
        // Record is null
        [ErrorLogger ERRORDEBUG: @"ERROR: The record is a null object."];
        [[[[iToast makeText: NSLocalizedString(@"error_VcardParseFailure", @"vCard parse failed.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
}


/*
 Return value error or failOverwrite(0), success(1)
 */
- (int)AddNewContact: (ABRecordRef)newRecord
{
    if(![delegate.mainView checkContactPermission])
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        return 0;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG:@"ERROR: Contact Permission Not Granted."];
        }
    });
    
	CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
    NSString* comparedtoken = nil;
    NSData *keyelement = nil;
    NSData *token = nil;
    
    NSString *firstname = (NSString*)ABRecordCopyValue(newRecord, kABPersonFirstNameProperty);
    NSString *lastname = (NSString*)ABRecordCopyValue(newRecord, kABPersonLastNameProperty);
    if(firstname==nil&&lastname==nil)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_VcardParseFailure", @"vCard parse failed.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        if(allPeople!=NULL)CFRelease(allPeople);
        if(aBook!=NULL)CFRelease(aBook);
        return 0;
    }
    
    NSString* username = [NSString vcardnstring:firstname withLastName:lastname];
    
    // Get SafeSlinger Fields
    ABMultiValueRef allIMPP = ABRecordCopyValue(newRecord, kABPersonInstantMessageProperty);
    for (CFIndex i = 0; i < ABMultiValueGetCount(allIMPP); i++)
    {
        CFDictionaryRef anIMPP = ABMultiValueCopyValueAtIndex(allIMPP, i);
        if ([(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey) caseInsensitiveCompare:@"SafeSlinger-PubKey"] == NSOrderedSame)
        {
            keyelement = [Base64 decode:(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey)];
            keyelement = [NSData dataWithBytes:[keyelement bytes] length:[keyelement length]];
        }else if([(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey) caseInsensitiveCompare:@"SafeSlinger-Push"] == NSOrderedSame)
        {
            comparedtoken = (NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey);
            token = [Base64 decode:comparedtoken];
        }
        if(anIMPP!=NULL)CFRelease(anIMPP);
    }
    if(allIMPP!=NULL)CFRelease(allIMPP);
    
    if(keyelement==nil||token==nil)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_VcardParseFailure", @"vCard parse failed.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        if(allPeople!=NULL)CFRelease(allPeople);
        if(aBook!=NULL)CFRelease(aBook);
        return 0;
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
    if(ABPersonHasImageData(newRecord))
    {
        // use Thumbnail image
        CFDataRef photo = ABPersonCopyImageDataWithFormat(newRecord, kABPersonImageFormatThumbnail);
        UIImage* img = [UIImage imageWithData:(NSData *)photo];
        imageData = [Base64 encode: UIImageJPEGRepresentation(img, 0.9)];
        CFRelease(photo);
    }
    
    // instead of using name to check existance, using token to check
    BOOL hasAccountExist = NO;
    int ex_type = -1;
    
    NSString* peer = [delegate.DbInstance SearchRecipient: tokenstr];
    if(peer)
    {
        ex_type = [delegate.DbInstance GetEXTypeByToken: tokenstr];
        if(ex_type==Exchanged)
        {
            // do not overwirte it
            [ErrorLogger ERRORDEBUG: @"ERROR: Already Exchanged Before, Do Not Overwrite."];
            if(allPeople!=NULL)CFRelease(allPeople);
            if(aBook!=NULL)CFRelease(aBook);
            return 0;
        }
        
        // update contact database
        if(username)
        {
            // already exist, check contact database
            for (CFIndex j = 0; j < CFArrayGetCount(allPeople); j++)
            {
                ABRecordRef existing = CFArrayGetValueAtIndex(allPeople, j);
                NSString *existingName = [NSString vcardnstring:ABRecordCopyValue(existing, kABPersonFirstNameProperty) withLastName:ABRecordCopyValue(existing, kABPersonLastNameProperty)];
                
                if ([peer isEqualToString: existingName]||[username isEqualToString: existingName])
                {
                    // check IMPP field
                    ABMultiValueRef allIMPP = ABRecordCopyValue(existing, kABPersonInstantMessageProperty);
                    for (CFIndex i = 0; i < ABMultiValueGetCount(allIMPP); i++)
                    {
                        CFDictionaryRef anIMPP = ABMultiValueCopyValueAtIndex(allIMPP, i);
                        if([(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey) caseInsensitiveCompare:@"SafeSlinger-Push"] == NSOrderedSame)
                        {
                            if([comparedtoken isEqualToString:(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey)])
                            {
                                hasAccountExist = YES;
                                // remove it
                                if(!ABAddressBookRemoveRecord(aBook, existing, &error))
                                {
                                    [[[[iToast makeText: NSLocalizedString(@"error_ContactUpdateFailed", @"Contact update failed.")]
                                       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                                    [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"ERROR: Unable to remove the old record. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
                                    if(allPeople!=NULL)CFRelease(allPeople);
                                    if(aBook!=NULL)CFRelease(aBook);
                                    return 0;
                                }
                            }
                        }
                        if(anIMPP)CFRelease(anIMPP);
                    }
                    if(allIMPP)CFRelease(allIMPP);
                }
            }// end of for
        }
    }
    
    // add VCard and update database
    if(!ABAddressBookAddRecord(aBook, newRecord, &error)){
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Unable to Add the new record. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
        if(hasAccountExist)
        {
            [[[[iToast makeText: NSLocalizedString(@"error_ContactUpdateFailed", @"Contact update failed.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            if(allPeople!=NULL)CFRelease(allPeople);
            if(aBook!=NULL)CFRelease(aBook);
            return 0;
        }else{
            [[[[iToast makeText: NSLocalizedString(@"error_ContactInsertFailed", @"Contact insert failed.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            if(allPeople!=NULL)CFRelease(allPeople);
            if(aBook!=NULL)CFRelease(aBook);
            return 0;
        }
    }
    
    if(!ABAddressBookSave(aBook, &error))
    {
        [[[[iToast makeText: NSLocalizedString(@"error_UnableToSaveRecipientInDB", @"Unable to save to the recipient database.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Unable to Save ABAddressBook. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
        if(allPeople!=NULL)CFRelease(allPeople);
        if(aBook!=NULL)CFRelease(aBook);
        return 0;
    }
    if(allPeople)CFRelease(allPeople);
	if(aBook)CFRelease(aBook);
    
    // handle key and token update
    if(peer){
        if(![delegate.DbInstance UpdateToken:tokenstr User:username Dev:devtype Photo:imageData KeyData:keyelement ExchangeOrIntroduction:NO])
        {
            [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateRecipientInDB", @"Unable to update the recipient database.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            return 0;
        }
    }else{
        if(![delegate.DbInstance RegisterToken:tokenstr User:username Dev:devtype Photo:imageData KeyData:keyelement ExchangeOrIntroduction:NO])
        {
            [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateRecipientInDB", @"Unable to update the recipient database.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            return 0;
        }
    }
    
    return 1;
}


- (void)DownloadFile: (NSData*)nonce WithIndex:(NSIndexPath*)index 
{
    [self.tableView cellForRowAtIndexPath:index].tag = -1;
    
    // save msg nonce
    NSMutableData *pktdata = [[NSMutableData alloc] init];
    //E1: Version (4bytes)
    int version = htonl([delegate getVersionNumberByInt]);
    [pktdata appendBytes: &version length: 4];
    //E2: ID_length (4bytes)
    int len = htonl([nonce length]);
    [pktdata appendBytes: &len length: 4];
    //E3: ID (random nonce), length = FILEID_LEN
    [pktdata appendData:nonce];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, GETFILE]];
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
             // inform the user
             [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Internet Connection failed. Error - %@ %@",
                                       [error localizedDescription],
                                       [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
             if(error.code==NSURLErrorTimedOut)
             {
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self.tableView cellForRowAtIndexPath:index].tag = 0;
                     [self PrintErrorOnUI:NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")];
                     [_ThreadLock unlock];
                 });
             }else{
                 // general errors
                 dispatch_async(dispatch_get_main_queue(), ^(void) {
                     [self.tableView cellForRowAtIndexPath:index].tag = 0;
                     [self PrintErrorOnUI:[NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]];
                     [_ThreadLock unlock];
                 });
             }
         }else{
             if ([data length] > 0 )
             {
                 // get attachment
                 const char *msgchar = [data bytes];
                 DEBUGMSG(@"Response Code: %d", ntohl(*(int *)(msgchar+4)));
                 int msglen = ntohl(*(int *)(msgchar+8));
                 DEBUGMSG(@"Received Packet Size: %d", msglen);
                 if(msglen<=0)
                 {
                     [ErrorLogger ERRORDEBUG:@"message length is less than 0"];
                     // display error
                     dispatch_async(dispatch_get_main_queue(), ^(void) {
                         [self.tableView cellForRowAtIndexPath:index].tag = 0;
                         [self PrintErrorOnUI:NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
                         [_ThreadLock unlock];
                     });
                     
                 }else{
                     NSData* encryptedfile = [NSData dataWithBytes:(msgchar+12) length:msglen];
                     NSData* filehash = [delegate.DbInstance QueryInMsgTableByMsgID:nonce Field: @"fbody"];
                     NSRange r;r.location = 0;r.length = NONCELEN;
                     filehash = [filehash subdataWithRange:r];
                     
                     // before decrypt we have to check the file hash
                     if(![[sha3 Keccak256Digest:encryptedfile]isEqualToData:filehash])
                     {
                        [ErrorLogger ERRORDEBUG:@"ERROR: Download File Digest Mismatch."];
                         // display error
                         dispatch_async(dispatch_get_main_queue(), ^(void) {
                             [self.tableView cellForRowAtIndexPath:index].tag = 0;
                             [self PrintErrorOnUI:NSLocalizedString(@"error_InvalidIncomingMessage", @"Bad incoming message format.")];
                             [_ThreadLock unlock];
                         });
                     }else{
                         // save to database
                         NSString* pubkeySet = [delegate.DbInstance QueryStringInTokenTableByKeyID:[SSEngine ExtractKeyID: encryptedfile] Field:@"pkey"];
                         NSMutableData *cipher = [NSMutableData dataWithCapacity:[encryptedfile length]-LENGTH_KEYID];
                         // remove keyid first
                         [cipher appendBytes:([encryptedfile bytes]+LENGTH_KEYID) length:([encryptedfile length]-LENGTH_KEYID)];
                         // unlock private key
                         int PRIKEY_STORE_SIZE = 0;
                         [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
                         NSData* DecKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
                         NSData* decipher = [SSEngine UnpackMessage: cipher PubKey:pubkeySet Prikey: DecKey];
                         if([decipher length]==0||!decipher)
                         {
                             // display error
                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                 [self.tableView cellForRowAtIndexPath:index].tag = 0;
                                 [self PrintErrorOnUI:NSLocalizedString(@"error_InvalidMsg", @"Bad message format.")];
                                 [_ThreadLock unlock];
                             });
                             [ErrorLogger ERRORDEBUG: @"ERROR: The size of decipher is zero or decipher is nil."];
                         }else{
                             [delegate.DbInstance UpdateFileBody:nonce DecryptedData:decipher];
                             dispatch_async(dispatch_get_main_queue(), ^(void) {
                                 [self.tableView cellForRowAtIndexPath:index].tag = 0;
                                 [delegate.activityView DisableProgress];
                                 [self UpdateTableEntry:[NSArray arrayWithObjects:index, nil]];
                                 [_ThreadLock unlock];
                             });
                         }
                     }
                 }
             }
         }
         [pktdata release];
     }];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return YES;
}

- (void) customizedMenu:(UILongPressGestureRecognizer *) gestureRecognizer {
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        [gestureRecognizer.view becomeFirstResponder];
        CGPoint p = [gestureRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        if (indexPath) {
            if(_selectIndex) [_selectIndex release];
            _selectIndex = [indexPath retain];
            UIMenuItem *command1 = [[UIMenuItem alloc] initWithTitle: NSLocalizedString(@"menu_messageCopyText", @"Copy Text") action:@selector(CopyText:)];
            NSArray *menuItems = [NSArray arrayWithObjects:command1, nil];
            CGRect rect = cell.frame;
            UIMenuController *menu = [UIMenuController sharedMenuController];
            [menu setMenuItems:menuItems];
            [menu setTargetRect:rect inView:gestureRecognizer.view];
            [menu setMenuVisible:YES animated:YES];
        }
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(CopyText:)) {
        return YES;
    }
    return NO;
}

- (void)CopyText:(id)sender
{
    //what to copy
    UIPasteboard *gpBoard = [UIPasteboard generalPasteboard];
    NSString* copytext = [[self.tableView cellForRowAtIndexPath: _selectIndex]textLabel].text;
    if(![copytext isEqual:@""])
    {
        [gpBoard setString: copytext];
    }
}


- (id <QLPreviewItem>)previewController: (QLPreviewController *)controller previewItemAtIndex:(NSInteger)index
{
	return _preview_cache_page;
}

- (NSInteger) numberOfPreviewItemsInPreviewController: (QLPreviewController *) controller
{
	return 1;
}

- (void)DecryptMessage: (MsgEntry*)msg WithIndex:(NSIndexPath*)index
{
    [self.tableView cellForRowAtIndexPath:index].tag = -1;
    BOOL hasfile = NO;
    // tap to decrypt
    NSString *keyid = [SSEngine ExtractKeyID: msg.msgbody];
    NSString* pubkeySet = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"pkey"];
    
    if(pubkeySet==nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[[[iToast makeText: NSLocalizedString(@"error_UnableFindPubKey", @"Unable to match public key to private key in crypto provider.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [self.tableView cellForRowAtIndexPath:index].tag = 0;
            [delegate.activityView DisableProgress];
            [_ThreadLock unlock];
        });
        return;
    }
    
    NSString* username = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"pid"];
    NSString* usertoken = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"ptoken"];
    NSString* imageData = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"note"];
    
    UIImage* img = [UIImage imageWithData:(NSData *)[Base64 decode:imageData]];
    CGSize ns; ns.height = ns.width = 45.0f;
    img = [img scaleToSize:ns];
    imageData = [Base64 encode:UIImageJPEGRepresentation(img, 0.9)];
    
    NSArray* namearray = [[username substringFromIndex:[username rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
    username = [NSString composite_name:[namearray objectAtIndex:1] withLastName:[namearray objectAtIndex:0]];
    
    NSMutableData *cipher = [NSMutableData dataWithCapacity:[msg.msgbody length]-LENGTH_KEYID];
    // remove keyid first
    [cipher appendBytes:([msg.msgbody bytes]+LENGTH_KEYID) length:([msg.msgbody length]-LENGTH_KEYID)];
    int PRIKEY_STORE_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
    NSData* DecKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
    if(!DecKey)
        [ErrorLogger ERRORDEBUG: @"ERROR: Private key is nil."];
    NSData* decipher = [SSEngine UnpackMessage: cipher PubKey:pubkeySet Prikey: DecKey];
    
    // parsing
    if([decipher length]==0||!decipher)
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: The size of decipher is zero or decipher is nil."];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [[[[iToast makeText: NSLocalizedString(@"error_InvalidMsg", @"Bad message format.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [self.tableView cellForRowAtIndexPath:index].tag = 0;
            [delegate.activityView DisableProgress];
            [_ThreadLock unlock];
        });
        return;
    }
    
    const char * p = [decipher bytes];
    int offset = 0, len = 0;
    unsigned int flen = 0;
    NSString* fname = nil;
    NSString* ftype = nil;
    NSString* peer = nil;
    NSString* text = nil;
    NSString* gmt = nil;
    NSData* filehash = nil;
    
    // parse message format
    DEBUGMSG(@"Version: %02X", ntohl(*(int *)p));
    offset += 4;
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    
    const char* localdate = [[NSData dataWithBytes:p+offset length:len]bytes];
    offset = offset+len;
    
    flen = (unsigned int)ntohl(*(int *)(p+offset));
    if(flen>0) hasfile=YES;
    offset += 4;
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        fname = [[NSString alloc] initWithData:[NSData dataWithBytes:p+offset length:len]
                                      encoding:NSUTF8StringEncoding];
        // handle file name
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle file type
        ftype = [NSString stringWithCString:[[NSData dataWithBytes:p+offset length:len]bytes] encoding:NSASCIIStringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle text
        text = [NSString stringWithCString:[[NSData dataWithBytes:p+offset length:len]bytes] encoding:NSUTF8StringEncoding];
        DEBUGMSG(@"text = %@", text);
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle Person Name
        peer = [NSString stringWithCString:[[NSData dataWithBytes:p+offset length:len]bytes] encoding:NSUTF8StringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle text
        gmt = [NSString stringWithCString:[[NSData dataWithBytes:p+offset length:len]bytes] encoding:NSASCIIStringEncoding];
        offset = offset+len;
    }
    
    len = ntohl(*(int *)(p+offset));
    offset += 4;
    if(len>0){
        // handle text
        filehash = [NSData dataWithBytes:p+offset length:len];
        offset = offset+len;
    }
    
    // decrypt it and update db
    [delegate.DbInstance UpdateMessage:msg.msgid NewMSG:text Time:gmt User:username Token:usertoken Photo:imageData];
    
    // update file if necessary
    if(hasfile)
    {
        NSMutableData *finfo = [NSMutableData data];
        [finfo appendData:filehash];
        [finfo appendBytes:&flen length:sizeof(flen)];
        [delegate.DbInstance UpdateFileInfo:msg.msgid filename:fname filetype:ftype Time:gmt fileinfo:finfo];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.tableView cellForRowAtIndexPath:index].tag = 0;
        [delegate.activityView DisableProgress];
        [self ReloadTable];
        [_ThreadLock unlock];
    });
}

@end
