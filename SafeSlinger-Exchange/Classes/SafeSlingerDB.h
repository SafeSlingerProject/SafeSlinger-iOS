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
#import <sqlite3.h>


#define DATABASE_NAME @"safeslinger-20120828.db"
#define DATABASE_TITLE @"safeslinger"
#define DATABASE_TIMESTR @"yyyy-MM-dd'T'HH:mm:ss'Z'"


/**
 Database Tables
    
 //
 table configs(2) :=
 {
    item_key varchar(50) primary key,   // configuration name
    item_value blob null                // configuration detail, raw bytes
 };
 
 table tokenstore(10) := 
 {
    ptoken text primary key,            // push token, unique, primary key
    pid text not null,                  // diaplayed username
    bdate datetime not null,            // exchange (or introduce) date
    dev int not null,                   // device type, 0 for Android, 1 for iOS now
    ex_type int not null,               // exchange type, 0 for exchange, 1 for introduction
    note text null,                     // current for photo
    keyid blob null,                    // unique key id (sha3 hash of public keys)
    pkey text null,                     // base64 encoding public keys
    pstamp datetime null,               // key geneartion date
    pstatus int default(0),             // 0 active, -1 unknown, 1 inactive (preserved now)
 };
 
 table msgtable(17) := {
    msgid blob primary key,             // msgid, 32 bytes
    cTime datetime null,                // timestamp for create/receive this message
    rTime datetime null,                // timestamp for decrypt this message
    dir   boolean not null,             // indicate msg is from or to
    token text null,                    // sender pushtoken
    sender text null,                   // sender display name 
    msgbody blob null,                  // msg body, pure text (encrypted or unecrypted)
    attach boolean null,                // indicate msg has attach(1) or not(0)
    fname text null,                    // filename, pure text
    fbody blob null,                    // file body, binary data
    ft datetime null,                   // file time stamp (preserved now)
    fext text null,                     // file MIME type
    smsg boolean not null,              // encrypted or decrypted msg
    sfile boolean not null,             // encrypted or decrypted file
    note text null                      // current for photo
    receipt text null                   // preserved now
    thread_id int default(-1)           // used to distinguish old or new thread
 };
*/

typedef enum ProtectType {
    Decrypted = 0,
    Encrypted
}ProtectType;

typedef enum ExchangeType {
    Exchanged = 0,
    Introduced
}ExchangeType;

typedef enum DirectionType {
    ToMsg = 1,
    FromMsg
}DirectionType;

@interface MsgListEntry : NSObject
{
    NSString *username, *token, *lastSeen;
    int messagecount, ciphercount;
}

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) NSString *lastSeen;
@property (nonatomic, readwrite) int messagecount;
@property (nonatomic, readwrite) int ciphercount;

@end

@interface MsgEntry : NSObject 
{
    // message indicator
    NSData *msgid;      // primary key, old version is sha1, new version is sha3
    NSString *cTime;      // for Send Time, GMT String
    NSString *rTime;      // for Received Time, GMT String
    int dir;            // send (1), receive (0)
    
    // receipent indicator
    NSString *token;    // sender/receiver pushtoken
    NSString *sender;   // sender/receiver display name
    NSString *face;     // sender/receiver facephoto
    
    // Message part
    int smsg;           // encrypted(1) or decrypted(0) msg
    NSData *msgbody;    // msg body, could be encrypted or unencrypted
    
    // File Part
    int attach;         // has attachment (1) or null (0)
    int sfile;          // encrypted(1) or decrypted(0) file, >1 indicates email attachment
    NSString *fname;    // filename
    NSString *fext;     // file extension, MIME type
    NSData *fbody;      // file raw data
}

@property (nonatomic, retain) NSData *msgid;
@property (nonatomic, retain) NSString *cTime;
@property (nonatomic, retain) NSString *rTime;
@property (nonatomic, readwrite) int dir;
@property (nonatomic, retain) NSString *token;
@property (nonatomic, retain) NSString *sender;
@property (nonatomic, retain) NSString *face;
@property (nonatomic, readwrite) int smsg;
@property (nonatomic, retain) NSData *msgbody;
@property (nonatomic, readwrite) int attach;
@property (nonatomic, readwrite) int sfile;
@property (nonatomic, retain) NSString *fname;
@property (nonatomic, retain) NSData *fbody;
@property (nonatomic, retain) NSString *fext;

-(MsgEntry*)initPlainTextMessage: (NSData*)newmsgid UserName:(NSString*)uname Token:(NSString*)tokenstr Message:(NSString*)message Photo:(NSString*)encodePhoto FileName:(NSString*)File FileType:(NSString*)MimeType FIleData:(NSData*)FileRaw;
-(MsgEntry*)initSecureMessage: (NSData*)newmsgid UserName:(NSString*)uname Token:(NSString*)tokenstr Message:(NSData*)cipher SecureM:(int)mflag SecureF:(int)fflag;

@end

@interface FileInfo : NSObject
{
    NSString *FName, *FExt;
    int FSize;
}

@property (nonatomic, retain) NSString *FName, *FExt;
@property (nonatomic, readwrite) int FSize;
@end

@interface SafeSlingerDB : NSObject
{
    sqlite3 *db;
}

// basic database operation
- (BOOL)LoadDBFromStorage: (NSString*)specific_path;
- (BOOL)SaveDBToStorage;
- (BOOL)TrimTable: (NSString*)table_name;

// for secure message (Text part)
- (NSArray*)LoadMessageThreads;
// Display Messages for separate threads
- (NSArray*)LoadThreadMessage: (NSString*)token;
// Get Message Count for separate threads
- (int)ThreadMessageCount: (NSString*)token;
// Get Ciphertext Count for separate threads
- (int)ThreadCipherCount: (NSString*)token;

- (BOOL)InsertMessage: (MsgEntry*)MSG;
- (BOOL)DeleteMessage: (NSData*)msgid;
- (BOOL)CheckMessage: (NSData*)msgid;
- (BOOL)UpdateMessage: (NSData*)msgid NewMSG:(NSString*)decrypted_message Time:(NSString*)GMTTime User:(NSString*)Name Token:(NSString*)TID Photo:(NSString*)UserPhoto;

- (BOOL)UpdateMessagesWithToken: (NSString*)oldKeyID ReplaceUsername:(NSString*)username ReplaceToken:(NSString*)token;
- (void)UpdateUndefinedThread;

- (BOOL)DeleteThread: (NSString*)thread_token;

// Query function for msg Table
- (NSData*)QueryInMsgTableByMsgID: (NSData*)MSGID Field:(NSString*)FIELD;

// for secure message (File part)
- (FileInfo*)GetFileInfo: (NSData*)msgid;
- (BOOL)UpdateFileBody: (NSData*)msgid DecryptedData:(NSData*)data;
- (BOOL)UpdateFileInfo: (NSData*)msgid filename:(NSString*)fname filetype: (NSString*)ext Time:(NSString*)GMTTime fileinfo:(NSData*)finfo;

// for configuration table, store some useful information
- (BOOL)InsertOrUpdateConfig: (NSData*)value withTag:(NSString*)tag;
- (NSData*)GetConfig: (NSString*)tag;
- (BOOL)RemoveConfigTag:(NSString*)tag;

// for recipients
- (NSArray*)LoadRecipients:(BOOL)ExchangeOnly;
- (NSArray*)LoadRecentRecipients:(BOOL)ExchangeOnly;
- (BOOL)RemoveRecipient: (NSString*)RecipientToken;
- (NSString*)SearchRecipient:(NSString*)RecipientToken;
- (BOOL)RegisterToken: (NSString*)token User:(NSString*)username Dev:(int)type Photo:(NSString*)UserPhoto KeyData: (NSData*)keyelement ExchangeOrIntroduction: (BOOL)flag;
- (BOOL)UpdateToken: (NSString*)token User:(NSString*)username Dev:(int)type Photo:(NSString*)UserPhoto KeyData: (NSData*)keyelement ExchangeOrIntroduction: (BOOL)flag;

// Utlilty functions
- (NSString*)GetRawKeyByToken: (NSString*)RecipientToken;
- (int)GetEXTypeByToken: (NSString*)RecipientToken;
- (int)GetDEVTypeByToken: (NSString*)RecipientToken;

// Query functions for Token Table
- (NSString*)QueryStringInTokenTableByKeyID: (NSString*)KEYID Field:(NSString*)FIELD;
- (NSString*)QueryStringInTokenTableByToken: (NSString*)TOKEN Field:(NSString*)FIELD;

@end
