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

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>
#import <MessageUI/MessageUI.h>

@interface UtilityFunc : NSObject

+ (void)SendOpts: (UIViewController<MFMailComposeViewControllerDelegate>*)VC;
+ (void)PopToMainPanel: (UINavigationController*)navigationController;
+ (BOOL) AddContactEntry: (ABAddressBookRef)aBook TargetRecord:(ABRecordRef)aRecord;
+ (void) RemoveDuplicates: (ABAddressBookRef)aBook AdressList:(CFArrayRef)allPeople CompareArray:(NSMutableDictionary*)compared;
+ (NSComparisonResult)CompareDate: (NSString*)basedate Target:(NSString*)targetdate;
+ (void) TriggerContactPermission;
+ (void)playSoundAlert;
+ (void)playVibrationAlert;

@end

@interface NSString (NameHandler)
+ (NSString *)compositeName:(NSString *)fname withLastName:(NSString *)lname;
+ (NSString *)vcardnstring:(NSString *)fname withLastName:(NSString *)lname;
+ (NSString *)humanreadable:(NSString *)databasename;
@end

@interface NSString (Utility)
-(BOOL) IsValidEmail;
-(BOOL) IsValidPhoneNumber;
+(NSString*) CalculateMemorySize: (int)TotalBytes;
+(NSString*) TranlsateErrorMessage: (NSString*)ErrorStr;
+(NSString*) GetGMTString: (NSString*)format;
+(NSString*) GetLocalTimeString: (NSString*)format;
+(NSString*) ChangeGMT2Local: (NSString*)gmtdstring GMTFormat:(NSString*)format1 LocalFormat:(NSString*)format2;
+(NSString*) GetTimeLabelString: (NSString*)TStamp;
+(NSString*) GetFileDateLabelString: (NSString*)TStamp;

@end

@interface UIImage (Resize)
- (UIImage*)scaleToSize:(CGSize)size;
@end
