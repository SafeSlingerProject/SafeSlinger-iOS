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

// for beta testing
#ifdef BETA
#define HTTPURL_PREFIX @"https://01060000t-dot-"
#define HTTPURL_HOST_MSG @"safeslinger-messenger.appspot.com"
#define HTTPURL_HOST_EXCHANGE @"safeslinger-exchange.appspot.com"
#else
// default server, for app store
#define HTTPURL_PREFIX @"https://"
#define HTTPURL_HOST_MSG @"safeslinger-messenger.appspot.com"
#define HTTPURL_HOST_EXCHANGE @"safeslinger-exchange.appspot.com"
#endif

// for backup capability
#define MAX_BACKUP_RETRY 5
#define BACKUP_PERIOD 3600.0f
// for password length
#define MIN_PINCODE_LENGTH 8
#define MAX_PINCODE_RETRY 3
#define PENALTY_TIME 10

// For Secure Message and Introduction
#define POSTMSG @"postMessage"
#define GETMSG @"getMessage"
#define GETNONCESBYTOKEN @"getMessageNoncesByToken"
#define GETFILE @"getFile"
#define QUERYTOKEN @"checkStatus"
#define POSTREGISTRATION @"postRegistration"

#define FILEID_LEN 32
#define PLATFORM_ANDROID_SMS 0
#define PLATFORM_ANDROID_C2DM 1
#define PLATFORM_IOS 2
#define MESSAGE_TIMEOUT 30.0
#define LENGTH_KEYID 88
#define NONCELEN 32 // for keccak256

#define KSDIdlingWindowTimeoutNotification @"SafeSlingerTimeOut"

// User prefernece
#define kAutoDecryptOpt @"AutoDecryptOpt"
#define kRemindBackup @"RemindBackup"
#define kPasshpraseCacheTime @"PasshpraseCacheTime"
#define kShowExchangeHint @"ShowExchangeHint"
#define kDEFAULT_DB_KEY @"DEFAULT_DB_KEY"
#define kFIRST_USE @"FIRST_USE"
#define kDB_KEY @"DB_KEY"
#define kDB_LIST @"DB_LIST"
#define kRestoreDate @"RestoreDate"
#define kBackupCplDate @"BackupCplDate"
#define kBackupReqDate @"BackupReqDate"
#define kBackupURL @"BackupURL"
#define kAPPVERSION @"APP_VERSION"
#define kLastNotificationTimestamp @"LastNotificationTimestamp"
#define kPUSH_TOKEN @"PUSH_TOKEN"

#define kRequireMicrophonePrivacy @"RequireMicrophonePrivacy"
#define kRequirePushNotification @"RequirePushNotification"

#define kPushNotificationHelpURL @"https://www.cylab.cmu.edu/safeslinger/help/h1.html"
#define kContactHelpURL @"https://www.cylab.cmu.edu/safeslinger/help/h2.html"
#define kiCloudHelpURL @"https://www.cylab.cmu.edu/safeslinger/help/h3.html"
#define kMicrophoneHelpURL @"https://www.cylab.cmu.edu/safeslinger/help/h4.html"
#define kPhotoHelpURL @"https://www.cylab.cmu.edu/safeslinger/help/h5.html"
#define kCameraHelpURL @"https://www.cylab.cmu.edu/safeslinger/help/h6.html"

#define kHelpURL @"www.cylab.cmu.edu/safeslinger"

#define kPrivacyURL @"http://www.cylab.cmu.edu/safeslinger/privacy.html"
#define kLicenseURL @"http://www.cylab.cmu.edu/safeslinger/eula.html"

typedef enum PermDialog {
    NotPermDialog = 0,
    AskPerm = 100,
	HelpContact,
	HelpNotification,
    HelpPhotoLibrary,
    HelpCamera,
    HelpMicrophone
}PermDialog;

// for UI constant
#define HalfkeyboardHieght 108.0f
#define MsgBoxHieght 30.0f

typedef enum HelpActionSheet {
	Help = 0,
	Feedback,
    LicenseLink,
    PrivacyLink
}HelpActionSheet;

typedef enum OptionType {
    Unregistered = 0,
	TurnOff = 1,
	TurnOn = 2
}OptionType;

typedef enum DevType {
    DISABLED = 0,
	Android_C2DM = 1,
	iOS = 2,
    Android_GCM = 3
}DevType;

typedef enum ProfileStatus {
	NonExist = -1,
	NonLink = 0
}ProfileStatus;

typedef enum ContactCategory {
	Photo = 0,
	Email,
	Url,
    PhoneNum,
    Address,
    IMPP
}ContactCategory;
