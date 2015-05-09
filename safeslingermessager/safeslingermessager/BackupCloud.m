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

#import <safeslingerexchange/iToast.h>
#import "BackupCloud.h"
#import "AppDelegate.h"
#import "ErrorLogger.h"
#import "SSEngine.h"

#define CloudFS1 @"safeslinger.dat"

@implementation BackupCloudFile

@synthesize datagram, delegate;

- (id)initWithFileURL:(NSURL *)url {
    if ((self = [super initWithFileURL:url])) {
        DEBUGMSG(@"iCLoud document created with URL: %@", url);
		self.datagram = nil;
        self.delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DocumentStateChanged:) name:UIDocumentStateChangedNotification object:nil];
    }
    return self;
}

- (void)DocumentStateChanged:(NSNotification*)notification {
    if(self.documentState==0)
    {
        // close
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
        [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
        NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:self.fileModificationDate]];
        if(backDate) {
            [[NSUserDefaults standardUserDefaults]setObject:backDate forKey: kBackupCplDate];
        }
    }
}


// Called whenever the application reads data from the file system
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName
                   error:(NSError *__autoreleasing *)outError
{
    if ([contents isKindOfClass:[NSData class]]) {
        if([contents length]>0)
            self.datagram = [[NSData alloc]initWithBytes:[contents bytes] length:[contents length]];
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
    if ([self.datagram length] == 0) {
        self.datagram = nil;
    }
    return self.datagram;
}

@end


@implementation BackupCloudUtility

@synthesize Operation, _query, bkperiod, CloudEnabled, _rootPath, delegate, Responder;

-(id)init
{
    if (self = [super init])
    {
        delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    }
    return self;
}

-(void)RecheckCapability
{
//    NSString *displayStr = nil;
//    id currentiCloudToken = [[NSFileManager defaultManager] ubiquityIdentityToken];
//    
//    if (currentiCloudToken) {
//        CloudEnabled = YES;
//        NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
//        displayStr = [ubiq lastPathComponent];
//        [[NSUserDefaults standardUserDefaults]setObject:displayStr forKey: kBackupURL];
//    } else {
        CloudEnabled = NO;
//    }
}

-(void)PerformBackup
{
    // wrtie to the icloud backup
    if(CloudEnabled) [self iCloudQuery:YES];
}

-(void)PerformRecovery
{
    // wrtie to the icloud backup
    if(CloudEnabled)
    {
        [self iCloudQuery:NO];
    }
}

- (NSData*)PrepareBackupFile
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc]initForWritingWithMutableData:data];
    
    // backup User preferences
    [archiver encodeInteger:[[NSUserDefaults standardUserDefaults]integerForKey:kAutoDecryptOpt] forKey:kAutoDecryptOpt];
    [archiver encodeInteger:[[NSUserDefaults standardUserDefaults]integerForKey:kRemindBackup] forKey:kRemindBackup];
    [archiver encodeInteger:[[NSUserDefaults standardUserDefaults]integerForKey:kShowExchangeHint] forKey:kShowExchangeHint];
    [archiver encodeInteger:[[NSUserDefaults standardUserDefaults]integerForKey:kPasshpraseCacheTime] forKey:kPasshpraseCacheTime];
    [archiver encodeInteger:[[NSUserDefaults standardUserDefaults]integerForKey:kDEFAULT_DB_KEY] forKey:kDEFAULT_DB_KEY];
    [archiver encodeObject:[[NSUserDefaults standardUserDefaults]stringArrayForKey:kDB_KEY] forKey:kDB_KEY];
    [archiver encodeObject:[[NSUserDefaults standardUserDefaults]stringArrayForKey:kDB_LIST] forKey:kDB_LIST];
    [archiver encodeObject:[[NSUserDefaults standardUserDefaults]objectForKey: kBackupCplDate] forKey:kBackupCplDate];
    [archiver encodeObject:[[NSUserDefaults standardUserDefaults]objectForKey: kRestoreDate] forKey:kRestoreDate];
    [archiver encodeObject:[[NSUserDefaults standardUserDefaults]objectForKey: kBackupReqDate] forKey:kBackupReqDate];
    [archiver encodeInteger:[[NSUserDefaults standardUserDefaults]integerForKey: kAPPVERSION] forKey:kAPPVERSION];
    
    // backup all available databases
    NSArray *keyarr = [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY];
    
    for(int i=0; i<[keyarr count]; i++)
    {
        NSString *db_item = nil;
        if(i==0) db_item = [NSString stringWithFormat:@"%@.db", DATABASE_NAME]; // default
        else db_item = [NSString stringWithFormat:@"%@-%d.db", DATABASE_NAME, i];
        
        NSString *floc = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent: db_item];
        
        NSFileManager* fs = [NSFileManager defaultManager];
        
        if([fs fileExistsAtPath:floc])
        {
            // create tmp database
            NSString* dbpath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent: @"tmp.db"];
            if([fs fileExistsAtPath:dbpath]) [fs removeItemAtPath:dbpath error:nil];
            [fs copyItemAtPath:floc toPath:dbpath error:nil];
            
            SafeSlingerDB *tmp_db = [[SafeSlingerDB alloc]init];
            [tmp_db LoadDBFromStorage: @"tmp"];
            // reset profile status as NonLink
            int nonlink = NonLink;
            NSData *contact = [NSData dataWithBytes:&nonlink length:sizeof(nonlink)];
            [tmp_db InsertOrUpdateConfig:contact withTag:@"IdentityNum"];
            [tmp_db TrimTable:@"msgtable"];
            [tmp_db CloseDB];
            [archiver encodeObject: [NSData dataWithContentsOfFile:dbpath] forKey: db_item];
        }
    }
    
    [archiver finishEncoding];
    
    return data;
}

- (BOOL)RecoveryFromBackup: (NSData*)recoveryfile
{
    if([recoveryfile length]==0) return NO;
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc]initForReadingWithData:recoveryfile];
    
    // roll back databases
    NSArray *DB_KEY = [unarchiver decodeObjectForKey:kDB_KEY];
    NSArray *DB_LIST = [unarchiver decodeObjectForKey:kDB_LIST];
    
    if(DB_KEY==nil||DB_LIST==nil)
    {
        [ErrorLogger ERRORDEBUG:@"Backup kDB_KEY or kDB_LIST are NULL."];
        return NO;
    }
    
    for(NSString *item in DB_KEY) DEBUGMSG(@"DB_KEY = %@", item);
    for(NSString *list in DB_LIST) DEBUGMSG(@"DB_KEY = %@", list);
    
    [[NSUserDefaults standardUserDefaults] setObject:DB_KEY forKey:kDB_KEY];
    [[NSUserDefaults standardUserDefaults] setObject:DB_LIST forKey:kDB_LIST];
    
    [delegate.DbInstance CloseDB];
    for(int i=0; i<[DB_KEY count]; i++)
    {
        NSString *db_item = nil;
        if(i==0) db_item = [NSString stringWithFormat:@"%@.db", DATABASE_NAME]; // default
        else db_item = [NSString stringWithFormat:@"%@-%d.db", DATABASE_NAME, i];
        
        NSData *DatabaseCopy = [unarchiver decodeObjectForKey: db_item];
        DEBUGMSG(@"dataebase(%d) has %lu bytes.", i, (unsigned long)[DatabaseCopy length]);
        
        NSString* dbpath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent: db_item];
        [DatabaseCopy writeToFile: dbpath atomically:YES];
    }
    
    // load default database
    NSInteger DB_KEY_INDEX = [[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY];
    DEBUGMSG(@"DB_KEY_INDEX = %ld", (long)DB_KEY_INDEX);
    if(DB_KEY_INDEX>0){
        [delegate.DbInstance LoadDBFromStorage: [NSString stringWithFormat:@"%@-%ld", DATABASE_NAME, (long)DB_KEY_INDEX]];
    }else{
        [delegate.DbInstance LoadDBFromStorage: nil];
    }
    
    [[NSUserDefaults standardUserDefaults] setInteger:[unarchiver decodeIntegerForKey: kAutoDecryptOpt] forKey:kAutoDecryptOpt];
    [[NSUserDefaults standardUserDefaults] setInteger: [unarchiver decodeIntegerForKey: kRemindBackup] forKey:kRemindBackup];
    [[NSUserDefaults standardUserDefaults] setInteger:[unarchiver decodeIntegerForKey: kShowExchangeHint] forKey:kShowExchangeHint];
    [[NSUserDefaults standardUserDefaults] setObject: [unarchiver decodeObjectForKey: kBackupCplDate] forKey:kBackupCplDate];
    [[NSUserDefaults standardUserDefaults] setObject: [unarchiver decodeObjectForKey: kRestoreDate] forKey:kRestoreDate];
    [[NSUserDefaults standardUserDefaults] setObject: [unarchiver decodeObjectForKey: kBackupReqDate] forKey:kBackupReqDate];
    [[NSUserDefaults standardUserDefaults] setInteger: [unarchiver decodeIntForKey: kPasshpraseCacheTime] forKey:kPasshpraseCacheTime];
    [[NSUserDefaults standardUserDefaults] setInteger: [unarchiver decodeIntForKey: kDEFAULT_DB_KEY] forKey:kDEFAULT_DB_KEY];
    [[NSUserDefaults standardUserDefaults] setInteger: [unarchiver decodeIntForKey: kAPPVERSION] forKey: kAPPVERSION];
    
    [unarchiver finishDecoding];
    unarchiver = nil;
    return YES;
}

- (void)AccessCloud:(NSMetadataQuery *)query
{
    if(Operation)
    {
        NSData* upload = [self PrepareBackupFile];
        DEBUGMSG(@"backup file is ready to upload (%lu bytes).", (unsigned long)[upload length]);
        if(!upload){
            [ErrorLogger ERRORDEBUG: @"The Backup File is Zero Byte."];
        }else{
            NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
            NSURL *ubiquitousPackage1 = [[ubiq URLByAppendingPathComponent:@"Documents"] URLByAppendingPathComponent: CloudFS1];
            BackupCloudFile *backup = [[BackupCloudFile alloc] initWithFileURL:ubiquitousPackage1];
            backup.datagram = upload;
            
            if ([query resultCount] > 0){
                __block BOOL result = NO;
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(queue, ^{
                    [backup saveToURL:[backup fileURL] forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^(BOOL success){
                        result = success;
                        if (success) {
                            [backup closeWithCompletionHandler:^(BOOL success) {
                                if (!success)
                                    [ErrorLogger ERRORDEBUG:@"Unable to close local CoreData document."];
                            }];
                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                            [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
                            [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                            NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:backup.fileModificationDate]];
                            // write to preference
                            [[NSUserDefaults standardUserDefaults]setObject: backDate forKey: kBackupReqDate];
                            DEBUGMSG(@"backup rewrite succeed.");
                        }
                        else {
                            [[NSUserDefaults standardUserDefaults]setObject: NSLocalizedString(@"label_SafeSlingerBackupDelayed", @"SafeSlinger backup delayed") forKey: kBackupReqDate];
                        }
                    }];
                });
            }else{
                
                // No file
                __block BOOL result = NO;
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(queue, ^{
                    [backup saveToURL:[backup fileURL] forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success){
                        result = success;
                        if (success) {
                            [backup closeWithCompletionHandler:^(BOOL success) {
                                if (!success) [ErrorLogger ERRORDEBUG: @"Unable to close local CoreData document."];
                            }];
                            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                            [dateFormatter setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
                            [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
                            NSString *backDate = [NSString stringWithFormat:@"%@",[dateFormatter stringFromDate:backup.fileModificationDate]];
                            // write to preference
                            [[NSUserDefaults standardUserDefaults]setObject: backDate forKey: kBackupReqDate];
                            DEBUGMSG(@"backup create succeed.");
                        }
                        else {
                            [ErrorLogger ERRORDEBUG: @"Unable to save local backup file."];
                            [[NSUserDefaults standardUserDefaults]setObject: NSLocalizedString(@"label_SafeSlingerBackupDelayed", @"SafeSlinger backup delayed") forKey:kBackupReqDate];
                        }
                    }];
                });
            }
        }
        
    }else{
        
        //read, recover
        if ([query resultCount] > 0)
        {
            // try to setup configuration: pick the last one, newest one
            NSMetadataItem *item = [query resultAtIndex:[query resultCount]-1];
            NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
            BackupCloudFile *cfile = [[BackupCloudFile alloc] initWithFileURL:url];
            
            [cfile openWithCompletionHandler:^(BOOL success) {
                if (success) {
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
                            [[NSUserDefaults standardUserDefaults]setObject: backDate forKey: kRestoreDate];
                            DEBUGMSG(@"recovery succeed.");
                            [Responder NotifyRestoreResult:YES];
                            
                        }else{
                            [ErrorLogger ERRORDEBUG: @"The Backup File is Not Complete."];
                            [Responder NotifyRestoreResult:NO];
                        }
                        
                    }else{
                        [ErrorLogger ERRORDEBUG:@"The Backup File is Zero Byte."];
                        //[delegate.setupView NotifyFromBackup: NO];
                    }
                    [cfile closeWithCompletionHandler:^(BOOL success) {
                        if (!success) [ErrorLogger ERRORDEBUG: @"Unable to close local CoreData document."];
                    }];
                } else {
                    [ErrorLogger ERRORDEBUG: @"Unable to opening document from iCloud."];
                    [Responder NotifyRestoreResult:NO];
                }
            }];
            
        }else {
            // no backup file exising on iCloud
            [Responder NotifyRestoreResult:NO];
        }
    }
}

- (void)queryDidFinishGathering:(NSNotification *)notification
{
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
    // nothing
}

- (void)iCloudQuery: (BOOL)ReadOrWrite
{
    self.Operation = ReadOrWrite;
    self._query = [[NSMetadataQuery alloc] init];
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