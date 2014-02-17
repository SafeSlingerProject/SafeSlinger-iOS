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

@implementation NSString (CustomComparator)

-(NSComparisonResult) compareUID: (id) obj
{
	NSString *s = (NSString *)obj;
	int i1 = [self intValue];
	int i2 = [s intValue];
	if (!i1 || !i2 || i1 == INT_MAX || i2 == INT_MAX || i1 == INT_MIN || i2 == INT_MIN)
		return [self compare: s];
	
	if (i1 < i2)
		return NSOrderedAscending;
	if (i1 > i2)
		return NSOrderedDescending;
	return NSOrderedSame;
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
    [formatter setTimeZone:[NSTimeZone localTimeZone]];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    GTMdateString = [formatter stringFromDate:[NSDate date]];
    [formatter release];
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
    [formatter release];
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
    [formatter release];
    return dateString;
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
