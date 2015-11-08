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

#import "SafeSlingerDB.h"
#import "Utility.h"
#import "ErrorLogger.h"
#import "ContactSelectView.h"

// the version of the database for this version of the app
#define CURRENT_DATABASE_VERSION 1

@implementation FileInfo
@synthesize FName, FSize, FExt;

@end

@implementation MsgEntry

@synthesize msgid, cTime, rTime, attach, smsg, sfile, fext, face;
@synthesize dir, token, sender, msgbody, fname, fbody, keyid;

-(MsgEntry*)InitOutgoingMsg: (NSData*)newmsgid Recipient:(ContactEntry*)user Message:(NSString*)message FileName:(NSString*)File FileType:(NSString*)MimeType FileData:(NSData*)FileRaw {
    // msgid
    self.msgid = newmsgid;
    self.dir = ToMsg;
    self.sender = [NSString compositeName:user.firstName withLastName:user.lastName];
    self.token = user.pushToken;
    self.keyid = user.keyId;
	self.cTime = [NSString GetGMTString:DATABASE_TIMESTR];
	
    if([message length]>0) self.msgbody = [message dataUsingEncoding:NSUTF8StringEncoding];
    else self.msgbody = nil;
    
    self.attach = ((File==nil) ? 0 : 1);
    self.smsg = self.sfile = Decrypted;
    self.face = nil;
    
    if(File) {
        self.fname = File;
        self.fbody = FileRaw;
        self.fext = MimeType;
    }
    return self;
}

-(MsgEntry*)InitIncomingMessage: (NSData*)newmsgid UserName:(NSString*)uname Token:(NSString*)tokenstr Message:(NSData*)cipher SecureM:(int)mflag SecureF:(int)fflag
{
    // msgid
    self.msgid = newmsgid;
    self.dir = FromMsg;
    self.sender = uname;
    self.token = tokenstr;
    self.msgbody = cipher;
    self.smsg = mflag;
    self.attach = self.sfile = fflag;
    self.face = nil;
    return self;
}

@end

@implementation MsgListEntry
@end

@implementation SafeSlingerDB

// private method
- (BOOL)LoadDBFromStorage:(NSString *)specific_path {
    BOOL success = NO;
	@try {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
		
		NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
		NSString *writableDBPath = [libraryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db", specific_path ? specific_path : DATABASE_NAME]];
        
        DEBUGMSG(@"DB Path = %@", writableDBPath);
        
        if (![fileManager fileExistsAtPath:writableDBPath]) {
            // The writable database does not exist, so copy the default to the appropriate location.
            NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db", DATABASE_NAME]];
            if (![fileManager copyItemAtPath:defaultDBPath toPath:writableDBPath error:&error]) {
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Failed to create writable database file with message '%@'.", [error localizedDescription]]];
            }
        }
        
        if(sqlite3_open([writableDBPath UTF8String], &db) == SQLITE_OK) {
			success = [self updateDatabase];
		} else {
			[ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Unable to open database. reasone = %s", sqlite3_errmsg(db)]];
		}
    } @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured, %@", [exception reason]]];
    } @finally {
        return success;
    }
}

- (BOOL)updateDatabase {
	
    sqlite3_stmt *sqlStatement;
	const char *sql = "PRAGMA user_version;";
    BOOL ret = NO;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) == SQLITE_ROW) {
            int databaseVersion = sqlite3_column_int(sqlStatement, 0);
            if(databaseVersion < CURRENT_DATABASE_VERSION) {
                if(databaseVersion == 0) {
                    // patches for database update from version 0 to version 1
                    if(!([self patchForContactsFromAddressBook] && [self patchForUnreadMessagesFlag] && [self patchForTokenstorePrimaryKey]))
                    {
                        sqlite3_finalize(sqlStatement);
                        return ret;
                    }
                }
                sqlite3_stmt *sqlStatement2;
                sql = [[NSString stringWithFormat:@"PRAGMA user_version = %d;", CURRENT_DATABASE_VERSION] cStringUsingEncoding:NSUTF8StringEncoding];
                if(sqlite3_prepare(db, sql, -1, &sqlStatement2, NULL) == SQLITE_OK) {
                    if(sqlite3_step(sqlStatement2) == SQLITE_DONE)
                        ret = YES;
                    else
                        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while performing command. '%s'", sqlite3_errmsg(db)]];
                    sqlite3_finalize(sqlStatement2);
                }else{
                    [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
                }
            }
        } else {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error executing statement: '%s'\n", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
	return ret;
}

- (BOOL)TrimTable: (NSString*)table_name
{
    if(!db){
        [ErrorLogger ERRORDEBUG: @"database/table_name is null."];
        return NO;
    }
    
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = [[NSString stringWithFormat:@"DELETE FROM %@", table_name]cStringUsingEncoding:NSASCIIStringEncoding];
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        if(sqlite3_step(sqlStatement) == SQLITE_DONE){
            ret = YES;
        }else
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while deleting table. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (BOOL)RemoveConfigTag:(NSString*)tag
{
    if(!db || [tag length]==0){
        [ErrorLogger ERRORDEBUG: @"database/tag is null."];
        return NO;
    }
    
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "DELETE FROM configs WHERE item_key=?;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind item_key
        sqlite3_bind_text(sqlStatement, 1, [tag UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement) == SQLITE_DONE) {
            ret = YES;
        }else
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Error while deleting data. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Error while preparing statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (BOOL)InsertOrUpdateConfig: (NSData*)value withTag:(NSString*)tag
{
    if(!db || [tag length]==0 || [value length]==0){
        [ErrorLogger ERRORDEBUG: @"database/value/tag is null."];
        return NO;
    }
    
    BOOL ret = YES;
    BOOL exist = NO;
    
    @try {
        sqlite3_stmt *sqlStatement;
        const char *sql = "SELECT COUNT(*) FROM configs WHERE item_key=?;";
        
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Error while preparing statement. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        // bind item_key
        sqlite3_bind_text(sqlStatement, 1, [tag UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement) == SQLITE_ERROR) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Error while query data. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        } else {
            if(sqlite3_column_int(sqlStatement, 0)>0) exist = YES;
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
            ret = NO;
        }
        
        if(exist)
        {
            sql = "update configs set item_value=? WHERE item_key=?;";
        }else{
            sql = "insert into configs (item_value, item_key) Values (?,?);";
        }
        
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while creating add statement. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        //item_value
        if(value)
            sqlite3_bind_blob(sqlStatement, 1, [value bytes], (int)[value length], SQLITE_TRANSIENT);
        else
            sqlite3_bind_null(sqlStatement, 1);
        
        //item_key
        sqlite3_bind_text(sqlStatement, 2, [tag UTF8String], -1, SQLITE_TRANSIENT);
        
        if(SQLITE_DONE != sqlite3_step(sqlStatement)){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"ERROR: Error while inserting data. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
            ret = NO;
        }
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: An exception occured, %@", [exception reason]]];
        ret = NO;
    }
    @finally {
        return ret;
    }
}

- (NSString*)GetStringConfig: (NSString*)tag
{
    if(!db || [tag length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/tag is null."];
        return nil;
    }
    
    NSString* data = nil;
    const char *sql = "SELECT item_value FROM configs where item_key = ?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_text(sqlStatement, 1, [tag UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            if(sqlite3_column_bytes(sqlStatement, 0)>0) {
                data = [NSString stringWithCString:sqlite3_column_blob(sqlStatement, 0) encoding:NSUTF8StringEncoding];
            }
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while preparing statement. '%s'", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return data;
}

- (NSData*)GetConfig: (NSString*)tag
{
    if(!db || [tag length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/tag is null."];
        return nil;
    }
    
    NSData* value = nil;
    const char *sql = "SELECT item_value FROM configs where item_key = ?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_text(sqlStatement, 1, [tag UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            int rawLen = sqlite3_column_bytes(sqlStatement, 0);
            if(rawLen>0) {
                value = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:rawLen];
            }
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while executing statement. '%s'", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return value;
}

- (NSData*)QueryInMsgTableByMsgID: (NSData*)MSGID Field:(NSString*)FIELD
{
    if(!db || [MSGID length]==0 || [FIELD length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/MSGID/FIELD is null."];
        return nil;
    }
    NSData* queryterm = nil;
    NSString* sqlstr = [NSString stringWithFormat:@"SELECT %@ FROM msgtable WHERE msgid = ?", FIELD];
    const char *sql = [sqlstr UTF8String];
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_blob(sqlStatement, 1, [MSGID bytes], (int)[MSGID length], SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            if(sqlite3_column_type(sqlStatement, 0)==SQLITE_TEXT)
            {
                // string term
                queryterm = [[NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)] dataUsingEncoding:NSUTF8StringEncoding];
            }else if(sqlite3_column_type(sqlStatement, 0)==SQLITE_BLOB)
            {
                // data term
                int rawLen = sqlite3_column_bytes(sqlStatement, 0);
                if(rawLen>0) {
                    queryterm = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:rawLen];
                }
            }
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return queryterm;
}

- (NSString*)QueryStringInTokenTableByKeyID:(NSString*)KEYID Field:(NSString*)FIELD
{
    if(!db || [KEYID length]==0 || [FIELD length]==0){
        [ErrorLogger ERRORDEBUG: @"database/MSGID/FIELD is null."];
        return nil;
    }
    NSString* queryterm = nil;
    sqlite3_stmt *sqlStatement;
    NSString* sqlstr = [NSString stringWithFormat:@"SELECT %@ FROM tokenstore WHERE keyid=?", FIELD];
    const char *sql = [sqlstr UTF8String];
        
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        sqlite3_bind_blob(sqlStatement, 1, [KEYID cStringUsingEncoding:NSUTF8StringEncoding], (int)[KEYID lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        // get newest one
        if (sqlite3_step(sqlStatement)==SQLITE_ROW)
        {
            if(sqlite3_column_type(sqlStatement, 0)!=SQLITE_NULL)
            {
                queryterm = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)];
            }
            sqlite3_finalize(sqlStatement);
        }
    }else
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    return queryterm;
}


#pragma Utility
- (NSString *)GetProfileName {
    if(!db){
        [ErrorLogger ERRORDEBUG: @"database is null."];
        return nil;
    }
    // profile only
    NSString* fname = [self GetStringConfig: @"Profile_FN"];
    NSString* lname = [self GetStringConfig: @"Profile_LN"];
    return [NSString compositeName:fname withLastName:lname];
}

- (NSString *)GetRawKey:(NSString *)KEYID {
    if(!db || [KEYID length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/KEYID is null."];
        return nil;
    }
    
    NSString *pubkey = nil;
    // get the newest term
    const char *sql = "SELECT pkey FROM tokenstore WHERE keyid=?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        // keyid
        sqlite3_bind_blob(sqlStatement, 1, [KEYID cStringUsingEncoding:NSUTF8StringEncoding], (int)[KEYID lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            if(sqlite3_column_type(sqlStatement, 0)!=SQLITE_NULL)
            {
                pubkey = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 0)];
            }
        }
        sqlite3_finalize(sqlStatement);
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    return pubkey;
}

- (int)GetDeviceType:(NSString *)KEYID {
    int dev = -1;
    if(!db || [KEYID length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/KEYID is null."];
        return dev;
    }
    
    // get the newest key
    const char *sql = "select dev from tokenstore WHERE keyid=?;";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_blob(sqlStatement, 1, [KEYID cStringUsingEncoding:NSUTF8StringEncoding], (int)[KEYID lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            dev = sqlite3_column_int(sqlStatement, 0);
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return dev;
}

- (int)GetExchangeType:(NSString *)KEYID {
    int ex_type = -1;
    if(!db || [KEYID length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/KEYID is null."];
        return ex_type;
    }
    
    // get the newest key
    const char *sql = "select ex_type from tokenstore where keyid=?;";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_blob(sqlStatement, 1, [KEYID cStringUsingEncoding:NSUTF8StringEncoding], (int)[KEYID lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            ex_type = sqlite3_column_int(sqlStatement, 0);
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return ex_type;
}

#pragma Recipients
- (NSArray*)LoadRecipients:(BOOL)ExchangeOnly {
    
    if(!db) {
        [ErrorLogger ERRORDEBUG: @"database is null."];
        return nil;
    }
    
    NSMutableArray *tmpArray = nil;
    sqlite3_stmt *sqlStatement = NULL;
    tmpArray = [NSMutableArray arrayWithCapacity:0];
    const char *sql = NULL;
    if(ExchangeOnly) {
        sql = "SELECT * FROM tokenstore where ex_type = 0 ORDER BY pid COLLATE NOCASE DESC";
    } else {
        sql = "SELECT * FROM tokenstore ORDER BY pid COLLATE NOCASE DESC";
    }
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            [tmpArray addObject:[self loadContactEntryFromStatement:sqlStatement]];
        }
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
        
    sqlite3_finalize(sqlStatement);
    return tmpArray;
}

- (NSArray *)LoadRecentRecipients:(BOOL)ExchangeOnly {
    if(!db) {
        [ErrorLogger ERRORDEBUG: @"database is null."];
        return nil;
    }
	
    NSMutableArray *result = [NSMutableArray new];
    const char *sql = NULL;
    sqlite3_stmt *sqlStatement = NULL;
    // Entries with the same value of <Name><Device Type> or <Push Token><Device Type>
    // are considered the represent the same contact, and only the most recent one is shown
    if(ExchangeOnly) {
        sql = "SELECT *, max(bdate) FROM (SELECT *, max(bdate) FROM tokenstore WHERE ex_type = 0 GROUP BY pid, dev) GROUP BY ptoken, dev ORDER BY pid COLLATE NOCASE DESC";
    } else {
        sql = "SELECT *, max(bdate) FROM (SELECT *, max(bdate) FROM tokenstore GROUP BY pid, dev) GROUP BY ptoken, dev ORDER BY pid COLLATE NOCASE DESC";
    }
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            [result addObject:[self loadContactEntryFromStatement:sqlStatement]];
        }
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    sqlite3_finalize(sqlStatement);
    return result;
}

- (ContactEntry *)loadContactEntryWithKeyId:(NSString *)keyId {
	if(!db) {
		[ErrorLogger ERRORDEBUG: @"database/keyId is null."];
		return nil;
	}
	ContactEntry *contact = nil;
    const char *sql = "SELECT * FROM tokenstore WHERE keyid=?";
	sqlite3_stmt *sqlStatement = nil;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // bind keyId
        sqlite3_bind_blob(sqlStatement, 1, [keyId cStringUsingEncoding:NSUTF8StringEncoding], (int)[keyId lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_ROW) {
            contact = [self loadContactEntryFromStatement:sqlStatement];
        }
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    sqlite3_finalize(sqlStatement);
	return contact;
}

- (ContactEntry *)loadContactEntryFromStatement:(sqlite3_stmt *)sqlStatement {
	ContactEntry *contact = [ContactEntry new];
	NSString *column = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 1)];
	NSArray* namearray = [[column substringFromIndex:[column rangeOfString:@":"].location+1]componentsSeparatedByString:@";"];
	if([namearray[1] length] > 0) {
		contact.firstName = [namearray objectAtIndex:1];
	}
	if([namearray[0] length] > 0) {
		contact.lastName = [namearray objectAtIndex:0];
	}
	contact.pushToken = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 0)];
	contact.exchangeDate = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 2)];
	contact.devType = sqlite3_column_int(sqlStatement, 3);
	contact.exchangeType = sqlite3_column_int(sqlStatement, 4);
	// setphoto
	if(sqlite3_column_type(sqlStatement, 5) != SQLITE_NULL) {
        contact.photo = [[NSData alloc]initWithBase64EncodedString:[NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 5)] options:0];
        //[Base64 decode:[NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 5)]];
	}
	// set keyid and pstamp
	if(sqlite3_column_bytes(sqlStatement, 6) > 0) {
		contact.keyId = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 6)];
	}
	if(sqlite3_column_type(sqlStatement, 8) != SQLITE_NULL) {
		contact.keygenDate = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 8)];
	}
	contact.recordId = sqlite3_column_int(sqlStatement, 10);
	return contact;
}

- (BOOL)updateContactDetails:(ContactEntry *)contact {
    BOOL result = NO;
	if (!db || !contact) {
		[ErrorLogger ERRORDEBUG: @"database/contact is null."];
		return result;
	}
	
	// update
    const char *sql = "UPDATE tokenstore SET pid=?, note=?, ABRecordID=? WHERE ptoken=?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // bind pid
        sqlite3_bind_text(sqlStatement, 1, [[NSString vcardnstring:contact.firstName withLastName:contact.lastName] UTF8String], -1, SQLITE_TRANSIENT);
        // bind photo
        if (!contact.photo) {
            sqlite3_bind_text(sqlStatement, 2, [[contact.photo base64EncodedStringWithOptions:0]UTF8String], -1, SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(sqlStatement, 2);
        }
        // bind ABRecordID
        sqlite3_bind_int(sqlStatement, 3, contact.recordId);
        // bind ptoken
        sqlite3_bind_text(sqlStatement, 4, [contact.pushToken UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_DONE) {
            result = YES;
        }else
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while inserting peer. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    return result;
}

- (BOOL)addNewRecipient:(ContactEntry *)contact {
    if (!db || !contact || !contact.keyId || !contact.keygenDate || !contact.keyString) {
        [ErrorLogger ERRORDEBUG: @"database/contact is null."];
        return NO;
    }
	
    BOOL result = NO;
    const char *sql = "SELECT pid FROM tokenstore WHERE keyid=?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        NSString* ptoken = nil;
        sqlite3_bind_blob(sqlStatement, 1, [contact.keyId cStringUsingEncoding:NSUTF8StringEncoding], (int)[contact.keyId lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement) == SQLITE_ROW) {
            ptoken = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)];
        }
        sqlite3_finalize(sqlStatement);
        
        NSString* now = [NSString GetLocalTimeString:DATABASE_TIMESTR];
        if(ptoken) {
            // update
            sql = "UPDATE tokenstore SET pid=?, dev=?, bdate=?, note=?, ex_type=?, ptoken=?, pkey=?, pstamp=? WHERE keyid=?";
            
            if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
                // bind pid
                sqlite3_bind_text(sqlStatement, 1, [[NSString vcardnstring:contact.firstName withLastName:contact.lastName] UTF8String], -1, SQLITE_TRANSIENT);
                // bind dev
                sqlite3_bind_int(sqlStatement, 2, contact.devType);
                // bind date
                sqlite3_bind_text(sqlStatement, 3, [now UTF8String], -1, SQLITE_TRANSIENT);
                // bind photo
                if (!contact.photo) {
                    sqlite3_bind_text(sqlStatement, 4, [[UIImageJPEGRepresentation([UIImage imageWithData:contact.photo], 0.9) base64EncodedStringWithOptions:0] UTF8String], -1, SQLITE_TRANSIENT);
                } else {
                    sqlite3_bind_null(sqlStatement, 4);
                }
                // bind ex_type
                sqlite3_bind_int(sqlStatement, 5, contact.exchangeType);
                // bind ptoken
                sqlite3_bind_text(sqlStatement, 6, [contact.pushToken UTF8String], -1, SQLITE_TRANSIENT);
                // pkey
                sqlite3_bind_text(sqlStatement, 7, [contact.keyString UTF8String], -1, SQLITE_TRANSIENT);
                // pstamp
                sqlite3_bind_text(sqlStatement, 8, [contact.keygenDate UTF8String], -1, SQLITE_TRANSIENT);
                // bind keyid
                sqlite3_bind_blob(sqlStatement, 9, [contact.keyId cStringUsingEncoding:NSUTF8StringEncoding], (int)[contact.keyId lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
                if(sqlite3_step(sqlStatement)==SQLITE_DONE) {
                    result = YES;
                }else
                    [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while inserting peer. '%s'", sqlite3_errmsg(db)]];
                sqlite3_finalize(sqlStatement);
            }else
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement. %s", sqlite3_errmsg(db)]];
        } else {
            
            sql = "INSERT INTO tokenstore (ptoken, pid, bdate, dev, ex_type, note, keyid, pkey, pstamp, ABRecordID) Values (?,?,?,?,?,?,?,?,?,?)";
            if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
                // bind ptoken
                sqlite3_bind_text(sqlStatement, 1, [contact.pushToken UTF8String], -1, SQLITE_TRANSIENT);
                // bind pid
                sqlite3_bind_text(sqlStatement, 2, [[NSString vcardnstring:contact.firstName withLastName:contact.lastName] UTF8String], -1, SQLITE_TRANSIENT);
                // binf date
                sqlite3_bind_text(sqlStatement, 3, [now UTF8String], -1, SQLITE_TRANSIENT);
                // bind dev
                sqlite3_bind_int(sqlStatement, 4, contact.devType);
                // bind ex_type
                sqlite3_bind_int(sqlStatement, 5, contact.exchangeType);
                // bind photo
                if (!contact.photo) {
                    sqlite3_bind_text(sqlStatement, 6, [[UIImageJPEGRepresentation([UIImage imageWithData:contact.photo], 1.0) base64EncodedStringWithOptions:0] UTF8String], -1, SQLITE_TRANSIENT);
                } else {
                    sqlite3_bind_null(sqlStatement, 6);
                }
                // bind keyid
                sqlite3_bind_blob(sqlStatement, 7, [contact.keyId cStringUsingEncoding:NSUTF8StringEncoding], (int)[contact.keyId lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
                // pkey
                sqlite3_bind_text(sqlStatement, 8, [contact.keyString UTF8String], -1, SQLITE_TRANSIENT);
                // pstamp
                sqlite3_bind_text(sqlStatement, 9, [contact.keygenDate UTF8String], -1, SQLITE_TRANSIENT);
                // ABRecordID
                sqlite3_bind_int(sqlStatement, 10, contact.recordId);
                if (sqlite3_step(sqlStatement)==SQLITE_DONE) {
                    result = YES;
                }else
                    [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while inserting peer. '%s'", sqlite3_errmsg(db)]];
                sqlite3_finalize(sqlStatement);
            }else
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sqlite3_errmsg(db)]];
        }
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sqlite3_errmsg(db)]];
    return result;
}

- (BOOL)RemoveRecipient:(NSString *)keyid {
    BOOL ret = NO;
    if(!db || [keyid length]==0) {
        [ErrorLogger ERRORDEBUG: @"database/keyid is null."];
        return ret;
    }
    sqlite3_stmt *sqlStatement;
    const char *sql = "DELETE FROM tokenstore WHERE keyid=?";
    // first , remove toekn from token store
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // bind keyid
        sqlite3_bind_blob(sqlStatement, 1, [keyid cStringUsingEncoding:NSUTF8StringEncoding], (int)[keyid lengthOfBytesUsingEncoding:NSUTF8StringEncoding], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_DONE) {
            ret = YES;
        }else
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while inserting data. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    return ret;
}

- (BOOL)PatchForTokenStoreTable {
    
    // patch for 1.7
    DEBUGMSG(@"database patch to change tokenstore.");
    BOOL ret = NO;
    // for configuration table
    sqlite3_stmt *sqlStatement;
    const char *sql = "ALTER TABLE tokenstore RENAME TO tokenstore_temp;";
        
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) != SQLITE_DONE) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while executing statement. '%s'\n", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    
    sql = "CREATE TABLE tokenstore (ptoken text not null, pid text not null, bdate datetime not null, dev int not null, ex_type int not null, note text, keyid blob not null, pkey text, pstamp datetime, pstatus int default 0, PRIMARY KEY(ptoken, keyid));";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) != SQLITE_DONE) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while executing statement. '%s'\n", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    
    sql = "INSERT INTO tokenstore SELECT * FROM tokenstore_temp;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) != SQLITE_DONE) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while executing statement. '%s'\n", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    
    sql = "DROP TABLE tokenstore_temp;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) != SQLITE_DONE) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while executing statement. '%s'\n", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
        
    sql = "DELETE msgtable WHERE smsg = 'Y';";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) != SQLITE_DONE) {
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while executing statement. '%s'\n", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    
    
    sql = "SELECT keyid, ptoken FROM tokenstore;";
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        while(sqlite3_step(sqlStatement) == SQLITE_ROW) {
            NSString* keyid = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 0)];
            NSString* token = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 1)];
            [dict setObject:keyid forKey:token];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    
    ret = YES;
    for(NSString* token in [dict allKeys]) {
        NSString *keyid = [dict objectForKey:token];
        sql = "UPDATE msgtable SET receipt = ? WHERE token = ?;";
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
            sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(sqlStatement, 2, [token UTF8String], -1, SQLITE_TRANSIENT);
            if(sqlite3_step(sqlStatement) != SQLITE_DONE) {
                [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"update failed."]];
                ret = NO;
            }
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }
        
    DEBUGMSG(@"Update Done.");
    return ret;
}

// Adds a new column 'unread' to the table 'msgtable'
// 'unread' is a flag that indicates if the message was not read yet. It is needed with the auto-decryption, to show the correct number of unread messages
- (BOOL)patchForUnreadMessagesFlag {
	// patch for 1.8.1
	BOOL ret = NO;
	// for configuration table
    sqlite3_stmt *sqlStatement;
    char *sql = "SELECT unread FROM msgtable;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // column already exists
        sqlite3_finalize(sqlStatement);
        return YES;
    }
    sql = "ALTER TABLE msgtable ADD COLUMN unread int;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret = YES;
    }else
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    sqlite3_finalize(sqlStatement);
    return ret;
}

// Adds a new column 'ABRecordID' to the table 'tokenstore'
// 'ABRecordID' stores the AddressBook RecordID for the contact in the user's device associated with this key
- (BOOL)patchForContactsFromAddressBook {
	// patch for 1.8.1
	BOOL ret = NO;
	// for configuration table
    sqlite3_stmt *sqlStatement;
    char *sql = "SELECT ABRecordID FROM tokenstore;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // column already exists
        sqlite3_finalize(sqlStatement);
        return YES;
    }
    sql = "ALTER TABLE tokenstore ADD COLUMN ABRecordID int;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret = YES;
        sqlite3_finalize(sqlStatement);
    }else
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    return ret;
}

// Sets the columns 'ptoken' and 'keyid' as primary keys for the table 'tokenstore'
- (BOOL)patchForTokenstorePrimaryKey {
	
    DEBUGMSG(@"database patch to change primary key on tokenstore table");
	sqlite3_stmt *sqlStatement;
    char *sql = "PRAGMA table_info(tokenstore);";
		
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        int primaryKeyColumnNumber = -1;
        for(int i = 0; i < sqlite3_column_count(sqlStatement); i++) {
            if([[NSString stringWithUTF8String:sqlite3_column_name(sqlStatement, i)] isEqualToString:@"pk"]) {
                primaryKeyColumnNumber = i;
                break;
            }
        }
        int primaryKeyColumnsCount = 0;
        while(sqlite3_step(sqlStatement) == SQLITE_ROW) {
            if(sqlite3_column_int(sqlStatement, primaryKeyColumnNumber) != 0) {
                primaryKeyColumnsCount++;
            }
        }
        if(primaryKeyColumnsCount == 2) {
            // primary key is already ptoken + keyid
            sqlite3_finalize(sqlStatement);
            return YES;
        }
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
        return NO;
    }
    
    // copy case
    int ret = 0;
	sql = "ALTER TABLE tokenstore RENAME TO tokenstore_temp;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret++;
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    }
    sql = "CREATE TABLE `tokenstore` ("
            "`ptoken`		text NOT NULL,"
            "`pid`			text NOT NULL,"
            "`bdate`		datetime NOT NULL,"
            "`dev`			int NOT NULL,"
            "`ex_type`		int NOT NULL,"
            "`note`			text,"
            "`keyid`		blob NOT NULL,"
            "`pkey`			text,"
            "`pstamp`		datetime,"
            "`pstatus`		int DEFAULT 0,"
            "`ABRecordID`	int,"
            "PRIMARY KEY(ptoken, keyid)"
            ");";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret++;
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    sql = "INSERT INTO tokenstore SELECT * FROM tokenstore_temp;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret++;
        sqlite3_finalize(sqlStatement);
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    sql = "DROP TABLE tokenstore_temp;";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK) {
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret++;
        sqlite3_finalize(sqlStatement);
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"Error while preparing statement. '%s'\n", sqlite3_errmsg(db)]];
    DEBUGMSG(@"Update Done.");
    if(ret==4) return YES;
    else return NO;
}

- (void)getConversationThreads: (NSMutableArray*)threads {
    if(!db || !threads) {
        [ErrorLogger ERRORDEBUG: @"database/threads is null."];
        return;
    }
    const char *sql = "SELECT receipt, cTime, count(msgid), count(unread), (CASE WHEN receipt IN (SELECT CAST(keyid AS TEXT) FROM (SELECT *, max(bdate) FROM (SELECT *, max(bdate) FROM tokenstore GROUP BY pid, dev) GROUP BY ptoken, dev ORDER BY pid COLLATE NOCASE DESC)) THEN 1 ELSE 0 END) as active FROM msgtable GROUP BY receipt order by cTime desc;";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        while(sqlite3_step(sqlStatement) == SQLITE_ROW) {
            MsgListEntry *listEntry = [MsgListEntry new];
            listEntry.keyid = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)];
            listEntry.lastSeen = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
            listEntry.messagecount = sqlite3_column_int(sqlStatement, 2);
            listEntry.unreadcount = sqlite3_column_int(sqlStatement, 3);
            listEntry.active = sqlite3_column_int(sqlStatement, 4) == 1;
            [threads addObject:listEntry];
        }
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Problem with prepare statement: %s", sql]];
    sqlite3_finalize(sqlStatement);
}

- (int)ThreadMessageCount:(NSString *)KEYID {
    int count = 0;
    if(!db || [KEYID length]==0) {
        [ErrorLogger ERRORDEBUG: @"database/KEYID is null."];
        return count;
    }
    const char *sql = "SELECT count(msgid) FROM msgtable WHERE receipt=?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(sqlStatement, 1, [KEYID UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement) == SQLITE_DONE)
            count = sqlite3_column_int(sqlStatement, 0);
        else
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while querying data. '%s'", sqlite3_errmsg(db)]];
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    sqlite3_finalize(sqlStatement);
    return count;
}

// Loads the messages exchanged with the keyId KEYID
- (NSArray *)loadMessagesExchangedWithKeyId:(NSString *)keyId {
    if(!db || [keyId length]==0) {
        [ErrorLogger ERRORDEBUG: @"database/keyId is null."];
        return nil;
    }
    
    NSMutableArray *tmparray = nil;
    int rownum = 0;
    const char *sql = "SELECT * FROM msgtable WHERE receipt=? ORDER BY rTime ASC";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)  {
        sqlite3_bind_text(sqlStatement, 1, [keyId UTF8String], -1, SQLITE_TRANSIENT);
        tmparray = [NSMutableArray array];
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            MsgEntry *amsg = [MsgEntry new];
            //1:msid
            int rawLen = sqlite3_column_bytes(sqlStatement, 0);
            if(rawLen>0) {
                amsg.msgid = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:rawLen];
            }
            // 2 cTime, might be null
            if(sqlite3_column_type(sqlStatement, 1)!=SQLITE_NULL) {
                amsg.cTime = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 1)];
            }
            // 3 rTime, might be null
            if(sqlite3_column_type(sqlStatement, 2)!=SQLITE_NULL) {
                amsg.rTime = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 2)];
            }
            //4 dir
            amsg.dir = sqlite3_column_int(sqlStatement, 3);
            // 5 token, might be null
            if(sqlite3_column_type(sqlStatement, 4)!=SQLITE_NULL) {
                amsg.token = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 4)];
            }
            // 6 sender, might be null
            if(sqlite3_column_type(sqlStatement, 5)!=SQLITE_NULL) {
                amsg.sender = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 5)];
            }
            // 7 msgbody
            if(sqlite3_column_type(sqlStatement, 6)!=SQLITE_NULL) {
                amsg.msgbody = [NSData dataWithBytes:(char*)sqlite3_column_blob(sqlStatement, 6) length:sqlite3_column_bytes(sqlStatement, 6)];
            }
            // 8 attach
            amsg.attach = sqlite3_column_int(sqlStatement, 7);
            // 9 fname text
            if(sqlite3_column_type(sqlStatement, 8)!=SQLITE_NULL) {
                amsg.fname = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 8)];
            }
            // 12 fext
            if(sqlite3_column_type(sqlStatement, 11)!=SQLITE_NULL) {
                amsg.fext = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 11)];
            }
            // 13 smsg boolean
            amsg.smsg = sqlite3_column_int(sqlStatement, 12);
            // 14 sfile boolean
            amsg.sfile = sqlite3_column_int(sqlStatement, 13);
            if(amsg.dir == ToMsg && (amsg.rTime == nil || amsg.rTime.length == 0)) {
                amsg.outgoingStatus = MessageOutgoingStatusFailed;
            }
            [tmparray addObject:amsg];
            rownum++;
        }
    }else
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Problem with prepare statement: %s", sql]];
    
    sqlite3_finalize(sqlStatement);
    return tmparray;
}

- (BOOL)markAllMessagesAsReadFromKeyId:(NSString *)keyId {
	
    if(!db || [keyId length]==0){
		[ErrorLogger ERRORDEBUG: @"database/keyId is null."];
		return NO;
	}
	BOOL ret = NO;
	sqlite3_stmt *sqlStatement;
    const char *sql = "UPDATE msgtable SET unread = NULL WHERE receipt = ?";
    
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind keyId
        sqlite3_bind_text(sqlStatement, 1, [keyId UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement) == SQLITE_DONE){
            ret = YES;
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while updating data. '%s'", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (FileInfo*)GetFileInfo: (NSData*)msgid
{
    if(!db || [msgid length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return nil;
    }
    FileInfo* finfo = nil;
    const char *sql = "SELECT fname, fext, fbody, sfile FROM msgtable where msgid = ?";
    sqlite3_stmt *sqlStatement = NULL;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_blob(sqlStatement, 1, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        if (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            finfo = [[FileInfo alloc]init];
            finfo.FName = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)];
            finfo.FExt = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
            finfo.FSize = 0;
            if(sqlite3_column_int(sqlStatement, 3)==0) {
                // decrypted file
                finfo.FSize = sqlite3_column_bytes(sqlStatement, 2);
            }
            else if(sqlite3_column_int(sqlStatement, 3)>=1)
            {
                // encrypted file
                int offset = 32;
                if(sqlite3_column_bytes(sqlStatement, 2)==offset)  // 32 bytes for hash + 4 bytes for size
                {
                    NSData *data = [NSData dataWithBytes:(char*)sqlite3_column_text(sqlStatement, 2)+offset length:4];
                    int size = 0;
                    [data getBytes: &size length: sizeof(size)];
                    finfo.FSize = size;
                }
            }
        }
        sqlite3_finalize(sqlStatement);
    }else {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return finfo;
}

- (BOOL)InsertMessage:(MsgEntry *)MSG {
    
    if(!db || !MSG) {
        [ErrorLogger ERRORDEBUG: @"database/MSG is null."];
        return NO;
    }
    
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "insert into msgtable (msgid, cTime, rTime, dir, token, sender, msgbody, attach, fname, fbody, ft, fext, smsg, sfile, note, receipt, thread_id, unread) Values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,0,?)";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // msgid
        sqlite3_bind_blob(sqlStatement, 1, [MSG.msgid bytes], (int)[MSG.msgid length], SQLITE_TRANSIENT);
        //2: cTime
        sqlite3_bind_text(sqlStatement, 2, [MSG.cTime UTF8String], -1, SQLITE_TRANSIENT);
        //3: rTime
        if(MSG.rTime) {
            sqlite3_bind_text(sqlStatement, 3, [MSG.rTime UTF8String], -1, SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(sqlStatement, 3);
        }
        //4: dir
        sqlite3_bind_int(sqlStatement, 4, MSG.dir);
        // 5: token, 6: sender (receiver when receiving messages)
        if(MSG.token) {
            sqlite3_bind_text(sqlStatement, 5, [MSG.token UTF8String], -1, SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(sqlStatement, 5);
        }
        if(MSG.sender) {
            sqlite3_bind_text(sqlStatement, 6, [MSG.sender UTF8String], -1, SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(sqlStatement, 6);
        }
        
        // 7: msgbody
        if(MSG.msgbody) {
            sqlite3_bind_blob(sqlStatement, 7, [MSG.msgbody bytes], (int)[MSG.msgbody length], SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(sqlStatement, 7);
        }
        
        // 8: attach, 9: fname, 10: fbody, 11: ft, 12: fext
        if(MSG.attach) {
            sqlite3_bind_int(sqlStatement, 8, 1);
            if(MSG.dir==ToMsg) {
                // fname/fdata
                sqlite3_bind_text(sqlStatement, 9, [MSG.fname UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_blob(sqlStatement, 10, [MSG.fbody bytes], (int)[MSG.fbody length], NULL);
                sqlite3_bind_null(sqlStatement, 11);
                sqlite3_bind_text(sqlStatement, 12, [MSG.fext UTF8String], -1, SQLITE_TRANSIENT);
            } else {
                // FromMsg
                sqlite3_bind_text(sqlStatement, 9, [MSG.fname UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_blob(sqlStatement, 10, [MSG.fbody bytes], (int)[MSG.fbody length], NULL);
                sqlite3_bind_text(sqlStatement, 11, [MSG.rTime UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(sqlStatement, 12, [MSG.fext UTF8String], -1, SQLITE_TRANSIENT);
            }
        } else {
            // for receive only
            sqlite3_bind_int(sqlStatement, 8, 0);
            // fname and fdata are null
            sqlite3_bind_null(sqlStatement,9);
            sqlite3_bind_null(sqlStatement,10);
            sqlite3_bind_null(sqlStatement,11);
            sqlite3_bind_null(sqlStatement,12);
        }
        
        // smsg, sfile
        sqlite3_bind_int(sqlStatement, 13, MSG.smsg);
        sqlite3_bind_int(sqlStatement, 14, MSG.sfile);
        
        // note
        if(MSG.face) {
            sqlite3_bind_text(sqlStatement, 15, [MSG.face UTF8String], -1, SQLITE_TRANSIENT);
        } else {
            sqlite3_bind_null(sqlStatement, 15);
        }
        // bind keyid
        sqlite3_bind_text(sqlStatement, 16, [MSG.keyid UTF8String], -1, SQLITE_TRANSIENT);
        // bind unread flag
        if(MSG.unread) {
            sqlite3_bind_int(sqlStatement, 17, 1);
        } else {
            sqlite3_bind_null(sqlStatement, 17);
        }
        if(sqlite3_step(sqlStatement)==SQLITE_DONE) {
            ret = YES;
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while inserting data. '%s'", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    return ret;
}

- (BOOL) UpdateFileBody: (NSData*)msgid DecryptedData:(NSData*)data
{
    if(!db || [data length]==0 || [msgid length]==0){
        [ErrorLogger ERRORDEBUG: @"database/msgid/data is null."];
        return NO;
    }
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "UPDATE msgtable SET fbody=?, sfile='N' where msgid = ?";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind msgbody
        sqlite3_bind_blob(sqlStatement, 1, [data bytes], (int)[data length], SQLITE_TRANSIENT);
        // bind msgid
        sqlite3_bind_blob(sqlStatement, 2, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement) == SQLITE_DONE){
            ret = YES;
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while updating data. '%s'", sqlite3_errmsg(db)]];
        }
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    sqlite3_finalize(sqlStatement);
    return ret;
}

- (BOOL) CheckMessage: (NSData*)msgid
{
    if(!db || [msgid length]==0){
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return NO;
    }
    BOOL exist = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "SELECT COUNT(*) FROM msgtable WHERE msgid=?";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind msgid
        sqlite3_bind_blob(sqlStatement, 1, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_DONE) {
            if(sqlite3_column_int(sqlStatement, 0)>0)
                exist = YES;
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while deleting data. '%s'", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    return exist;
}


- (BOOL) DeleteThread: (NSString*)keyid
{
    if(!db || [keyid length]==0) {
        [ErrorLogger ERRORDEBUG: @"database/keyid is null."];
        return NO;
    }
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "DELETE FROM msgtable WHERE receipt = ?";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        // bind msgid
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_DONE) {
            ret = YES;
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while deleting data. '%s'", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (BOOL) DeleteMessage: (NSData*)msgid
{
    if(!db || [msgid length]==0){
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return NO;
    }
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "DELETE FROM msgtable WHERE msgid=?";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind msgid
        sqlite3_bind_blob(sqlStatement, 1, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement) == SQLITE_DONE){
            ret = YES;
        }else{
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while deleting data. %s", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (BOOL) CloseDB
{
    if(!db) return YES;
    if(sqlite3_close(db)==SQLITE_OK)
    {
        return YES;
    }else{
        [ErrorLogger ERRORDEBUG: @"Unable to close the database."];
        return NO;
    }
}

@end
