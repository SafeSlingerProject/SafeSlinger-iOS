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

@import Foundation;
#import "SafeSlingerDB.h"

typedef enum KeyType {
	ENC_PRI = 0,
	SIGN_PRI,
    ENC_PUB,
    SIGN_PUB
}KeyType;

@interface SSEngine : NSObject 

+ (NSData *)BuildCipher:(NSString *)keyid Message:(NSData *)Message Attach:(NSString *)FileName RawFile:(NSData *)rawFile MIMETYPE:(NSString *)MimeType Cipher:(NSMutableData *)cipher;

// Key Generation API
+(BOOL)checkCredentialExist;
+(BOOL)GenKeyPairForENC;
+(BOOL)GenKeyPairForSIGN;
+(int)GenRSAKey:(int)bits WithType:(int)keytype;

// block cipher and hmac for message and files
+(NSData*)GenRandomBytes:(int)len_bytes;
+(NSData*)AESEncrypt: (NSData*)plain withAESKey: (NSData*)secret;
+(NSData*)AESDecrypt: (NSData*)cipher withAESKey: (NSData*)secret withPlen: (int)lengthOfPlain;

// public key cryptography
+(NSData*)Encrypt: (NSString*)pubkeyData keysize:(int)bits withData:(NSData*)text;
+(BOOL)Verify: (NSString*)pubkeyData keySize:(int)bits withSig:(NSData*)sig withtext: (NSData*)text;
+(NSData*)Decrypt: (NSData*)cipher withPrikey:(NSData*)keybytes;
+(NSData*)Sign: (NSData*)text withPrikey:(NSData*)keybytes;

// Key information retrieve
+(NSData*)getPrivateKey: (int)keytype;
+(NSData*)getPubKey: (int)keytype;
+(NSString*)getSelfKeyID;
+(NSString*)getSelfSubmissionToken;
+(NSString*)getSelfGenKeyDate;
+(NSData*)getPackPubKeys;

+(BOOL)TestPassPhase: (NSString*)Passphase KeySize1:(int)plen1 KeySize2:(int)plen2;
+(NSData*)UnlockPrivateKey: (NSString*)Passphase Size:(int)plen Type:(int)keytype;
+(void)LockPrivateKeys: (NSString*)Passphase RawData:(NSData*)plaintext Type:(int)keytype;
+(int)getSelfPrivateKeySize: (int)keytype;

// Packet Unpacking and packing
+(NSString*)ExtractKeyID: (NSData*)packet;
+(NSData*)PackMessage:(NSData*)plain PubKey:(NSString*)puk Prikey:(NSData*)pri;
+(NSData*)UnpackMessage:(NSData*)cipher PubKey:(NSString*)puk Prikey:(NSData*)pri;

@end


