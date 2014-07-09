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
#import <CommonCrypto/CommonHMAC.h>
#import <openssl/dh.h>
#import "WordListViewController.h"
#import "Config.h"

enum ProtocolState
{
	AssignUser,
	SyncUsers,
	SyncData,
	SyncSigs,
    SyncDHKeyNodes,
    SyncMatch,
    
    ProtocolSuccess,
    ProtocolFail,
    ProtocolTimeout,
    ProtocolCancel,
    NetworkFailure
};

@class safeslingerexchange;

@interface SafeSlingerExchange : NSObject <UIAlertViewDelegate>
{
	int users, retries, minID, version, serverVersion, minVersion;
	BOOL confirmed, wordListsDiffer;
	enum ProtocolState state;
	NSString *userID;
	
    // userid
    NSMutableArray *allUsers;
    // nonces and hashes structures
    NSData *match_nonce, *wrong_nonce, *match_hash, *match_extrahash, *wrong_hash;
    NSMutableDictionary *matchNonceSet, *matchExtraHashSet, *wrongNonceSet;
    NSMutableDictionary *matchHashSet, *wrongHashSet, *DHPubKeySet;
    // commitments
    NSData *protocol_commitment, *data_commitment;
    NSMutableDictionary *protocolCommitmentSet, *dataCommitmentSet;
    // encrypted data
    NSData *encrypted_data;
    NSMutableDictionary *encrypted_dataSet;
    // group DH
    NSData *DHPubKey, *groupKey;
    DH* diffieHellmanKeys;
    NSMutableDictionary *keyNodes;
    
	// Network Usage
	NSURL *serverURL;
	NSMutableURLRequest *request;
	NSURLConnection *connection;
	NSMutableData *serverResponse;
}

@property (nonatomic) int users, retries, minID, version, serverVersion, minVersion;
@property (nonatomic) BOOL confirmed;
@property (nonatomic) enum ProtocolState state;
@property (nonatomic, retain) NSString *userID;
@property (nonatomic, retain) NSData *match_nonce, *wrong_nonce, *match_hash, *match_extrahash, *wrong_hash, *encrypted_data;
@property (nonatomic, retain) NSData *protocol_commitment, *data_commitment, *DHPubKey, *groupKey;
@property (nonatomic, retain) NSMutableDictionary *protocolCommitmentSet, *dataCommitmentSet, *encrypted_dataSet, *matchNonceSet, *wrongNonceSet, *matchHashSet, *wrongHashSet, *matchExtraHashSet, *DHPubKeySet, *keyNodes;

@property (nonatomic, retain) NSURL *serverURL;
@property (nonatomic, retain) NSMutableURLRequest *request;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *serverResponse;
@property (nonatomic, retain) NSMutableArray *allUsers;
@property (nonatomic, assign) safeslingerexchange *delegate;


-(id)init: (NSString*)ServerHost version:(int)vnum;
-(NSData*) generateHashForPhrases;
-(void) startProtocol: (NSData*)input;
-(void) sendMinID;
-(void) distributeNonces: (BOOL)match Choice: (NSString*)Phrase;

@end
