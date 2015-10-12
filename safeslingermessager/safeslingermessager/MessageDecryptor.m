//
//  MessageDecryptor.m
//  safeslingermessager
//
//  Created by Bruno Nunes on 5/21/15.
//  Copyright (c) 2015 CyLab. All rights reserved.
//

#import "MessageDecryptor.h"
#import "AppDelegate.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "Utility.h"

@implementation MessageDecryptor

+ (void)tryToDecryptAll {
    DEBUGMSG(@"tryToDecryptAll");
	AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSArray *encryptedMessages = [delegate.UDbInstance getEncryptedMessages];
		
		for(MsgEntry *message in encryptedMessages) {
			[MessageDecryptor decryptCipherMessage:message];
		}
	});
}

+ (BOOL)decryptCipherMessage:(MsgEntry *)msg {
	BOOL hasfile = NO;
	AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	// tap to decrypt
	NSString* pubkeySet = [delegate.DbInstance QueryStringInTokenTableByKeyID:msg.keyid Field:@"pkey"];
	
	if(pubkeySet == nil) {
		[ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_UnableFindPubKey", @"Unable to match public key to private key in crypto provider.")];
		return NO;
	}
	
	NSString* username = [NSString humanreadable:[delegate.DbInstance QueryStringInTokenTableByKeyID:msg.keyid Field:@"pid"]];
	NSString* usertoken = [delegate.DbInstance QueryStringInTokenTableByKeyID:msg.keyid Field:@"ptoken"];
	
	int PRIKEY_STORE_SIZE = 0;
	[[delegate.DbInstance GetConfig:@"PRIKEY_STORE_SIZE"] getBytes:&PRIKEY_STORE_SIZE length:sizeof(PRIKEY_STORE_SIZE)];
	NSData* DecKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_SIZE Type:ENC_PRI];
	
	if(!DecKey) {
		[ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_couldNotExtractPrivateKey", @"Could not extract private key.")];
		return NO;
	}
	
	NSData* decipher = [SSEngine UnpackMessage:msg.msgbody PubKey:pubkeySet Prikey:DecKey];
	
	// parsing
	if(!decipher || decipher.length == 0) {
		[ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")];
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[[[[iToast makeText: NSLocalizedString(@"error_MessageSignatureVerificationFails", @"Signature verification failed.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
		});
		return NO;
	}
	
	const char * p = [decipher bytes];
	int offset = 0, len = 0;
	unsigned int flen = 0;
	NSString* fname = nil;
	NSString* ftype = nil;
	NSString* peer = nil;
	NSString* text = nil;
	NSString* gmt = nil;
	NSData* filehash = nil;
	
	// parse message format
	DEBUGMSG(@"Version: %02X", ntohl(*(int *)p));
	offset += 4;
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	
	offset = offset+len;
	
	flen = (unsigned int)ntohl(*(int *)(p+offset));
	if(flen>0) hasfile=YES;
	offset += 4;
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	if(len>0){
		fname = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSUTF8StringEncoding];
		// handle file name
		offset = offset+len;
	}
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	if(len>0){
		// handle file type
		ftype = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSASCIIStringEncoding];
		offset = offset+len;
	}
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	if(len>0){
		// handle text
		text = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSUTF8StringEncoding];
		offset = offset+len;
	}
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	if(len>0){
		// handle Person Name
		peer = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSUTF8StringEncoding];
		offset = offset+len;
	}
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	if(len>0){
		// handle text
		gmt = [[NSString alloc] initWithBytes:p+offset length:len encoding:NSASCIIStringEncoding];
		DEBUGMSG(@"gmt: %@", gmt);
		offset = offset+len;
	}
	
	len = ntohl(*(int *)(p+offset));
	offset += 4;
	if(len>0){
		// handle text
		filehash = [NSData dataWithBytes:p+offset length:len];
		offset = offset+len;
	}
	
	msg.sender = username;
	msg.token = usertoken;
	msg.smsg = Decrypted;
	msg.msgbody = [text dataUsingEncoding:NSUTF8StringEncoding];
	msg.rTime = gmt;
	msg.unread = 1;
	
	if(hasfile) {
		msg.attach = msg.sfile = Encrypted;
		NSMutableData *finfo = [NSMutableData data];
		[finfo appendData:filehash];
		[finfo appendBytes:&flen length:sizeof(flen)];
		msg.fname =fname;
		msg.fbody = finfo;
		msg.fext = ftype;
	}
	
	// Move message from Universal Database to Individual Database
	[delegate.DbInstance InsertMessage:msg];
	[delegate.UDbInstance DeleteMessage:msg.msgid];
	
	return YES;
}

@end
