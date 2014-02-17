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

#import "BackupCloud.h"
#import "KeySlingerAppDelegate.h"
#import "iToast.h"
#import "VersionCheckMarco.h"
#import "ErrorLogger.h"
#import "SSEngine.h"

#define CloudFS1 @"safeslinger.dat"

@implementation BackupCloudFile

@synthesize datagram, delegate;

- (id)initWithFileURL:(NSURL *)url {
    if ((self = [super initWithFileURL:url])) {
        DEBUGMSG(@"iCLoud document created with URL: %@", url);
		self.datagram = nil;
        self.delegate = [[UIApplication sharedApplication]delegate];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DocumentStateChanged:) name:UIDocumentStateChangedNotification object:nil];
    }
    return self;
}

- (void)DocumentStateChanged:(NSNotification*)notification {
    if(self.documentState==0)
    {
        DEBUGMSG(@"Backup Complete.");
        // close
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
        [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
        NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:self.fileModificationDate]];
        if(backDate) {
            [delegate.DbInstance InsertOrUpdateConfig:[backDate dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupCompleteDate"];
        }
        [dateFormatter release];
    }
}


// Called whenever the application reads data from the file system
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName
                   error:(NSError *__autoreleasing *)outError
{
    if ([contents isKindOfClass:[NSData class]]) {
        if([contents length]>0)
            self.datagram = [[[NSData alloc]initWithBytes:[contents bytes] length:[contents length]]autorelease];
        else
            self.datagram = nil;
        return YES;
    }
    else {
        return NO;
    }
}

// Called whenever the application (auto)saves the content of a note
- (id)contentsForType:(NSString *)typeName error:(NSError **)outError
{
    DEBUGMSG(@"contentsForType.");
    if ([self.datagram length] == 0) {
        self.datagram = nil;
    }
    return self.datagram;
}

- (void)dealloc
{
    if(datagram!=nil)
        [datagram release];
    datagram = nil;
    [super dealloc];
}

@end


@implementation BackupCloudUtility

@synthesize Operation, _query, bkperiod, CloudEnabled, _rootPath, delegate; //, _vcard;

-(id)init
{
    if (self = [super init])
    {
        delegate = [[UIApplication sharedApplication]delegate];
        _rootPath = delegate.documentsPath;
    }
    return self;
}

-(void)RecheckCapability
{
    NSString *displayStr = nil;
    if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
    {
        id currentiCloudToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
        if (currentiCloudToken) {
            CloudEnabled = YES;
            NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
            displayStr = [ubiq lastPathComponent];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupURL"];
        } else {
            CloudEnabled = NO;
            displayStr = NSLocalizedString(@"label_None", @"None");
            // make them blanks
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupURL"];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupRequestDate"];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupCompleteDate"];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_restoreCompleteDate"];
        }
    }else{
        // 5.x
        NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
        if (ubiq) {
            CloudEnabled = YES;
            displayStr = [ubiq lastPathComponent];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupURL"];
        } else {
            CloudEnabled = NO;
            displayStr = NSLocalizedString(@"label_None", @"None");
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupURL"];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupRequestDate"];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupCompleteDate"];
            [delegate.DbInstance InsertOrUpdateConfig:[displayStr dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_restoreCompleteDate"];
        }
    }
    [delegate.systemView UpdateView];
}

-(void)PerformBackup
{
    // wrtie to the icloud backup
    if(CloudEnabled) [self iCloudQuery:YES];
}

- (NSData*)PrepareBackupFile
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
    
    // public keys
    [archiver encodeObject: [NSData dataWithContentsOfFile:[NSString stringWithFormat: @"%@/pubkey.pem", _rootPath]] forKey: @"pubkey-enc"];
    [archiver encodeObject: [NSData dataWithContentsOfFile:[NSString stringWithFormat: @"%@/spubkey.pem", _rootPath]] forKey: @"pubkey-sign"];
    // get cipher of private keys
    [archiver encodeObject: [NSData dataWithContentsOfFile:[SSEngine getSelfPrivateKeyPath: ENC_PRI]] forKey: @"prikey-enc"];
    [archiver encodeObject: [NSData dataWithContentsOfFile:[SSEngine getSelfPrivateKeyPath: SIGN_PRI]] forKey: @"prikey-sign"];
    
    // prepare database
    // copy current database to a tempral place
    NSData *DatabaseCopy = [NSData dataWithContentsOfFile:[NSString stringWithFormat: @"%@/%@", _rootPath, DATABASE_NAME]];
    NSString* dbpath = [NSString stringWithFormat: @"%@/%@", _rootPath, @"tmp.db"];
    [DatabaseCopy writeToFile:dbpath atomically:YES];
    // trim tables
    SafeSlingerDB *tmp_db = [[SafeSlingerDB alloc]init];
    [tmp_db LoadDBFromStorage: dbpath];
    [tmp_db TrimTable:@"msgtable"];
    [tmp_db SaveDBToStorage];
    [archiver encodeObject: [NSData dataWithContentsOfFile:dbpath] forKey: DATABASE_NAME];
    
    // key information
    [archiver encodeObject: [NSData dataWithContentsOfFile:[NSString stringWithFormat: @"%@/gendate.txt", _rootPath]] forKey: @"GENDATE"];
    [archiver encodeObject: [NSData dataWithContentsOfFile:[NSString stringWithFormat: @"%@/gendate.dat", _rootPath]] forKey: @"KEYID"];
    
    // vCard
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        }
    });
    
    ABRecordRef aRecord = ABAddressBookGetPersonWithRecordID(aBook, delegate.myID);
    if(!aRecord)
    {
        // contact is missing
        CFRelease(aBook);
        [archiver finishEncoding];
        [archiver release];
        return nil;
    }
    
    NSArray *export = [NSArray arrayWithObject:aRecord];
    NSData *vcard = (NSData*)ABPersonCreateVCardRepresentationWithPeople((CFArrayRef)export);
    [archiver encodeObject: vcard forKey: @"vcard"];
    [vcard release];
    CFRelease(aBook);
    
    [archiver finishEncoding];
    [archiver release];
    
    return data;
}

- (BOOL)RecoveryFromBackup: (NSData*)recoveryfile
{
    if([recoveryfile length]==0) return NO;
    // check contact priviledge first
    if(![delegate.mainView checkContactPermission]) return NO;
    
    BOOL ret = YES;
    CFErrorRef error = NULL;
    ABAddressBookRef aBook = NULL;
    aBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABAddressBookRequestAccessWithCompletion(aBook, ^(bool granted, CFErrorRef error) {
        if (!granted) {
            [ErrorLogger ERRORDEBUG: @"ERROR: Contact Permission Not Granted."];
        }
    });
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc]initForReadingWithData:recoveryfile];
    
    // roll back everything
    NSData *EncPub = [[unarchiver decodeObjectForKey: @"pubkey-enc"]retain];
    if(EncPub)[EncPub writeToFile:[NSString stringWithFormat: @"%@/pubkey.pem", _rootPath] atomically:YES];
    else {
        [ErrorLogger ERRORDEBUG: @"ERROR: EncPub is NULL."];
        ret = NO;
    }
    
    NSData *SignPub = [[unarchiver decodeObjectForKey: @"pubkey-sign"]retain];
    if(SignPub)[SignPub writeToFile:[NSString stringWithFormat: @"%@/spubkey.pem", _rootPath] atomically:YES];
    else {
        [ErrorLogger ERRORDEBUG: @"ERROR: SignPub is NULL."];
        ret = NO;
    }
    
    NSData *EncPri = [[unarchiver decodeObjectForKey: @"prikey-enc"]retain];
    if(EncPri)[EncPri writeToFile:[NSString stringWithFormat: @"%@/prikey.pem", _rootPath] atomically:YES];
    else {
        [ErrorLogger ERRORDEBUG: @"ERROR: EncPri is NULL."];
        ret = NO;
    }
    
    NSData *SignPri = [[unarchiver decodeObjectForKey: @"prikey-sign"]retain];
    if(SignPri)[SignPri writeToFile:[NSString stringWithFormat: @"%@/sprikey.pem", _rootPath] atomically:YES];
    else {
        [ErrorLogger ERRORDEBUG: @"ERROR: SignPri is NULL."];
        ret = NO;
    }
    
    NSData *KeygenDate = [[unarchiver decodeObjectForKey: @"GENDATE"]retain];
    if(KeygenDate)[KeygenDate writeToFile:[NSString stringWithFormat: @"%@/gendate.txt", _rootPath] atomically:YES];
    else {
        [ErrorLogger ERRORDEBUG: @"ERROR: KeygenDate is NULL."];
        ret = NO;
    }
    
    NSData *KeyId = [[unarchiver decodeObjectForKey: @"KEYID"]retain];
    if(KeyId)[KeyId writeToFile:[NSString stringWithFormat: @"%@/gendate.dat", _rootPath] atomically:YES];
    else {
        [ErrorLogger ERRORDEBUG: @"ERROR: KeyID is NULL."];
        ret = NO;
    }
    
    NSData *DatabaseCopy = [[unarchiver decodeObjectForKey: DATABASE_NAME]retain];
    NSString* dbpath = [NSString stringWithFormat: @"%@/%@", _rootPath, DATABASE_NAME];
    if([[NSFileManager defaultManager]fileExistsAtPath:dbpath])
    {
        NSError *err = nil;
        // rewrite db files from recovery file
        [delegate.DbInstance SaveDBToStorage];
        [[NSFileManager defaultManager]removeItemAtPath:dbpath error:&err];
        if(err) {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Unable to backup DataBase from iCloud backup. Error = %@", [err userInfo]]];
            ret = NO;
        }
        [DatabaseCopy writeToFile:dbpath atomically:YES];
        [delegate.DbInstance LoadDBFromStorage: nil];
    }
    
    NSData *VCardCopy = [[unarchiver decodeObjectForKey: @"vcard"]retain];
    
    // Vcard should be treat different way
    ABRecordRef selfcontact = NULL;
    CFArrayRef contact = ABPersonCreatePeopleInSourceWithVCardRepresentation(NULL, (CFDataRef)VCardCopy);
    if(CFArrayGetCount(contact)==1)
    {
        int ExistContact = -1;
        selfcontact =CFArrayGetValueAtIndex(contact,0);
        CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(aBook);
        NSString *CompositeName = (NSString*)ABRecordCopyCompositeName(selfcontact);
        for (CFIndex j = 0; j < CFArrayGetCount(allPeople); j++)
        {
            ABRecordRef existing = CFArrayGetValueAtIndex(allPeople, j);
            NSString *existingCN = (NSString*)ABRecordCopyCompositeName(existing);
            if ([CompositeName isEqualToString: existingCN])
            {
                // Keep the existing one
                ExistContact = ABRecordGetRecordID(existing);
            }
            if(existingCN)[existingCN release];
        }
        if(CompositeName)[CompositeName release];
        if(allPeople)CFRelease(allPeople);
        
        if(ExistContact==-1)
        {
            // add VCard and update database
            if(!ABAddressBookAddRecord(aBook, selfcontact, &error))
            {
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Unable to Add the new record. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
                ret = NO;
            }
            if(!ABAddressBookSave(aBook, &error))
            {
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Unable to save ABAddressBook. Error = %@", (NSString*)CFErrorCopyDescription(error)]];
                ret = NO;
            }
            delegate.myID = ABRecordGetRecordID(selfcontact);
        }else{
            delegate.myID = ExistContact;
        }
    }else{
        ret = NO;
    }
    DEBUGMSG(@"self contact id = %d", delegate.myID);
    if(selfcontact)CFRelease(selfcontact);
    if(aBook)CFRelease(aBook);
    
    [unarchiver finishDecoding];
    [unarchiver release];
    unarchiver = nil;
    return ret;
}

- (void)AccessCloud:(NSMetadataQuery *)query
{
    if(Operation)
    {
        NSData* upload = [self PrepareBackupFile];
        if(upload){
            [ErrorLogger ERRORDEBUG: @"ERROR: The Backup File is Zero Byte."];
        }else{
            NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
            NSURL *ubiquitousPackage1 = [[ubiq URLByAppendingPathComponent:@"Documents"]
                                         URLByAppendingPathComponent: CloudFS1];
            BackupCloudFile *backup = [[BackupCloudFile alloc] initWithFileURL:ubiquitousPackage1];
            backup.datagram = [upload retain];
            [upload release];
            
            if ([query resultCount] > 0){
                DEBUGMSG(@"One backup file on iCloud Storage. Start overwriting self copy to Cloud..");
                
                __block BOOL result = NO;
                
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(queue, ^{
                    [backup saveToURL:[backup fileURL] forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success){
                        result = success;
                        if (success) {
                            DEBUGMSG(@"backup save successful!");
                            [backup closeWithCompletionHandler:^(BOOL success) {
                                if (!success)
                                    [ErrorLogger ERRORDEBUG:@"ERROR: Unable to close local CoreData document."];
                                [backup autorelease];
                            }];
                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                            [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
                            [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                            NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:backup.fileModificationDate]];
                            DEBUGMSG(@"backDate = %@", backDate);
                            // write to preference
                            [delegate.DbInstance InsertOrUpdateConfig:[backDate dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupRequestDate"];
                            [dateFormatter release];
                        }
                        else {
                            DEBUGMSG(@"PostPone Backup: Cannot save local backup file.");
                            [backup autorelease];
                            [delegate.DbInstance InsertOrUpdateConfig:[NSLocalizedString(@"label_SafeSlingerBackupDelayed", @"SafeSlinger backup delayed") dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupCompleteDate"];
                        }
                        [delegate.systemView UpdateView];
                    }];
                });
            }else{
                
                // No file
                DEBUGMSG(@"No backup file on iCloud Storage. Start uploading self copy to Cloud..");
                __block BOOL result = NO;
                
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(queue, ^{
                    [backup saveToURL:[backup fileURL] forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
                        result = success;
                        if (success) {
                            DEBUGMSG(@"backup save successful!");
                            [backup closeWithCompletionHandler:^(BOOL success) {
                                if (!success) [ErrorLogger ERRORDEBUG: @"ERROR: Unable to close local CoreData document."];
                                [backup autorelease];
                            }];
                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                            [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
                            [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                            NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:backup.fileModificationDate]];
                            DEBUGMSG(@"backDate = %@", backDate);
                            // write to preference
                            [delegate.DbInstance InsertOrUpdateConfig:[backDate dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupRequestDate"];
                            [dateFormatter release];
                        }
                        else {
                            [ErrorLogger ERRORDEBUG: @"ERROR: Unable to save local backup file."];
                            [backup autorelease];
                            [delegate.DbInstance InsertOrUpdateConfig:[NSLocalizedString(@"label_SafeSlingerBackupDelayed", @"SafeSlinger backup delayed") dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_backupCompleteDate"];
                        }
                        [delegate.systemView UpdateView];
                    }];
                });

            }
        }
        
    }else{
        
        //read, recover
        if ([query resultCount] > 0)
        {
            // try to setup configuration
            // pick the last one
            NSMetadataItem *item = [query resultAtIndex:[query resultCount]-1];
            NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
            BackupCloudFile *cfile = [[BackupCloudFile alloc] initWithFileURL:url];
            
            [cfile openWithCompletionHandler:^(BOOL success) {
                if (success) {
                    DEBUGMSG(@"iCloud data has %d bytes", [cfile.datagram length]);
                    // be.gin backup
                    if([cfile.datagram length]>0)
                    {
                        BOOL ret = [self RecoveryFromBackup: cfile.datagram];
                        if(ret)
                        {
                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                            [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
                            [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                            NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:cfile.fileModificationDate]];
                            [dateFormatter release];
                            [delegate.DbInstance InsertOrUpdateConfig:[backDate dataUsingEncoding:NSUTF8StringEncoding] withTag:@"label_restoreCompleteDate"];
                            // enable HW Encryption as possible
                            DEBUGMSG(@"backup succeed.");
                            [delegate.setupView NotifyFromBackup:YES];
                            [delegate.systemView UpdateView];
                        }else{
                            [ErrorLogger ERRORDEBUG: @"ERROR: The Backup File is Not Complete."];
                            [delegate.setupView NotifyFromBackup:NO];
                        }
                        
                    }else{
                        [ErrorLogger ERRORDEBUG:@"ERROR: The Backup File is Zero Byte."];
                        [delegate.setupView NotifyFromBackup:NO];
                    }
                    [cfile closeWithCompletionHandler:^(BOOL success) {
                        if (!success) [ErrorLogger ERRORDEBUG: @"ERROR: Unable to close local CoreData document."];
                    }];
                } else {
                    [ErrorLogger ERRORDEBUG: @"ERROR: Unable to opening document from iCloud."];
                    [delegate.setupView NotifyFromBackup:NO];
                }
            }];
            [cfile release];
            
        }else {
            DEBUGMSG(@"No backup file exist.");
        }
    }
}

- (void)queryDidFinishGathering:(NSNotification *)notification
{
    DEBUGMSG(@"queryDidFinishGathering");
    NSMetadataQuery *query = [notification object];
    [_query disableUpdates];
    [_query stopQuery];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidFinishGatheringNotification
                                                  object:_query];
    _query = nil;
	[self AccessCloud: query];
}

// Method invoked when notifications of content batches have been received
- (void)queryDidUpdate:sender
{
    DEBUGMSG(@"A data batch has been received");
}

- (void)iCloudQuery: (BOOL)ReadOrWrite
{
    self.Operation = ReadOrWrite;
    self._query = [[[NSMetadataQuery alloc] init] autorelease];
    [self._query setSearchScopes:[NSArray arrayWithObject:NSMetadataQueryUbiquitousDocumentsScope]];
    NSPredicate *pred = [NSPredicate predicateWithFormat: @"%K == %@", NSMetadataItemFSNameKey, CloudFS1];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryDidUpdate:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:self._query];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryDidFinishGathering:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:self._query];
    [self._query setPredicate:pred];
    [self._query startQuery];
}

@end