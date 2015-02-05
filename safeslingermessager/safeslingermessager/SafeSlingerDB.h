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

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "ContactSelectView.h"

#define DATABASE_NAME @"safeslinger-20120828"
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
    ptoken text not null,               // push token, should be unique per device
    pid text not null,                  // diaplayed username
    bdate datetime not null,            // exchange (or introduce) date
    dev int not null,                   // device type, 0 for Android, 1 for iOS now
    ex_type int not null,               // exchange type, 0 for exchange, 1 for introduction
    note text null,                     // current for photo
    keyid blob primary key,             // unique key id (sha3 hash of public keys)
    pkey text null,                     // base64 encoding public keys
    pstamp datetime null,               // key geneartion date
    pstatus int default(0),             // 0 active, -1 unknown, 1 inactive (preserved now)
 };
 
 table msgtable(17) := {
    msgid blob primary key,             // msgid, 32 bytes
    cTime datetime null,                // timestamp for create/receive this message
    rTime datetime null,                // time of decryption of received message or send of sent message
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
    note text null                      //
    receipt text null                   // pcurrent for keyid
    thread_id int default(-1)           // used to distinguish old or new thread
 };
*/

typedef enum ProtectType {
    Drafted = -1,
    Decrypted = 0,
    Encrypted
}ProtectType;

typedef enum DirectionType {
    ToMsg = 1,
    FromMsg
}DirectionType;

typedef enum {
	MessageOutgoingStatusSent = 0,
	MessageOutgoingStatusSending,
	MessageOutgoingStatusFailed
} MessageOutgoingStatus;

@interface MsgListEntry : NSObject

@property (nonatomic, strong) NSString *keyid;
@property (nonatomic, strong) NSString *lastSeen;
@property (nonatomic, readwrite) int messagecount;
@property (nonatomic, readwrite) int ciphercount;
@property (nonatomic, readwrite) BOOL active;

@end

@interface MsgEntry : NSObject 

// message indicator
@property (nonatomic, strong) NSData *msgid;    // primary key, old version is sha1, new version is sha3
@property (nonatomic, strong) NSString *cTime;  // for creation Time, GMT String
// for Received/Sent Time, GMT String
// When this message was received, rTime is the time of decryption
// When this message was sent, rTime is the time it was sent, or null if failed to send
@property (nonatomic, strong) NSString *rTime;
@property (nonatomic, readwrite) DirectionType dir;       // send (1), receive (0)
@property (nonatomic, readwrite) MessageOutgoingStatus outgoingStatus;	// the status of the message
// receipent indicator
@property (nonatomic, strong) NSString *token;  // sender/receiver pushtoken
@property (nonatomic, strong) NSString *sender; // sender/receiver display name
@property (nonatomic, strong) NSString *face;   // sender/receiver facephoto
@property (nonatomic, strong) NSString *keyid;   // sender/receiver keyid
@property (nonatomic, readwrite) ProtectType smsg;      // encrypted(1) or decrypted(0) msg
// attachment indicator
@property (nonatomic, strong) NSData *msgbody;  // msg body, could be encrypted or unencrypted
@property (nonatomic, readwrite) int attach;    // has attachment (1) or null (0)
@property (nonatomic, readwrite) ProtectType sfile;     // encrypted(1) or decrypted(0) file,
@property (nonatomic, strong) NSString *fname;  // filename
@property (nonatomic, strong) NSData *fbody;    // file extension, MIME type
@property (nonatomic, strong) NSString *fext;   // file raw data


-(MsgEntry*)InitOutgoingMsg: (NSData*)newmsgid Recipient:(ContactEntry*)user Message:(NSString*)message FileName:(NSString*)File FileType:(NSString*)MimeType FileData:(NSData*)FileRaw;
-(MsgEntry*)InitIncomingMessage: (NSData*)newmsgid UserName:(NSString*)uname Token:(NSString*)tokenstr Message:(NSData*)cipher SecureM:(int)mflag SecureF:(int)fflag;

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

- (BOOL)PatchForTokenStoreTable;
- (BOOL)patchForContactsFromAddressBook;

// basic database operation
- (BOOL)LoadDBFromStorage:(NSString *)specific_path;
- (BOOL)TrimTable:(NSString *)table_name;
- (void)DumpUsage;
- (BOOL)CloseDB;

// for recipients
- (NSArray *)LoadRecipients:(BOOL)ExchangeOnly;
- (NSArray *)LoadRecentRecipients:(BOOL)ExchangeOnly;
- (ContactEntry *)loadContactEntryWithKeyId:(NSString *)keyId;
- (BOOL)updateContactDetails:(ContactEntry *)contact;
- (BOOL)RemoveRecipient:(NSString *)KEYID;
- (BOOL)addNewRecipient:(ContactEntry *)contact;

// for Message Thread
- (NSMutableArray *)getConversationThreads;
- (NSArray *)loadMessagesExchangedWithKeyId:(NSString *)keyId;
- (int)ThreadMessageCount:(NSString *)KEYID;
- (BOOL)DeleteThread:(NSString *)KEYID;

// for single message
- (BOOL)InsertMessage: (MsgEntry*)MSG;
- (BOOL)DeleteMessage: (NSData*)msgid;
- (BOOL)CheckMessage: (NSData*)msgid;


// Query function for msg Table
- (NSData*)QueryInMsgTableByMsgID: (NSData*)MSGID Field:(NSString*)FIELD;
// Query functions for Token Table
- (NSString*)QueryStringInTokenTableByKeyID: (NSString*)KEYID Field:(NSString*)FIELD;

// for secure message (File part)
- (FileInfo*)GetFileInfo: (NSData*)msgid;
- (BOOL)UpdateFileBody: (NSData*)msgid DecryptedData:(NSData*)data;

// for configuration
- (BOOL)InsertOrUpdateConfig: (NSData*)value withTag:(NSString*)tag;
- (NSData*)GetConfig: (NSString*)tag;
- (NSString*)GetStringConfig: (NSString*)tag;
- (BOOL)RemoveConfigTag:(NSString*)tag;

// Utlilty functions
- (NSString*)GetProfileName;
- (NSString*)GetRawKey: (NSString*)KEYID;
- (int)GetDeviceType: (NSString*)KEYID;
- (int)GetExchangeType: (NSString*)KEYID;



@end
