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

#import "UniversalDB.h"
#import "ErrorLogger.h"
#import "SafeSlingerDB.h"
#import "Utility.h"
#import "SSEngine.h"
#import "Config.h"

@implementation UniversalDB

// private method
- (BOOL) LoadDBFromStorage
{
    BOOL success = YES;
	@try{
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error;
        NSString *db_path = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent: @"universal.db"];
        
        if (![fileManager fileExistsAtPath:db_path])
        {
            // The writable database does not exist, so copy the default to the appropriate location.
            NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"universal.db"];
            if (![fileManager copyItemAtPath:defaultDBPath toPath:db_path error:&error])
            {
                [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Failed to create writable database file with message '%@'.", [error localizedDescription]]];
                success = NO;
            }
        }
        
        if(!(sqlite3_open([db_path UTF8String], &db) == SQLITE_OK)){
            [ErrorLogger ERRORDEBUG:@"ERROR: Unable to open database."];
            success = NO;
        }
        
    }@catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: An exception occured, %@", [exception reason]]];
        success = NO;
    }@finally {
        return success;
    }
}

- (BOOL)CheckMessage: (NSData*)msgid
{
    if(!db || [msgid length]==0){
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return NO;
    }
    
    BOOL exist = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "SELECT COUNT(*) FROM ciphertable WHERE msgid=?";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind msgid
        sqlite3_bind_blob(sqlStatement, 1, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement) == SQLITE_OK){
            if(sqlite3_column_int(sqlStatement, 0)>0)
                exist = YES;
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return exist;
}

- (BOOL)createNewEntry:(MsgEntry *)msg {
    
    if(!db || !msg){
        [ErrorLogger ERRORDEBUG: @"database/msg is null."];
        return NO;
    }
    
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "insert into ciphertable (msgid, cTime, keyid, cipher) Values (?,?,?,?)";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        const NSString* unknownFlag = @"UNDEFINED";
        // msgid
        sqlite3_bind_blob(sqlStatement, 1, [msg.msgid bytes], (int)[msg.msgid length], SQLITE_TRANSIENT);
        // time
        sqlite3_bind_text(sqlStatement, 2, [msg.cTime UTF8String], -1, SQLITE_TRANSIENT);
        // unknown for keyid
        sqlite3_bind_text(sqlStatement, 3, [unknownFlag UTF8String], -1, SQLITE_TRANSIENT);
        // empty for cipher
        sqlite3_bind_null(sqlStatement, 4);
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret = YES;
        else
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while inserting data. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
        
    return ret;
}

- (BOOL)updateMessageEntry:(MsgEntry *)msg {
	
    if(!db || !msg)
    {
		[ErrorLogger ERRORDEBUG: @"database/msg is null."];
		return NO;
	}
	
	BOOL ret = NO;
    // update entry
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "UPDATE ciphertable SET keyid=?, cipher=? WHERE msgid=?";
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        sqlite3_bind_text(sqlStatement, 1, [msg.keyid UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_blob(sqlStatement, 2, [msg.msgbody bytes], (int)[msg.msgbody length], SQLITE_TRANSIENT);
        sqlite3_bind_blob(sqlStatement, 3, [msg.msgid bytes], (int)[msg.msgid length], SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement) == SQLITE_DONE)
            ret = YES;
        else
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while updating data. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
    }
    return ret;
}

- (NSArray*)GetEntriesForKeyID: (NSString*)keyid WithToken:(NSString*)token WithName:(NSString*)name
{
    if(!db || [keyid length]==0 || [token length]==0 || [name length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/keyid/token/name is null."];
        return nil;
    }
	
    NSMutableArray *Ciphers = nil;
    Ciphers = [NSMutableArray arrayWithCapacity:0];
    const char *sql = sql = "SELECT * FROM ciphertable WHERE keyid=?";
    sqlite3_stmt *sqlStatement;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            NSData *nonce = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:sqlite3_column_bytes(sqlStatement, 0)];
            NSData *cipher = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 3) length:sqlite3_column_bytes(sqlStatement, 3)];
            MsgEntry* newmsg = [[MsgEntry alloc]InitIncomingMessage:nonce UserName:name Token:token Message:cipher SecureM:Encrypted SecureF:Decrypted];
            newmsg.rTime = newmsg.cTime = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
            [Ciphers addObject:newmsg];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Problem with prepare statement: %s", sql]];
        Ciphers = nil;
    }
    return Ciphers;
}

- (int)updateThreadEntries:(NSMutableArray *)threadlist {
    
    if(!db || !threadlist) {
        [ErrorLogger ERRORDEBUG: @"database/threadlist is null."];
        return -1;
    }
    
    int NumMessage = 0;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "SELECT keyid, cTime, count(msgid) FROM ciphertable GROUP BY keyid order by cTime desc;";
		
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        while (sqlite3_step(sqlStatement) == SQLITE_ROW) {
            NSString* keyid = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)];
            DEBUGMSG(@"keyid = %@", keyid);
            
            MsgListEntry *listEntry;
            
            for(int i = 0; i < threadlist.count; i++) {
                if([keyid isEqualToString:((MsgListEntry *)threadlist[i]).keyid]) {
                    listEntry = threadlist[i];
                    break;
                }
            }
            
            if(listEntry) {
                // update information
                DEBUGMSG(@"modify entry thread.");
                NSString *date1 = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
                // compare dates
                if ([UtilityFunc CompareDate:date1 Target:listEntry.lastSeen] == NSOrderedDescending) {
                    listEntry.lastSeen = date1;
                    [threadlist removeObject:listEntry];
                    [self insertMessageListEntry:listEntry orderedByDateDescendingInArray:threadlist];
                }
                listEntry.ciphercount = sqlite3_column_int(sqlStatement, 2);
                NumMessage += listEntry.ciphercount;
                listEntry.messagecount += listEntry.ciphercount;
            } else {
                // create entry
                DEBUGMSG(@"create new entry thread.");
                listEntry = [[MsgListEntry alloc]init];
                listEntry.keyid = keyid;
                listEntry.lastSeen = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
                listEntry.messagecount = listEntry.ciphercount = sqlite3_column_int(sqlStatement, 2);
                NumMessage += listEntry.ciphercount;
                [self insertMessageListEntry:listEntry orderedByDateDescendingInArray:threadlist];
            }
        } // end of while
        
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while prepaing statement. '%s'", sqlite3_errmsg(db)]];
    }
        
    sqlite3_finalize(sqlStatement);
    return NumMessage;
}

- (void)insertMessageListEntry:(MsgListEntry *)listEntry orderedByDateDescendingInArray:(NSMutableArray *)threadList {
	int index = 0;
	BOOL inserted = false;
	
	while(index < threadList.count && !inserted) {
		MsgListEntry *entry = threadList[index];
		if([UtilityFunc CompareDate:listEntry.lastSeen Target:entry.lastSeen] == NSOrderedDescending) {
			[threadList insertObject:listEntry atIndex:index];
			inserted = true;
		}
		index++;
	}
	
	if(!inserted) {
		// if date is smaller than any other thread, insert at the end
		[threadList addObject:listEntry];
	}
}

- (int)ThreadCipherCount: (NSString*)keyid
{
    int count = 0;
    if(!db || [keyid length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return count;
    }
    const char *sql = "SELECT count(msgid) FROM ciphertable WHERE keyid=?";
    sqlite3_stmt *sqlStatement = NULL;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_OK)
        {
            count = sqlite3_column_int(sqlStatement, 0);
        }else{
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while querying data. '%s'", sqlite3_errmsg(db)]];
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while prepaing statement. '%s'", sqlite3_errmsg(db)]];
    }
    return count;
}

- (BOOL)DeleteMessage: (NSData*)msgid
{
    if(!db || [msgid length]==0){
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return NO;
    }
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement;
    const char *sql = "DELETE FROM ciphertable WHERE msgid=?";
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
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while prepaing statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (NSArray*)LoadThreadMessage: (NSString*)keyid
{
    NSMutableArray *tmparray = [NSMutableArray arrayWithCapacity:0];
    if(!db || [keyid length]==0)
    {
        [ErrorLogger ERRORDEBUG: @"database/keyid is null."];
        return tmparray;
    }
    int rownum = 0;
    const char *sql = "SELECT * FROM ciphertable WHERE keyid=? ORDER BY cTime ASC";
    sqlite3_stmt *sqlStatement = NULL;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK)
    {
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            if(sqlite3_column_type(sqlStatement, 0) == SQLITE_BLOB
               && sqlite3_column_bytes(sqlStatement, 0) > 0
               && sqlite3_column_type(sqlStatement, 1) == SQLITE_TEXT
               && sqlite3_column_type(sqlStatement, 3) == SQLITE_BLOB
               && sqlite3_column_bytes(sqlStatement, 3) > 0)
            {
                MsgEntry *amsg = [[MsgEntry alloc]init];
                int id_len = sqlite3_column_bytes(sqlStatement, 0);
                amsg.msgid = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:id_len];
                amsg.cTime = amsg.rTime = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 1)];
                amsg.dir = FromMsg;
                amsg.keyid = keyid;
                int cipher_len = sqlite3_column_bytes(sqlStatement, 3);
                char* output = (char*)sqlite3_column_blob(sqlStatement, 3);
                amsg.msgbody = [NSData dataWithBytes:output length:cipher_len];
                amsg.smsg = amsg.sfile = Encrypted;
                [tmparray addObject:amsg];
                rownum++;
            }
        }
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while prepaing statement. '%s'", sqlite3_errmsg(db)]];
    }
    return tmparray;
}

- (NSArray *)getEncryptedMessages {
    
    NSMutableArray *tmparray = nil;
	if(!db) {
		[ErrorLogger ERRORDEBUG: @"database is null."];
		return tmparray;
	}
	
	const char *sql = "SELECT * FROM ciphertable WHERE cipher IS NOT NULL ORDER BY cTime ASC";
    sqlite3_stmt *sqlStatement = NULL;
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK) {
        tmparray = [NSMutableArray array];
        while (sqlite3_step(sqlStatement) == SQLITE_ROW) {
            if(sqlite3_column_type(sqlStatement, 0) == SQLITE_BLOB
               && sqlite3_column_bytes(sqlStatement, 0) > 0
               && sqlite3_column_type(sqlStatement, 1) == SQLITE_TEXT
               && sqlite3_column_type(sqlStatement, 2) == SQLITE_TEXT
               && sqlite3_column_type(sqlStatement, 3) == SQLITE_BLOB
               && sqlite3_column_bytes(sqlStatement, 3) > 0
               )
            {
                MsgEntry *amsg = [[MsgEntry alloc]init];
                amsg.msgid = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:sqlite3_column_bytes(sqlStatement, 0)];
                amsg.cTime = amsg.rTime = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 1)];
                amsg.keyid = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 2)];
                amsg.msgbody = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 3) length:sqlite3_column_bytes(sqlStatement, 3)];
                amsg.smsg = amsg.sfile = Encrypted;
                amsg.dir = FromMsg;
                [tmparray addObject:amsg];
            }
        } // end of while
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while prepaing statement. '%s'", sqlite3_errmsg(db)]];
    }
    return tmparray;
}

- (BOOL) DeleteThread: (NSString*)keyid
{
    if(!db || [keyid length]==0){
        [ErrorLogger ERRORDEBUG: @"database/msgid is null."];
        return NO;
    }
    BOOL ret = NO;
    sqlite3_stmt *sqlStatement = NULL;
    const char *sql = "DELETE FROM ciphertable WHERE keyid=?";
		
    if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) == SQLITE_OK){
        // bind msgid
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        if(sqlite3_step(sqlStatement)==SQLITE_DONE)
            ret = YES;
        else
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
        sqlite3_finalize(sqlStatement);
    }else{
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while prepaing statement. '%s'", sqlite3_errmsg(db)]];
    }
    return ret;
}

- (BOOL) CloseDB
{
    if(!db)
        return YES;
	if(sqlite3_close(db)==SQLITE_OK)
    {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Unable to close the database: %s", sqlite3_errmsg(db)]];
        return YES;
    }else
        return NO;
}

@end
