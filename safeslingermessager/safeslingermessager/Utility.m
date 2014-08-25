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

#import "Utility.h"
#import "SafeSlingerDB.h"
#import "ErrorLogger.h"
#import "FunctionView.h"
#import "AppDelegate.h"
#import <AddressBook/AddressBook.h>

@implementation UtilityFunc

+ (void)SendOpts: (UIViewController<MFMailComposeViewControllerDelegate>*)VC
{
    // Email Subject
    NSString *emailTitle = [NSString stringWithFormat:@"%@(iOS%@)",
                            NSLocalizedString(@"title_comments", @"Questions/Comments"),
                            [(AppDelegate*)[[UIApplication sharedApplication]delegate]getVersionNumber]];
    
    NSArray *toRecipents = [NSArray arrayWithObject:@"safeslingerapp@gmail.com"];
    
    if([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
        [mc setTitle:NSLocalizedString(@"menu_sendFeedback", @"Send Feedback")];
        mc.mailComposeDelegate = VC;
        [mc setSubject:emailTitle];
        [mc setToRecipients:toRecipents];
        
        NSString *detail = [ErrorLogger GetLogs];
        if(detail)
        {
            // add attachment for debug
            [mc addAttachmentData:[detail dataUsingEncoding:NSUTF8StringEncoding] mimeType:@"text/txt" fileName:@"feedback.txt"];
            [ErrorLogger CleanLogFile];
        }
        // Present mail view controller on screen
        [VC presentViewController:mc animated:YES completion:NULL];
    }else{
        // display error..
        [[[[iToast makeText: NSLocalizedString(@"error_NoEmailAccount", @"Email account is not setup!")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
}

+ (void)PopToMainPanel: (UINavigationController*)navigationController
{
    FunctionView *mainview = nil;
    NSArray *stack = [navigationController viewControllers];
    for(UIViewController *view in stack)
    {
        if([view isMemberOfClass:[FunctionView class]])
        {
            mainview = (FunctionView*)view;
            break;
        }
    }
    
    if(mainview)[navigationController popToViewController:mainview animated:YES];
}

+(BOOL) AddContactEntry: (ABAddressBookRef)aBook TargetRecord:(ABRecordRef)aRecord
{
    CFErrorRef error = NULL;
    BOOL InsertSucess = false;
    ABRecordRef defaultR = ABAddressBookCopyDefaultSource(aBook);
    CFTypeRef sourceType = ABRecordCopyValue(defaultR, kABSourceTypeProperty);
    int STI = [(__bridge NSNumber *)sourceType intValue];
    if(sourceType)CFRelease(sourceType);
    CFRelease(defaultR);
    
    if (STI==kABSourceTypeLocal) {
        InsertSucess = ABAddressBookAddRecord(aBook, aRecord, &error);
    }else{
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
            int STII = [(__bridge NSNumber *)ST intValue];
            CFRelease(ST);
            
            // possible caes, local, mobileMe, iCloud, and suyn with MAC
            if(!((STII==kABSourceTypeExchange)||(STII==kABSourceTypeExchangeGAL)))
            {
                ABRecordRef acopy = ABPersonCreateInSource(currentSource);
                // copy necessary field from aRecord
                if(f) ABRecordSetValue(acopy, kABPersonFirstNameProperty, f, &error);
                if(l) ABRecordSetValue(acopy, kABPersonLastNameProperty, l, &error);
                if(photo) ABPersonSetImageData(acopy, photo, &error);
                if(allIMPP&&ABMultiValueGetCount(allIMPP)>0) ABRecordSetValue(acopy, kABPersonInstantMessageProperty, allIMPP, &error);
                if(allWebpages&&ABMultiValueGetCount(allWebpages)>0)ABRecordSetValue(acopy, kABPersonURLProperty, allWebpages, &error);
                if(allPhones&&ABMultiValueGetCount(allPhones)>0)ABRecordSetValue(acopy, kABPersonPhoneProperty, allPhones, &error);
                if(allAddresses&&ABMultiValueGetCount(allAddresses)>0)ABRecordSetValue(acopy, kABPersonAddressProperty, allAddresses, &error);
                if(allEmails&&ABMultiValueGetCount(allEmails)>0)ABRecordSetValue(acopy, kABPersonEmailProperty, allEmails, &error);
                InsertSucess = ABAddressBookAddRecord(aBook, acopy, &error);
            }
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
    
    return InsertSucess;
}

+(void) RemoveDuplicates:(ABAddressBookRef)aBook AdressList:(CFArrayRef)allPeople CompareArray:(NSMutableDictionary*)compared
{
    CFErrorRef error = NULL;
    // check contact database see if entry is already exist
    for (CFIndex j = 0; j < CFArrayGetCount(allPeople); j++)
    {
        ABRecordRef existing = CFArrayGetValueAtIndex(allPeople, j);
        CFStringRef f = ABRecordCopyValue(existing, kABPersonFirstNameProperty);
        CFStringRef l = ABRecordCopyValue(existing, kABPersonLastNameProperty);
        NSString *existingName = [NSString vcardnstring:(__bridge NSString*)f withLastName:(__bridge NSString*)l];
        
        if(f==NULL&l==NULL)
        {
            continue;
        }
        
        if ([[compared allValues]containsObject:existingName])
        {
            // check IMPP field
            ABMultiValueRef allIMPP = ABRecordCopyValue(existing, kABPersonInstantMessageProperty);
            for (CFIndex i = 0; i < ABMultiValueGetCount(allIMPP); i++)
            {
                CFDictionaryRef anIMPP = ABMultiValueCopyValueAtIndex(allIMPP, i);
                CFStringRef label = CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey);
                if([(__bridge NSString*)label caseInsensitiveCompare:@"SafeSlinger-Push"] == NSOrderedSame)
                {
                    NSString *ctoken = (NSString*)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey);
                    if([compared objectForKey:ctoken])
                    {
                        // remove it
                        if(!ABAddressBookRemoveRecord(aBook, existing, &error))
                        {
                            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"ERROR: Unable to remove the old record. Error = %@", CFErrorCopyDescription(error)]];
                            if(anIMPP)CFRelease(anIMPP);
                            continue;
                        }
                    }
                }
                if(anIMPP)CFRelease(anIMPP);
            }
            if(allIMPP)CFRelease(allIMPP);
        }
        if(f)CFRelease(f);
        if(l)CFRelease(l);
    }// end of for
}

+(NSComparisonResult)CompareDate: (NSString*)basedate Target:(NSString*)targetdate
{
    NSDate *date1, *date2;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat: DATABASE_TIMESTR];
    date1 = [formatter dateFromString: basedate];
    date2 = [formatter dateFromString: targetdate];
    return [date1 compare:date2];
}

+ (void) TriggerContactPermission
{
    // used to trigger contact book access right dialog..
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
    
    });
    if(aBook)CFRelease(aBook);
}

+ (BOOL) checkContactPermission
{
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    if(status==kABAuthorizationStatusAuthorized)
    {
        return YES;
    }else{
        return NO;
    }
}

@end

@implementation NSString (Utility)

+(NSString*) CalculateMemorySize: (int)TotalBytes
{
    if(TotalBytes/1048576>0)
        return [NSString stringWithFormat: NSLocalizedString(@"label_mb", @"%.1f MB"), (float)TotalBytes/1048576.0f];
    else if(TotalBytes/1024>0)
        return [NSString stringWithFormat: NSLocalizedString(@"label_kb", @"%.0f kb"), (float)TotalBytes/1024.0f];
    else
        return [NSString stringWithFormat: NSLocalizedString(@"label_b", @"%.0f b"), (float)TotalBytes];
}

+(NSString*) TranlsateErrorMessage: (NSString*)ErrorStr
{
    if([ErrorStr hasSuffix:@"InvalidRegistration"])
        return NSLocalizedString(@"error_PushMsgNotRegistered", @"That recipient's push token is no longer valid. The recipient may have uninstalled SafeSlinger or turned off notifications. You should stop sending messages to this device.");
    else if([ErrorStr hasSuffix:@"PushServiceFail"])
        return NSLocalizedString(@"error_PushMsgServiceFail", @"Notification service is not available this time. Please try to send the message later.");
    else if([ErrorStr hasSuffix:@"PushNotificationFail"])
        return NSLocalizedString(@"error_PushMsgNotSucceed", @"There is an error communicating with the push notification service.");
    else if([ErrorStr hasSuffix:@"MessageNotFound"])
        return NSLocalizedString(@"error_PushMsgMessageNotFound", @"Message expired.");
    else if([ErrorStr hasSuffix:@"QuotaExceeded"])
        return NSLocalizedString(@"error_PushMsgQuotaExceeded", @"You have exceeded the message quota for this device. Please retry later.");
    else if([ErrorStr hasSuffix:@"DeviceQuotaExceeded"])
        return NSLocalizedString(@"error_PushMsgDeviceQuotaExceeded", @"You have exceeded the message quota for that recipient. Please retry later.");
    else if([ErrorStr hasSuffix:@"NotRegistered"])
        return NSLocalizedString(@"error_PushMsgNotRegistered", @"That recipient's push token is no longer valid. The recipient may have uninstalled SafeSlinger or turned off notifications. You should stop sending messages to this device.");
    else if([ErrorStr hasSuffix:@"MessageTooBig"])
        return NSLocalizedString(@"error_PushMsgMessageTooBig", @"The message is too big. Reduce the size of the message.");
    else if([ErrorStr hasSuffix:@"MissingCollapseKey"])
        return NSLocalizedString(@"error_PushMsgNotSucceed", @"There was an error communicating with the push notification service.");
    else
        return [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessage", @"Server message: '%@'"), ErrorStr];
}

+(NSString*) GetGMTString: (NSString*)format
{
    NSDateFormatter *formatter;
    NSString *GTMdateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    GTMdateString = [formatter stringFromDate:[NSDate date]];
    return GTMdateString;
}

+(NSString*) GetLocalTimeString: (NSString*)format
{
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    dateString = [formatter stringFromDate:[NSDate date]];
    return dateString;
}

+(NSString*) ChangeGMT2Local: (NSString*)gmtdstring GMTFormat:(NSString*)format1 LocalFormat:(NSString*)format2
{
    NSString        *dateString;
    NSDateFormatter *formatter;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format1];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSDate *gmtDate = [formatter dateFromString: gmtdstring];
    [formatter setDateFormat:format2];
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    dateString = [formatter stringFromDate:gmtDate];
    return dateString;
}

+(NSString*) GetTimeLabelString: (NSString*)TStamp
{
    // Display Time
    NSString* result = nil;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setDateFormat: DATABASE_TIMESTR];
    NSDate *cDate = [formatter dateFromString: TStamp];
    
    components = [calendar components:NSDayCalendarUnit
                             fromDate: cDate
                               toDate: [NSDate date]
                              options:0];
    // for efficiency
    if(components.day>0){
        result = [NSString ChangeGMT2Local: TStamp GMTFormat:DATABASE_TIMESTR LocalFormat:@"MMM dd"];
    }else{
        result = [NSString ChangeGMT2Local: TStamp GMTFormat:DATABASE_TIMESTR LocalFormat:@"hh:mm a"];
    }
    return result;
}

+(NSString*) GetFileDateLabelString: (NSString*)TStamp
{
    // Display Time
    NSString* result = nil;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setDateFormat: DATABASE_TIMESTR];
    NSDate *cDate = [formatter dateFromString: TStamp];
    
    NSDate *plus1day = [cDate dateByAddingTimeInterval:60*60*24];
    components = [calendar components:NSHourCalendarUnit|NSMinuteCalendarUnit
                             fromDate:[NSDate date]
                               toDate:plus1day
                              options:0];
    
    // display file expiration time
    if(components.minute>=0&&components.hour>=0)
    {
        result = [NSString stringWithFormat: @"\n(%@: %@ %@)", NSLocalizedString(@"label_expiresIn", @"expires in"),
         [NSString stringWithFormat:NSLocalizedString(@"label_hours", @"%d hrs"), components.hour],
         [NSString stringWithFormat:NSLocalizedString(@"label_minutes", @"%d min"), components.minute]];
    }
    
    return result;
}

-(BOOL) IsValidEmail
{
    BOOL stricterFilter = YES;
    NSString *stricterFilterString = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    NSString *laxString = @".+@([A-Za-z0-9]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:self];
}

-(BOOL) IsValidPhoneNumber
{
    NSCharacterSet *charsToTrim = [NSCharacterSet characterSetWithCharactersInString:@" ()-"];
    NSString *telestr = [[self componentsSeparatedByCharactersInSet:charsToTrim] componentsJoinedByString:@""];
    NSCharacterSet *alphaNums = [NSCharacterSet decimalDigitCharacterSet];
    NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:telestr];
    return [alphaNums isSupersetOfSet:inStringSet];
}

@end

@implementation NSString (NameHandler)

+(NSString*) humanreadable:(NSString*)databasename
{
    NSArray* namearray = [[databasename substringFromIndex:[databasename rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
    return [NSString composite_name:[namearray objectAtIndex:1] withLastName:[namearray objectAtIndex:0]];
}

+(NSString*) composite_name:(NSString*)fname withLastName:(NSString*)lname
{
    if(fname==nil&&lname==nil)
    {
        return nil;
    }else if(fname!=nil&&lname==nil)
    {
        return [NSString stringWithFormat:@"%@", fname];
    }else if(fname==nil&&lname!=nil)
    {
        return [NSString stringWithFormat:@"%@", lname];
    }
    else
    {
        return [NSString stringWithFormat:@"%@ %@", fname, lname];
    }
}

+(NSString*) vcardnstring:(NSString*)fname withLastName:(NSString*)lname
{
    if(lname==nil) return [NSString stringWithFormat:@"N:;%@", fname];
    else if (fname==nil) return [NSString stringWithFormat:@"N:%@;", lname];
    else return [NSString stringWithFormat:@"N:%@;%@", lname, fname];
}
@end

@implementation UIImage (Resize)
- (UIImage*)scaleToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, size.width, size.height), self.CGImage);
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}
@end
