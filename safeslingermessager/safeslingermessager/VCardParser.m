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

#import "VCardParser.h"

#import "Utility.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "ContactSelectView.h"

#import <UAirship.h>
#import <UAPush.h>
#import <UAAnalytics.h>


@implementation VCardParser

+(NSString*) vCardWithNameOnly: (NSString*)FN LastName:(NSString*)LN
{
	NSMutableString *vCard = [NSMutableString stringWithCapacity:0];
	[vCard appendString: @"BEGIN:VCARD\n"];
	[vCard appendString: @"VERSION:3.0\n"];
#pragma mark FN
	[vCard appendFormat: @"FN:%@\n", [NSString composite_name:FN withLastName:LN]];
#pragma mark N
	[vCard appendString: @"N:"];
    if (LN)[vCard appendString: LN];
    [vCard appendString: @";"];
    if (FN) [vCard appendString: FN];
    [vCard appendString: @"\n"];
#pragma mark PubliKey
    [vCard appendFormat: @"IMPP;SafeSlinger-PubKey:%@\n", [Base64 encode:[SSEngine getPackPubKeys]]];
    NSString* uairship = [UAirship shared].deviceToken;
    NSMutableData *encodeToken = [NSMutableData dataWithLength:0];
    if(uairship)
    {
        int devtype = htonl(iOS);
        int len = htonl([uairship length]);
        [encodeToken appendData:[NSData dataWithBytes: &devtype length: 4]];
        [encodeToken appendData:[NSData dataWithBytes: &len length: 4]];
        [encodeToken appendData:[uairship dataUsingEncoding:NSASCIIStringEncoding]];
    }else{
        // no token available
        int devtype = htonl(DISABLED);
        NSString* str = @"RECEIVED_DISABLED";
        int len = htonl([str lengthOfBytesUsingEncoding:NSASCIIStringEncoding]);
        [encodeToken appendData:[NSData dataWithBytes: &devtype length: 4]];
        [encodeToken appendData:[NSData dataWithBytes: &len length: 4]];
        [encodeToken appendData:[str dataUsingEncoding:NSASCIIStringEncoding]];
    }
    [vCard appendFormat: @"IMPP;SafeSlinger-Push:%@\n", [Base64 encode:encodeToken]];
    
#pragma mark EndofVCard
	[vCard appendString: @"END:VCARD"];
	return vCard;
}

+(NSData*) GetSimpleVCard: (ContactEntry*)contact RawPubkey: (NSString*)Pubkey
{
    NSMutableString *vCard = [[NSMutableString alloc] init];
	[vCard appendString: @"BEGIN:VCARD\n"];
	[vCard appendString: @"VERSION:3.0\n"];
    [vCard appendString: [NSString vcardnstring:contact.fname withLastName:contact.lname]];
    [vCard appendString: @"\n"];
    
    if(contact.photo) [vCard appendFormat: @"PHOTO;TYPE=JPEG;ENCODING=b:%@\n",[Base64 encode:contact.photo]];
    
    NSString* Base64Enckey = [Base64 encode:[[NSString stringWithFormat:@"%@\n%@\n%@", contact.keyid, contact.keygenDate, Pubkey] dataUsingEncoding:NSASCIIStringEncoding]];
    [vCard appendFormat: @"IMPP;SafeSlinger-PubKey:%@\n", Base64Enckey];
    
    // push token format: Base64EncodeByteArray(type | lentok | token)
    NSMutableData *encToken = [NSMutableData dataWithLength:0];
    int devtype = htonl(contact.devType);
    int len = htonl([contact.pushtoken length]);
    [encToken appendData:[NSData dataWithBytes: &devtype length: 4]];
    [encToken appendData:[NSData dataWithBytes: &len length: 4]];
    [encToken appendData:[contact.pushtoken dataUsingEncoding:NSASCIIStringEncoding]];
    
    NSString* Base64Enctoken = [Base64 encode: encToken];
    [vCard appendFormat: @"IMPP;SafeSlinger-Push:%@\n", Base64Enctoken];
	[vCard appendString: @"END:VCARD"];
    
	return [vCard dataUsingEncoding:NSUTF8StringEncoding];
}

+(NSString *) vCardFromContact: (ABRecordRef)record labels: (NSArray *)labels values:(NSArray *)values selections: (NSArray *)selections category: (NSArray *)category
{
	NSMutableString *vCard = [NSMutableString stringWithCapacity:0];
	[vCard appendString: @"BEGIN:VCARD\n"];
	[vCard appendString: @"VERSION:3.0\n"];
	
#pragma mark FN
	CFStringRef compositeName = ABRecordCopyCompositeName(record);
	if (!compositeName)
	{
		[vCard appendFormat: @"FN:%@\n", compositeName];
		CFRelease(compositeName);
	}
#pragma mark N
	CFStringRef lastName, firstName, middleName, prefix, suffix;
	lastName = ABRecordCopyValue(record, kABPersonLastNameProperty);
	firstName = ABRecordCopyValue(record, kABPersonFirstNameProperty);
	middleName = ABRecordCopyValue(record, kABPersonMiddleNameProperty);
	prefix = ABRecordCopyValue(record, kABPersonPrefixProperty);
	suffix = ABRecordCopyValue(record, kABPersonSuffixProperty);
	if (lastName != NULL || firstName != NULL)
	{
		[vCard appendString: @"N:"];
		if (lastName != NULL)
		{
			[vCard appendString: (__bridge NSString *)lastName];
			CFRelease(lastName);
		}
		[vCard appendString: @";"];
		if (firstName != NULL)
		{
			[vCard appendString: (__bridge NSString *)firstName];
			CFRelease(firstName);
		}
		if (middleName != NULL)
		{
			[vCard appendFormat: @";%@", (__bridge NSString *)middleName];
			CFRelease(middleName);
		}
		if (prefix != NULL)
		{
			[vCard appendFormat: @";%@", (__bridge NSString *)prefix];
			CFRelease(prefix);
		}
		if (suffix != NULL)
		{
			[vCard appendFormat: @";%@", (__bridge NSString *)suffix];
			CFRelease(suffix);
		}
		[vCard appendString: @"\n"];
	}
	else
	{
        // name fields are required
		return nil;
	}
    
	for (int i = 0; i < [labels count]; i++)
	{
		if ([(NSNumber*)[selections objectAtIndex:i]boolValue]==NO)
        {
            continue;
        }
		
		NSString *currentLabel = [labels objectAtIndex: i];
        NSNumber *currentClass = [category objectAtIndex: i];
		NSString *currentValue = [[values objectAtIndex: i] stringByReplacingOccurrencesOfString: @"," withString: @"\\,"];
        
        //category, 0 for Photo, 1 for emails, 2 for urls, 3 for phone numbers, 4 for addresses
        switch (currentClass.intValue)
        {
#pragma mark PHOTO
            case Photo:
                [vCard appendFormat: @"PHOTO;TYPE=JPEG;ENCODING=b:%@\n", currentValue];
                break;
#pragma mark EMAIL
            case Email:
                [vCard appendFormat: @"EMAIL;TYPE=%@:%@\n", [currentLabel uppercaseString], currentValue];
                break;
#pragma mark URL
            case Url:
                [vCard appendFormat: @"URL;TYPE=%@:%@\n", [currentLabel uppercaseString], currentValue];
                break;
#pragma mark TEL
            case PhoneNum:
                if ([currentLabel isEqualToString: @"iPhone"])
                    [vCard appendFormat: @"TEL;TYPE=CELL,IPHONE:%@\n", currentValue];
                else if([currentLabel hasSuffix: @"FAX"])
                {
                    NSString* type = [currentLabel stringByReplacingOccurrencesOfString:@"FAX" withString:@""];
                    [vCard appendFormat: @"TEL;TYPE=%@,FAX:%@\n", [type uppercaseString], currentValue];
                    
                }else{
                    [vCard appendFormat: @"TEL;TYPE=%@:%@\n", [currentLabel uppercaseString], currentValue];
                }
                break;
#pragma mark ADR
            case Address:
                [vCard appendFormat: @"ADR;TYPE=%@:;;%@\n", [currentLabel uppercaseString], currentValue];
                break;
            default:
                break;
        }
    }// end of for
    
#pragma mark PubliKey
    [vCard appendFormat: @"IMPP;SafeSlinger-PubKey:%@\n", [Base64 encode:[SSEngine getPackPubKeys]]];
    NSString* uairship = [UAirship shared].deviceToken;
    NSMutableData *encodeToken = [NSMutableData dataWithLength:0];
    if(uairship)
    {
        int devtype = htonl(iOS);
        int len = htonl([uairship length]);
        [encodeToken appendData:[NSData dataWithBytes: &devtype length: 4]];
        [encodeToken appendData:[NSData dataWithBytes: &len length: 4]];
        [encodeToken appendData:[uairship dataUsingEncoding:NSASCIIStringEncoding]];
    }else{
        // no token available
        int devtype = htonl(DISABLED);
        NSString* str = @"RECEIVED_DISABLED";
        int len = htonl([str lengthOfBytesUsingEncoding:NSASCIIStringEncoding]);
        [encodeToken appendData:[NSData dataWithBytes: &devtype length: 4]];
        [encodeToken appendData:[NSData dataWithBytes: &len length: 4]];
        [encodeToken appendData:[str dataUsingEncoding:NSASCIIStringEncoding]];
    }
    [vCard appendFormat: @"IMPP;SafeSlinger-Push:%@\n", [Base64 encode:encodeToken]];
    
#pragma mark EndofVCard
	[vCard appendString: @"END:VCARD"];
	return vCard;
}


+(ABRecordRef) vCardToContact: (NSString *)vCard
{
	ABRecordRef aRecord = ABPersonCreate();
    ABMutableMultiValueRef allPhones = ABMultiValueCreateMutable(kABMultiStringPropertyType);
	ABMutableMultiValueRef allEmails = ABMultiValueCreateMutable(kABMultiStringPropertyType);
	ABMutableMultiValueRef allAddresses = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    ABMutableMultiValueRef allWebpages = ABMultiValueCreateMutable(kABMultiStringPropertyType);
	ABMutableMultiValueRef allIMPP = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    
	CFErrorRef error;
	NSString *previousItem = nil;
	NSMutableString *imageString = [[NSMutableString alloc] init];
	NSArray *allLines = [vCard componentsSeparatedByString: @"\n"];
	
	for (NSString *line in allLines)
	{
		if ([line length] == 0)
			continue;
		
		BOOL hasMain = NO, isFax = NO, isPager = NO, isHome = NO, isWork = NO;
		NSMutableArray *tokens = [[line componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @":;"]] mutableCopy];
		NSMutableString *item = [NSMutableString stringWithString: [tokens objectAtIndex: 0]];
		[tokens removeObjectAtIndex: 0];

#pragma mark PHOTO (finish up)
		if (([tokens count] > 0) &&([previousItem isEqualToString: @"PHOTO"]))
		{
            if ([imageString length]==0)
			{
                [tokens removeAllObjects];
				continue;
			}else{
                NSData *decodedPhoto = [Base64 decode: imageString];
                if(decodedPhoto!=nil) {
                    ABPersonSetImageData(aRecord, (__bridge CFDataRef)decodedPhoto, &error);
                }
            }
		}
        
		if ([tokens count] == 0)
		{
			if ([previousItem isEqualToString: @"PHOTO"])
			{
				[item replaceOccurrencesOfString: @" " withString: @"" options: NSLiteralSearch range: NSMakeRange(0, [item length])];
				[imageString appendString: item];
			}
            [tokens removeAllObjects];
			continue;
		}
#pragma mark ADR
		else if ([item caseInsensitiveCompare: @"ADR"] == NSOrderedSame)
		{
            // Default: All fields are empty
            // street, city, state, zip, country
            NSMutableArray *addrInfo = [NSMutableArray arrayWithObjects: 
                                        (id)kABPersonAddressStreetKey, 
                                        (id)kABPersonAddressCityKey,
                                        (id)kABPersonAddressStateKey,
                                        (id)kABPersonAddressZIPKey,
                                        (id)kABPersonAddressCountryKey,
                                        nil];
            
			CFStringRef typeString = kABOtherLabel;
			int min = [[tokens objectAtIndex: 0] length] > 4 ? 4 : (int)[[tokens objectAtIndex: 0] length];
			while ([[[tokens objectAtIndex: 0] substringToIndex: min] caseInsensitiveCompare: @"TYPE"] == NSOrderedSame)
			{
				NSString *typeList = [[tokens objectAtIndex: 0] substringFromIndex: 5];
				[tokens removeObjectAtIndex: 0];
				NSArray *types = [typeList componentsSeparatedByString: @","];
				for (int i = 0; i < [types count]; i++)
				{
					NSString *currentType = [[types objectAtIndex: i] uppercaseString];
					if ([currentType isEqualToString: @"HOME"])
					{
						typeString = kABHomeLabel;
					}
					else if ([currentType isEqualToString: @"WORK"])
					{
						typeString = kABWorkLabel;
					}
				}
				min = [[tokens objectAtIndex: 0] length] > 4 ? 4 : (int)[[tokens objectAtIndex: 0] length];
			}
            
			CFMutableDictionaryRef address = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            
			// No need to add since all information are empty
            if ([tokens count] < 2) {
                [tokens removeAllObjects];
                continue;
            }
            
			//Skip ahead to street number as PO box and extended address aren't used by Contacts
			[tokens removeObjectAtIndex: 0];
            [tokens removeObjectAtIndex: 0];
			
            // No more information, skip to add it
			if ([tokens count] == 0) {
                continue;
            }
            
            int ItemIdx = 0;
            while ([tokens lastObject]!=nil) {
                // add information one by one
                NSString* add = [tokens objectAtIndex: 0];
                add = [add stringByReplacingOccurrencesOfString:@"\\n" withString:@" "];
                CFDictionarySetValue(address, (const CFStringRef)[addrInfo objectAtIndex:ItemIdx], (__bridge const void *)(add));
                [tokens removeObjectAtIndex: 0];
                ItemIdx++;
            }
            
            while(ItemIdx<5)
            {
                // User May not fill all fields, use "" instead
                CFDictionarySetValue(address, (const CFStringRef)[addrInfo objectAtIndex:ItemIdx], @"");
                ItemIdx++;
            }
            
			ABMultiValueAddValueAndLabel(allAddresses, address, typeString, nil);
			CFRelease(address);
		}
#pragma mark EMAIL
		else if ([item caseInsensitiveCompare: @"EMAIL"] == NSOrderedSame)
		{
			CFStringRef typeString = kABOtherLabel;
			int min = [[tokens objectAtIndex: 0] length] > 4 ? 4 : (int)[[tokens objectAtIndex: 0] length];
            
			while ([[[tokens objectAtIndex: 0] substringToIndex: min] caseInsensitiveCompare: @"TYPE"] == NSOrderedSame)
			{
				NSString *typeList = [[tokens objectAtIndex: 0] substringFromIndex: 5];
				[tokens removeObjectAtIndex: 0];
				NSArray *types = [typeList componentsSeparatedByString: @","];
				for (int i = 0; i < [types count]; i++)
				{
					NSString *currentType = [[types objectAtIndex: i] uppercaseString];
					if ([currentType isEqualToString: @"HOME"])
					{
						typeString = kABHomeLabel;
					}
					else if ([currentType isEqualToString: @"WORK"])
					{
						typeString = kABWorkLabel;
					}
				}
				min = [[tokens objectAtIndex: 0] length] > 4 ? 4 : (int)[[tokens objectAtIndex: 0] length];
			}
            
			if ([tokens count] == 0) {
                continue;
            }
            
			ABMultiValueAddValueAndLabel(allEmails, (__bridge CFTypeRef)([tokens objectAtIndex: 0]), typeString, nil);
		}
#pragma mark IMPP
		else if ([item caseInsensitiveCompare: @"IMPP"] == NSOrderedSame)
		{
            
            // now we only accept IMPP from SAFESLINGER fields
            if ([tokens count] < 2)
			{
                [tokens removeAllObjects];
				continue;
			}
            
            if([((NSString*)[tokens objectAtIndex:0])caseInsensitiveCompare:@"SafeSlinger-PubKey"]||[((NSString*)[tokens objectAtIndex:0])caseInsensitiveCompare:@"SafeSlinger-Push"])
            {
                CFStringRef typeString = kABOtherLabel;
                CFMutableDictionaryRef impp = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                CFDictionarySetValue(impp, kABPersonInstantMessageServiceKey, (CFStringRef)[[tokens objectAtIndex: 0] uppercaseString]);
                CFDictionarySetValue(impp, kABPersonInstantMessageUsernameKey, (CFStringRef)[tokens objectAtIndex: 1]);
                ABMultiValueAddValueAndLabel(allIMPP, impp, typeString, nil);
                [tokens removeAllObjects];
            }
		}
#pragma mark N
		else if ([item caseInsensitiveCompare: @"N"] == NSOrderedSame)
		{
			NSString *lastName = [tokens objectAtIndex: 0];
			[tokens removeObjectAtIndex: 0];
			if (lastName != nil && [lastName length] > 0)
			{
				ABRecordSetValue(aRecord, kABPersonLastNameProperty, (__bridge CFStringRef)lastName, &error);
			}
			if ([tokens count] == 0) continue;
			
			NSString *firstName = [tokens objectAtIndex: 0];
			[tokens removeObjectAtIndex: 0];
			if (firstName != nil && [firstName length] > 0)
			{
				ABRecordSetValue(aRecord, kABPersonFirstNameProperty, (__bridge CFStringRef)firstName, &error);
			}
			if ([tokens count] == 0) {
                continue;
            }
			
			NSArray *additionalNames = [[tokens objectAtIndex: 0] componentsSeparatedByString: @","];
			[tokens removeObjectAtIndex: 0];
			NSMutableString *middleNameString = [[NSMutableString alloc] init];
			[middleNameString appendString: [additionalNames objectAtIndex: 0]];
			for (int i = 1; i < [additionalNames count]; i++)
			{
				[middleNameString appendFormat: @" %@", [additionalNames objectAtIndex: i]];
			}
			if ([middleNameString length] > 0)
			{
				ABRecordSetValue(aRecord, kABPersonMiddleNameProperty, 
								 (__bridge CFStringRef)[middleNameString stringByReplacingOccurrencesOfString: @"\\" withString: @""], &error);
			}
			
			if ([tokens count] == 0){
                continue;
            }
				
			
			NSArray *prefixes = [[tokens objectAtIndex: 0] componentsSeparatedByString: @","];
			[tokens removeObjectAtIndex: 0];
			NSMutableString *prefixString = [[NSMutableString alloc] init];
			[prefixString appendString: [prefixes objectAtIndex: 0]];
			for (int i = 1; i < [prefixes count]; i++)
			{
				[prefixString appendFormat: @" %@", [prefixes objectAtIndex: i]];
			}
			if ([prefixString length] > 0)
			{
				ABRecordSetValue(aRecord, kABPersonPrefixProperty, 
								 (__bridge CFStringRef)[prefixString stringByReplacingOccurrencesOfString: @"\\" withString: @""], &error);
			}
			
			if ([tokens count] == 0)
            {
                continue;
            }
            
			NSArray *suffixes = [[tokens objectAtIndex: 0] componentsSeparatedByString: @","];
			[tokens removeObjectAtIndex: 0];
			NSMutableString *suffixString = [[NSMutableString alloc] init];
			[suffixString appendString: [suffixes objectAtIndex: 0]];
			for (int i = 1; i < [suffixes count]; i++)
			{
				[suffixString appendFormat: @" %@", [suffixes objectAtIndex: 0]];
			}
			if ([suffixString length] > 0)
			{
				ABRecordSetValue(aRecord, kABPersonSuffixProperty, 
								 (__bridge CFStringRef)[suffixString stringByReplacingOccurrencesOfString: @"\\" withString: @""], &error);
			}
		}
#pragma mark PHOTO
		else if ([item caseInsensitiveCompare: @"PHOTO"] == NSOrderedSame)
		{
			while ([tokens count] > 1)
			{
				//Assume base64 for now
				[tokens removeObjectAtIndex: 0];
			}
            // set image if possible
			[imageString appendString: [tokens objectAtIndex: 0]];
		}
#pragma mark TEL
		else if ([item caseInsensitiveCompare: @"TEL"] == NSOrderedSame)
		{
			CFStringRef typeString = kABOtherLabel;
			while ([[[tokens objectAtIndex: 0] substringToIndex: 4] caseInsensitiveCompare: @"TYPE"] == NSOrderedSame)
			{
				NSString *typeList = [[tokens objectAtIndex: 0] substringFromIndex: 5];
				[tokens removeObjectAtIndex: 0];
				NSArray *types = [typeList componentsSeparatedByString: @","];
				BOOL iPhone = NO;
                
				for (int i = 0; i < [types count]; i++)
				{
					NSString *currentType = [[types objectAtIndex: i] uppercaseString];
					if ([currentType isEqualToString: @"HOME"] && !hasMain)
					{
						isHome = YES;
						if (!isFax)
							typeString = kABHomeLabel;
						else if (isPager)
							typeString = kABPersonPhonePagerLabel;
						else
							typeString = kABPersonPhoneHomeFAXLabel;
						
					}
					else if ([currentType isEqualToString: @"WORK"] && !hasMain)
					{
						isWork = YES;
						if (!isFax)
							typeString = kABWorkLabel;
						else if (isPager)
							typeString = kABPersonPhonePagerLabel;
						else
							typeString = kABPersonPhoneWorkFAXLabel;
						
					}
                    else if ([currentType isEqualToString: @"MOBILE"] && !hasMain)
					{
						typeString = kABPersonPhoneMobileLabel;
					}
					else if ([currentType isEqualToString: @"IPHONE"] && !hasMain)
					{

						typeString = kABPersonPhoneIPhoneLabel;
						iPhone = YES;
					}
					else if ([currentType isEqualToString: @"PREF"])
					{
						hasMain = YES;
						if (!isFax && !isPager && !iPhone)
							typeString = kABPersonPhoneMainLabel;
					}
					else if ([currentType isEqualToString: @"FAX"])
					{
						isFax = YES;
						if (isHome)
							typeString = kABPersonPhoneHomeFAXLabel;
						else if (isWork)
							typeString = kABPersonPhoneWorkFAXLabel;
					}
					else if ([currentType isEqualToString: @"PAGER"])
					{
						isPager = YES;
						typeString = kABPersonPhonePagerLabel;
					}
				}
			}
			ABMultiValueAddValueAndLabel(allPhones, (__bridge CFStringRef)[tokens objectAtIndex: 0], (CFStringRef)typeString, nil);
		}
#pragma mark VERSION
		else if ([item caseInsensitiveCompare: @"VERSION"] == NSOrderedSame)
		{
			if (![[tokens objectAtIndex: 0] isEqualToString: @"3.0"])
			{
                [ErrorLogger ERRORDEBUG: @"ERROR: VCard Version Error."];
				CFRelease(aRecord);
				return nil;
			}
		}
#pragma mark URL //@"URL;TYPE=%@:%@\n"
		else if ([item caseInsensitiveCompare: @"URL"] == NSOrderedSame)
		{
            if ([tokens count] > 1)
            {
                CFStringRef typeString = kABOtherLabel;
                if ([tokens count] == 2)
                {
                    if ([[tokens objectAtIndex: 0]hasPrefix:@"TYPE"] == NSOrderedSame)
                    {
                        NSString *currentType = [[tokens objectAtIndex: 1] uppercaseString];
                        if ([currentType hasSuffix: @"HOMEPAGE"])
                        {
                            typeString = kABHomeLabel;
                        }
                        else if ([currentType hasSuffix: @"HOME"])
                        {
                            typeString = kABWorkLabel;
                        }
                        else if ([currentType hasSuffix: @"WORK"])
                        {
                            typeString = kABWorkLabel;
                        }
                        else if ([currentType hasSuffix: @"OTHER"])
                        {
                            typeString = kABOtherLabel;
                        }
                    }
                }
                ABMultiValueAddValueAndLabel(allWebpages, (__bridge CFTypeRef)([tokens objectAtIndex: [tokens count]-1]), typeString, nil);
            }
		}
		previousItem = item;
        if([tokens count]>0)[tokens removeAllObjects];
        tokens = nil;
	}
    
    ABRecordSetValue(aRecord, kABPersonURLProperty, allWebpages, &error);
	ABRecordSetValue(aRecord, kABPersonPhoneProperty, allPhones, &error);
	ABRecordSetValue(aRecord, kABPersonEmailProperty, allEmails, &error);
	ABRecordSetValue(aRecord, kABPersonAddressProperty, allAddresses, &error);
	ABRecordSetValue(aRecord, kABPersonInstantMessageProperty, allIMPP, &error);
    if(allWebpages!=NULL)CFRelease(allWebpages);
	if(allAddresses!=NULL)CFRelease(allAddresses);
	if(allPhones!=NULL)CFRelease(allPhones);
	if(allEmails!=NULL)CFRelease(allEmails);
	if(allIMPP!=NULL)CFRelease(allIMPP);
	return aRecord;
}

@end
