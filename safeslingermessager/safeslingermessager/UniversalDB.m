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
    if(db==nil||msgid==nil){
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return NO;
    }
    
    BOOL exist = NO;
    @try {
        
        sqlite3_stmt *sqlStatement;
        const char *sql = "SELECT COUNT(*) FROM ciphertable WHERE msgid=?";
        
        if(sqlite3_prepare_v2(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
        }
        
        // bind msgid
        sqlite3_bind_blob(sqlStatement, 1, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        
        if (sqlite3_step(sqlStatement) == SQLITE_ERROR) {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while querying data. '%s'", sqlite3_errmsg(db)]];
        } else {
            if(sqlite3_column_int(sqlStatement, 0)>0) exist = YES;
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
        }
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: An exception occured, %@", [exception reason]]];
    }
    @finally {
        return exist;
    }
}

- (BOOL)CreateNewEntry: (NSData*)msgnonce
{
    DEBUGMSG(@"CreateNewEntry");
    if(db==nil){
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return NO;
    }
    
    BOOL ret = YES;
    @try {
        
        sqlite3_stmt *sqlStatement;
        const char *sql = "insert into ciphertable (msgid, cTime, keyid, cipher) Values (?,?,?,?);";
        if(sqlite3_prepare_v2(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        const NSString* unknownFlag = @"UNDEFINED";
        
        // msgid
        sqlite3_bind_blob(sqlStatement, 1, [msgnonce bytes], (int)[msgnonce length], SQLITE_TRANSIENT);
        // time
        sqlite3_bind_text(sqlStatement, 2, [[NSString GetGMTString:DATABASE_TIMESTR]UTF8String], -1, SQLITE_TRANSIENT);
        // unknown for keyid
        sqlite3_bind_text(sqlStatement, 3, [unknownFlag UTF8String], -1, SQLITE_TRANSIENT);
        // empty for cipher
        sqlite3_bind_null(sqlStatement, 4);
        
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
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured: %@", [exception reason]]];
        ret = NO;
    }
    @finally {
        return ret;
    }
}

- (NSArray*)GetEntriesForKeyID: (NSString*)keyid WithToken:(NSString*)token WithName:(NSString*)name
{
    if(db==nil)
    {
        [ErrorLogger ERRORDEBUG:@"ERROR: DB Object is null or input is null."];
        return nil;
    }
    
    NSMutableArray *Ciphers = nil;
    @try {
        
        Ciphers = [NSMutableArray arrayWithCapacity:0];
        const char *sql = NULL;
        sqlite3_stmt *sqlStatement;
        
        sql = "SELECT * FROM ciphertable WHERE keyid=?;";
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK)
        {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Problem with prepare statement: %s", sql]];
            Ciphers = nil;
        }
        
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            
            NSData *nonce = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:sqlite3_column_bytes(sqlStatement, 0)];
            NSData *cipher = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 3) length:sqlite3_column_bytes(sqlStatement, 3)];
            
            MsgEntry* newmsg = [[MsgEntry alloc]InitIncomingMessage:nonce UserName:name Token:token Message:cipher SecureM:Encrypted SecureF:Decrypted];
            
            newmsg.rTime = newmsg.cTime = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
            [Ciphers addObject:newmsg];
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
        }
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured: %@", [exception reason]]];
        Ciphers = nil;
    }
    @finally {
        return Ciphers;
    }
}

- (int) UpdateThreadEntries: (NSMutableDictionary*) threadlist
{
    if(db==nil&&threadlist==nil)
    {
        [ErrorLogger ERRORDEBUG:@"ERROR: DB Object is null or input is null."];
        return -1;
    }
    
    int NumMessage = 0;
    @try {
        const char *sql = NULL;
        sqlite3_stmt *sqlStatement;
        
        sql = "SELECT keyid, cTime, count(msgid) FROM ciphertable GROUP BY keyid order by cTime desc;";
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK)
        {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Problem with prepare statement: %s", sql]];
        }
        
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            
            NSString* keyid = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 0)];
            DEBUGMSG(@"keyid = %@", keyid);
            
            MsgListEntry *listEnt = [threadlist objectForKey: keyid];
            if(listEnt)
            {
                // update information
                DEBUGMSG(@"modify entry thread.");
                NSString *date1 = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
                NSString *date2 = listEnt.lastSeen;
                // compare dates
                switch ([UtilityFunc CompareDate:date1 Target:date2]) {
                    case NSOrderedAscending:
                        listEnt.lastSeen = date2;
                        break;
                    case NSOrderedSame:
                    case NSOrderedDescending:
                        listEnt.lastSeen = date1;
                        break;
                    default:
                        break;
                }
                
                listEnt.ciphercount = sqlite3_column_int(sqlStatement, 2);
                NumMessage += listEnt.ciphercount;
                listEnt.messagecount += listEnt.ciphercount;
            }else{
                // create entry
                DEBUGMSG(@"create new entry thread.");
                listEnt = [[MsgListEntry alloc]init];
                listEnt.keyid = keyid;
                listEnt.lastSeen = [NSString stringWithUTF8String:(char*)sqlite3_column_text(sqlStatement, 1)];
                listEnt.messagecount = listEnt.ciphercount = sqlite3_column_int(sqlStatement, 2);
                NumMessage += listEnt.ciphercount;
                [threadlist setObject:listEnt forKey:keyid];
            }
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
            NumMessage = -1;
        }
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured: %@", [exception reason]]];
        NumMessage = -1;
    }
    @finally {
        return NumMessage;
    }
}

- (BOOL)UpdateEntryWithCipher: (NSData*)msgnonce Cipher:(NSData*)newcipher
{
    if(db==nil){
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return NO;
    }
    
    BOOL ret = YES;
    @try {
        
        NSString *keyid = [SSEngine ExtractKeyID: newcipher];
        NSData *cipher = [NSData dataWithBytes:[newcipher bytes]+LENGTH_KEYID length:[newcipher length]-LENGTH_KEYID];
        
        // update entry
        sqlite3_stmt *sqlStatement;
        const char *sql = "UPDATE ciphertable SET keyid=?, cipher=? where msgid=?";
        if(sqlite3_prepare_v2(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        sqlite3_bind_text(sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_blob(sqlStatement, 2, [cipher bytes], (int)[cipher length], SQLITE_TRANSIENT);
        sqlite3_bind_blob(sqlStatement, 3, [msgnonce bytes], (int)[msgnonce length], SQLITE_TRANSIENT);
        
        if(SQLITE_DONE != sqlite3_step(sqlStatement)){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"Error while updating data. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
            ret = NO;
        }
        
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured: %@", [exception reason]]];
        ret = NO;
    }
    @finally {
        return ret;
    }
}

- (int)ThreadCipherCount: (NSString*)KEYID
{
    if(db==nil||KEYID==nil)
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return 0;
    }
    
    int count = 0;
    @try {
        const char *sql = "SELECT count(msgid) FROM ciphertable WHERE keyid=?";
        sqlite3_stmt *sqlStatement;
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK)
        {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Problem with prepare statement: %s", sql]];
        }
        
        sqlite3_bind_text(sqlStatement, 1, [KEYID UTF8String], -1, SQLITE_TRANSIENT);
        
        if (sqlite3_step(sqlStatement) == SQLITE_ERROR) {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error while querying data. '%s'", sqlite3_errmsg(db)]];
        } else {
            count = sqlite3_column_int(sqlStatement, 0);
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
            count = 0;
        }
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured: %@", [exception reason]]];
        count = 0;
    }
    @finally {
        return count;
    }
}

- (BOOL)DeleteMessage: (NSData*)msgid
{
    if(db==nil||msgid==nil){
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return NO;
    }
    
    BOOL ret = YES;
    @try {
        
        sqlite3_stmt *sqlStatement;
        const char *sql = "DELETE FROM ciphertable WHERE msgid=?";
        
        if(sqlite3_prepare_v2(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        // bind msgid
        sqlite3_bind_blob(sqlStatement, 1, [msgid bytes], (int)[msgid length], SQLITE_TRANSIENT);
        
        if(SQLITE_DONE != sqlite3_step(sqlStatement)){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while deleting data. '%s'", sqlite3_errmsg(db)]];
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

- (NSArray*)LoadThreadMessage: (NSString*)KEYID
{
    if(db==nil||KEYID==nil)
    {
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return nil;
    }
    
    NSMutableArray *tmparray = nil;
    @try {
        
        int rownum = 0;
        tmparray = [NSMutableArray arrayWithCapacity:0];
        
        const char *sql = "SELECT * FROM ciphertable WHERE keyid=? ORDER BY cTime ASC";
        sqlite3_stmt *sqlStatement;
        if(sqlite3_prepare(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK)
        {
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Problem with prepare statement: %s", sql]];
            tmparray = nil;
        }
        
        sqlite3_bind_text(sqlStatement, 1, [KEYID UTF8String], -1, SQLITE_TRANSIENT);
        
        char* output = NULL;
        while (sqlite3_step(sqlStatement)==SQLITE_ROW) {
            
            MsgEntry *amsg = [[MsgEntry alloc]init];
            
            int rawLen = sqlite3_column_bytes(sqlStatement, 0);
            if(rawLen>0) {
                amsg.msgid = [NSData dataWithBytes:sqlite3_column_blob(sqlStatement, 0) length:rawLen];
            }
            
            if(sqlite3_column_type(sqlStatement, 1)!=SQLITE_NULL)
            {
                amsg.cTime = amsg.rTime = [NSString stringWithUTF8String:(char *)sqlite3_column_text(sqlStatement, 1)];
            }
            
            amsg.dir = FromMsg;
            amsg.keyid = KEYID;
            
            // cipher
            if(sqlite3_column_type(sqlStatement, 3)!=SQLITE_NULL)
            {
                int rawLen = sqlite3_column_bytes(sqlStatement, 3);
                DEBUGMSG(@"cipher size = %d", rawLen);
                if(rawLen>0) {
                    output = (char*)sqlite3_column_blob(sqlStatement, 3);
                    amsg.msgbody = [NSData dataWithBytes:output length:rawLen];
                }
            }
            
            // 13 smsg boolean
            amsg.smsg = amsg.sfile = Encrypted;
            
            [tmparray addObject:amsg];
            amsg = nil;
            rownum++;
        }
        
        if(sqlite3_finalize(sqlStatement) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG: @"ERROR: Problem with finalize statement"];
        }
    }
    @catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"An exception occured: %@", [exception reason]]];
        tmparray = nil;
    }
    @finally {
        return tmparray;
    }
}

- (BOOL)DeleteThread: (NSString*)keyid
{
    if(db==nil){
        [ErrorLogger ERRORDEBUG: @"ERROR: DB Object is null or Input is null."];
        return NO;
    }
    
    BOOL ret = YES;
    @try {
        
        sqlite3_stmt *sqlStatement;
        const char *sql = "DELETE FROM ciphertable WHERE keyid=?";
        
        if(sqlite3_prepare_v2(db, sql, -1, &sqlStatement, NULL) != SQLITE_OK){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while creating statement. '%s'", sqlite3_errmsg(db)]];
            ret = NO;
        }
        
        // bind msgid
        sqlite3_bind_text (sqlStatement, 1, [keyid UTF8String], -1, SQLITE_TRANSIENT);
        
        if(SQLITE_DONE != sqlite3_step(sqlStatement)){
            [ErrorLogger ERRORDEBUG:[NSString stringWithFormat:@"Error while deleting data. '%s'", sqlite3_errmsg(db)]];
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

- (BOOL) CloseDB
{
    if(db==nil) return YES;
	@try{
        if(sqlite3_close(db)!=SQLITE_OK)
        {
            [ErrorLogger ERRORDEBUG: @"ERROR: Unable to close the database."];
            DEBUGMSG(@"ERROR: Unable to close the database.");
        }else
            return YES;
    }@catch (NSException *exception) {
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: An exception occured in SaveDBToStorage: %@", [exception reason]]];
        DEBUGMSG(@"ERROR: An exception occured in SaveDBToStorage: %@", [exception reason]);
        return NO;
    }
}

@end
