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

#ifndef KeySlinger_Config_h
#define KeySlinger_Config_h

// for beta testing
#ifdef BETA
#define HTTPURL_PREFIX @"https://01060000ios-dot-"
#define HTTPURL_HOST_MSG @"starsling-server.appspot.com"
#define HTTPURL_HOST_EXCHANGE @"keyslinger-server.appspot.com"
#else
// default server, for app store
#define HTTPURL_PREFIX @"https://"
#define HTTPURL_HOST_MSG @"starsling-server.appspot.com"
#define HTTPURL_HOST_EXCHANGE @"keyslinger-server.appspot.com"
#endif

// for backup capability
#define MAX_BACKUP_RETRY 5
#define BACKUP_PERIOD 3600.0f
// for password length
#define MIN_PINCODE_LENGTH 8

// For Secure Message and Introduction
#define POSTANDROIDMSG @"postFile1"
#define POSTIOSMSG @"postFile2"
#define GETMSG @"getMessage"
#define GETNONCESBYTOKEN @"getMessageNoncesByToken"
#define GETFILE @"getFile"
#define QUERYTOKEN @"checkStatus"
#define FILEID_LEN 32
#define PLATFORM_ANDROID_SMS 0
#define PLATFORM_ANDROID_C2DM 1
#define PLATFORM_IOS 2
#define MESSAGE_TIMEOUT 30.0
#define LENGTH_KEYID 88

// For Key exchange part
#define MINICVERSION 0x01060000 // Client minimum version
#define NONCELEN 32 // for keccak256
#define CRYPTONONCELEN 25
#define HASHLEN 32  // for keccak256
#define TIMEOUT 60
#define RETRYTIMEOUT 1
#define COLLECTIONTIMEOUT 15
#define KEYLENGTH 1024
#define ABORTTIMEOUT 15
#define IVTRUNCLEN 16
#define KEYTRUNCLEN 16
#define MAX_USERS 10
#define MIN_USERS 2
#define MAX_RETRY 3
#define PENALTY_TIME 10

// For Secure Message
#define ENTROPY_BLOCK_SIZE 64

// for UI constant
#define HalfkeyboardHieght 108.0f
#define MsgBoxHieght 30.0f

typedef enum DevType {
	Android = 1,
	iOS
}DevType;

typedef enum ContactOperation {
	EditOld = 0,
	AddNew,
	ReSelect
}ContactOperation;

typedef enum ContactCategory {
	Photo = 0,
	Email,
	Url,
    PhoneNum,
    Address,
    IMPP
}ContactCategory;

#endif
