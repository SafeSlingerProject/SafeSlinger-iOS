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

#import <AddressBook/AddressBook.h>
#import "InvitationView.h"
#import "Utility.h"
#import "ErrorLogger.h"
#import "SafeSlingerDB.h"
#import "AppDelegate.h"
#import "BackupCloud.h"

@interface InvitationView ()

@end

@implementation InvitationView

@synthesize InviteeLabel, InviterLabel, MeLabel;
@synthesize InviteeFacel, InviterFace, MyFace;
@synthesize AcceptBtn;
@synthesize InviteeVCard, InviterFaceImg, InviterName;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // show dialog
    [MeLabel setText:NSLocalizedString(@"label_Me", @"Me")];
    [AcceptBtn setTitle:NSLocalizedString(@"btn_Accept", @"Accept") forState: UIControlStateNormal];
    self.navigationItem.title = NSLocalizedString(@"title_SecureIntroductionInvite", @"Secure Introduction Invitation!");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Invitee
    NSString *InviteeName = [NSString compositeName: (__bridge NSString *)(ABRecordCopyValue(InviteeVCard, kABPersonFirstNameProperty)) withLastName:(__bridge NSString *)(ABRecordCopyValue(InviteeVCard, kABPersonLastNameProperty))];
    
    if(!InviteeName) {
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }
    
    [InviteeLabel setText:InviteeName];
    
    // Inviter
    [InviterLabel setText: [NSString stringWithFormat:@"%@\n%@",
                            NSLocalizedString(@"label_safeslingered", @"(SafeSlinger Direct Exchange)"),
                            InviterName]];
    
    [InviterFace setImage:InviterFaceImg];
    
    if(ABPersonHasImageData(InviteeVCard)) {
        // use Thumbnail image
        [InviteeFacel setImage:[UIImage imageWithData:(__bridge NSData *)ABPersonCopyImageDataWithFormat(InviteeVCard, kABPersonImageFormatThumbnail)]];
    } else {
        [InviteeFacel setImage:[UIImage imageNamed: @"blank_contact.png"]];
    }
}

- (IBAction)BeginImport:(id)sender {
    if(InviteeVCard) {
        int result = [self AddNewContact:InviteeVCard];
        if(result>=0) {
            if(result>0) {
                AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
                // Try to backup
                [delegate.BackupSys RecheckCapability];
                [delegate.BackupSys PerformBackup];
            }
            
            // show dialog
            [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_SomeContactsImported", @"%@ contacts imported."), [NSString stringWithFormat:@"%d", result]]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
        InviteeVCard = NULL;
    } else {
        // Record is null
        [ErrorLogger ERRORDEBUG: @"ERROR: The record is a null object."];
        [[[[iToast makeText: NSLocalizedString(@"error_VcardParseFailure", @"vCard parse failed.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
    [self performSegueWithIdentifier:@"FinishInvitation" sender:self];
}

/*
 Return value error or WrongFormat(-1), failOverwrite(0), success(1)
 */
- (int)AddNewContact:(ABRecordRef)newRecord {
	ContactEntry *contact = [ContactEntry new];
    NSData *keyelement = nil;
    NSData *token = nil;
	NSString *comparedtoken = nil;
	
	contact.firstName = (__bridge_transfer NSString *)ABRecordCopyValue(newRecord, kABPersonFirstNameProperty);
	contact.lastName = (__bridge_transfer NSString *)ABRecordCopyValue(newRecord, kABPersonLastNameProperty);
    
    // Get SafeSlinger Fields
    ABMultiValueRef allIMPP = ABRecordCopyValue(newRecord, kABPersonInstantMessageProperty);
    for (CFIndex i = 0; i < ABMultiValueGetCount(allIMPP); i++) {
        CFDictionaryRef anIMPP = ABMultiValueCopyValueAtIndex(allIMPP, i);
        if ([(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey) caseInsensitiveCompare:@"SafeSlinger-PubKey"] == NSOrderedSame) {
            keyelement = [Base64 decode:(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey)];
            keyelement = [NSData dataWithBytes:[keyelement bytes] length:[keyelement length]];
        } else if([(NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageServiceKey) caseInsensitiveCompare:@"SafeSlinger-Push"] == NSOrderedSame) {
            comparedtoken = (NSString *)CFDictionaryGetValue(anIMPP, kABPersonInstantMessageUsernameKey);
            token = [Base64 decode:comparedtoken];
        }
        if(anIMPP)CFRelease(anIMPP);
    }
	
    if(allIMPP)CFRelease(allIMPP);
    
    if([keyelement length]==0) {
        [[[[iToast makeText: NSLocalizedString(@"error_AllMembersMustUpgradeBadKeyFormat", @"All members must upgrade, some are using older key formats.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return -1;
    }
    
    if([token length]==0) {
        [[[[iToast makeText: NSLocalizedString(@"error_AllMembersMustUpgradeBadPushToken", @"All members must upgrade, some are using older push token formats.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return -1;
    }
	
	[contact setKeyInfo:keyelement];
	
    int offset = 0, tokenlen = 0;
    const char* p = [token bytes];
    
    contact.devType = ntohl(*(int *)(p+offset));
    offset += 4;
    
    tokenlen = ntohl(*(int *)(p+offset));
    offset += 4;
	
    contact.pushToken = [[NSString stringWithCString:[[NSData dataWithBytes:p+offset length:tokenlen]bytes] encoding:NSASCIIStringEncoding] substringToIndex:tokenlen];
    
    // get photo if possible
    if(ABPersonHasImageData(newRecord)) {
		CFDataRef photo = ABPersonCopyImageDataWithFormat(newRecord, kABPersonImageFormatThumbnail);
		contact.photo = UIImageJPEGRepresentation([UIImage imageWithData:(__bridge NSData *)photo], 0.9);
        CFRelease(photo);
    }
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
    
    // introduction
    NSString* rawdata = [NSString stringWithCString:[keyelement bytes] encoding:NSASCIIStringEncoding];
    rawdata = [rawdata substringToIndex:[keyelement length]];
    
    NSArray* keyarray = [rawdata componentsSeparatedByString:@"\n"];
    if([keyarray count]!=3) {
        [ErrorLogger ERRORDEBUG: (@"ERROR: Exchange public key is not well-formated!")];
        return -1;
    }
    
    contact.exchangeType = [delegate.DbInstance GetExchangeType: [keyarray objectAtIndex:0]];
    if(contact.exchangeType == Exchanged) {
        // do not overwirte it
        [ErrorLogger ERRORDEBUG: @"ERROR: Already Exchanged Before, Do Not Overwrite."];
        return 0;
    }
	
	contact.exchangeType = Introduced;
    
    // update token
	if(!contact.pushToken) {
		[ErrorLogger ERRORDEBUG: @"ERROR: recipient's token is missing."];
		return -1;
	}
	
	[mapping setObject:[NSString vcardnstring:contact.firstName withLastName:contact.lastName] forKey:comparedtoken];
	
    if(ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
        // contact permission is enabled, update address book.
        CFErrorRef error = NULL;
        ABAddressBookRef aBook = NULL;
        aBook = ABAddressBookCreateWithOptions(NULL, &error);
        ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
            if (!granted) {
            }
        });
        
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
        // remove old duplicates
        [UtilityFunc RemoveDuplicates:aBook AdressList:allPeople CompareArray:mapping];
        // add one by one
        [UtilityFunc AddContactEntry:aBook TargetRecord:newRecord];
        
		if(!ABAddressBookSave(aBook, &error)) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"ERROR: Unable to Save ABAddressBook. Error = %@", CFErrorCopyDescription(error)]];
        }
        
        if(allPeople)CFRelease(allPeople);
        if(aBook)CFRelease(aBook);
	}
	
	contact.recordId = ABRecordGetRecordID(newRecord);
	
	// update or insert entry for new recipient
	if(![delegate.DbInstance addNewRecipient:contact]) {
		[[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateRecipientInDB", @"Unable to update the recipient database.")]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
		return -1;
	}
	
    return 1;
}

@end
