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

/*
 Database Tables
 
 table ciphertable(4) := {
    msgid BLOB PRIMARY KEY,    // msgid, 32 bytes
    cTime DATETIME NULL,       // timestamp for create/receive this message
    keyid TEXT NULL,           // sender's key id
    cipher BLOB NULL           // receiving encrypted ciphertext
 };
 
 */

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class MsgEntry;

@interface UniversalDB : NSObject
{
    sqlite3 *db;
}

- (BOOL) LoadDBFromStorage;
- (BOOL) CloseDB;

- (BOOL) CreateNewEntry: (NSData*)msgnonce;
- (BOOL) UpdateEntryWithCipher: (NSData*)msgnonce Cipher:(NSData*)newcipher;
- (BOOL) DeleteThread: (NSString*)keyid;
- (int) UpdateThreadEntries: (NSMutableDictionary*) threadlist;
- (NSArray*) GetEntriesForKeyID: (NSString*)keyid WithToken:(NSString*)token WithName:(NSString*)name;
- (int) ThreadCipherCount: (NSString*)KEYID;
- (BOOL) CheckMessage: (NSData*)msgid;
- (NSArray*)LoadThreadMessage: (NSString*)KEYID;
- (BOOL)DeleteMessage: (NSData*)msgid;

@end
