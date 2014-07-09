//
//  InvitationView.m
//  safeslingermessager
//
//  Created by Yueh-Hsun Lin on 6/30/14.
//  Copyright (c) 2014 CyLab. All rights reserved.
//

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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // show dialog
    [MeLabel setText:NSLocalizedString(@"label_Me", @"Me")];
    [AcceptBtn setTitle:NSLocalizedString(@"btn_Accept", @"Accept") forState: UIControlStateNormal];
    self.navigationItem.title = NSLocalizedString(@"title_SecureIntroductionInvite", @"Secure Introduction Invitation!");
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Invitee
    NSString *InviteeName = [NSString composite_name: (__bridge NSString *)(ABRecordCopyValue(InviteeVCard, kABPersonFirstNameProperty)) withLastName:(__bridge NSString *)(ABRecordCopyValue(InviteeVCard, kABPersonLastNameProperty))];
    
    if(!InviteeName)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_InvalidContactName", @"A valid Contact Name is required.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationShort] show];
    }
    
    [InviteeLabel setText:InviteeName];
    
    // Inviter
    [InviterLabel setText: [NSString stringWithFormat:@"%@\n%@",
                            NSLocalizedString(@"label_safeslingered", @"(SafeSlinger Direct Exchange)"),
                            InviterName]];
    
    [InviterFace setImage:InviterFaceImg];
    
    if(ABPersonHasImageData(InviteeVCard))
    {
        // use Thumbnail image
        [InviteeFacel setImage:[[UIImage imageWithData:(__bridge NSData *)ABPersonCopyImageDataWithFormat(InviteeVCard, kABPersonImageFormatThumbnail)]scaleToSize:CGSizeMake(45.0f, 45.0f)]];
    }else{
        [InviteeFacel setImage:[UIImage imageNamed: @"blank_contact.png"]];
    }
}

-(IBAction) BeginImport: (id)sender
{
    if(InviteeVCard)
    {
        int result = [self AddNewContact:InviteeVCard];
        if(result>=0)
        {
            if(result>0)
            {
                AppDelegate *delegate = [[UIApplication sharedApplication]delegate];
                // Try to backup
                [delegate.BackupSys RecheckCapability];
                [delegate.BackupSys PerformBackup];
            }
            
            // show dialog
            [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"state_SomeContactsImported", @"%@ contacts imported."), [NSString stringWithFormat:@"%d", result]]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
        InviteeVCard = NULL;
    }else{
        // Record is null
        [ErrorLogger ERRORDEBUG: @"ERROR: The record is a null object."];
        [[[[iToast makeText: NSLocalizedString(@"error_VcardParseFailure", @"vCard parse failed.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    }
    
    [self performSegueWithIdentifier:@"FinishInvitation" sender:self];
}

/*
 Return value error or WrongFormat(-1), failOverwrite(0), success(1)
 */
- (int)AddNewContact: (ABRecordRef)newRecord
{
    NSString* comparedtoken = nil;
    NSData *keyelement = nil;
    NSData *token = nil;
    NSString* imageData = nil;
    int ex_type = -1;
    
    NSString* username = [NSString vcardnstring:(__bridge NSString *)(ABRecordCopyValue(newRecord, kABPersonFirstNameProperty)) withLastName:(__bridge NSString *)(ABRecordCopyValue(newRecord, kABPersonLastNameProperty))];
    
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
        if(anIMPP)CFRelease(anIMPP);
    }
    if(allIMPP)CFRelease(allIMPP);
    
    if([keyelement length]==0)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_AllMembersMustUpgradeBadKeyFormat", @"All members must upgrade, some are using older key formats.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return -1;
    }
    
    if([token length]==0) {
        [[[[iToast makeText: NSLocalizedString(@"error_AllMembersMustUpgradeBadPushToken", @"All members must upgrade, some are using older push token formats.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return -1;
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
    CFDataRef photo = ABPersonCopyImageData(newRecord);
    if(photo)
    {
        imageData = [Base64 encode: UIImageJPEGRepresentation([UIImage imageWithData:(__bridge NSData *)photo], 0.3)];
        CFRelease(photo);
    }
    
    AppDelegate *delegate = [[UIApplication sharedApplication]delegate];
    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
    
    // introduction
    NSString* rawdata = [NSString stringWithCString:[keyelement bytes] encoding:NSASCIIStringEncoding];
    rawdata = [rawdata substringToIndex:[keyelement length]];
    
    NSArray* keyarray = [rawdata componentsSeparatedByString:@"\n"];
    if([keyarray count]!=3) {
        [ErrorLogger ERRORDEBUG: (@"ERROR: Exchange public key is not well-formated!")];
        return -1;
    }
    
    ex_type = [delegate.DbInstance GetExchangeType: [keyarray objectAtIndex:0]];
    if(ex_type==Exchanged)
    {
        // do not overwirte it
        [ErrorLogger ERRORDEBUG: @"ERROR: Already Exchanged Before, Do Not Overwrite."];
        return 0;
    }
    
    // update token
    if(tokenstr)
    {
        // update or insert entry for new recipient
        if(![delegate.DbInstance AddNewRecipient:keyelement User:username Dev:devtype Photo:imageData Token:tokenstr ExchangeOrIntroduction:NO])
        {
            
            [[[[iToast makeText: NSLocalizedString(@"error_UnableToUpdateRecipientInDB", @"Unable to update the recipient database.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            return -1;
        }
        [mapping setObject:username forKey:comparedtoken];
    }else{
        DEBUGMSG(@"recipient's token is missing.");
        return -1;
    }
    
    if([UtilityFunc checkContactPermission])
    {
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
        [UtilityFunc AddContactEntry:aBook TargetRecord: InviteeVCard];
        
        if(!ABAddressBookSave(aBook, &error))
        {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"ERROR: Unable to Save ABAddressBook. Error = %@", CFErrorCopyDescription(error)]];
        }
        
        if(allPeople)CFRelease(allPeople);
        if(aBook)CFRelease(aBook);
    }else{
        return 0;
    }
    
    return 1;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
