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

#import <QuartzCore/QuartzCore.h>
#import <Foundation/NSException.h>
#import <CommonCrypto/CommonHMAC.h>
#import <unistd.h>
#import <stdlib.h>

#import "SafeSlinger.h"
#import "WordListViewController.h"
#import "NSDataEncryption.h"
#import "Utility.h"
#import "safeslingerexchange.h"
#import "GroupingViewController.h"
#import "ActivityWindow.h"
#import "GroupSizePicker.h"
#import "sha3.h"

#import <openssl/rand.h>
#import <openssl/err.h>

#define DH_PRIME "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF"
#define DH_GENERATOR "02"

@implementation SafeSlingerExchange

@synthesize users, retries, minID, version, serverVersion, minVersion;
@synthesize userID;
@synthesize confirmed;
@synthesize state;
@synthesize protocol_commitment, data_commitment, match_nonce, wrong_nonce, match_hash, match_extrahash, matchExtraHashSet, wrong_hash, encrypted_data, DHPubKey, groupKey;
@synthesize protocolCommitmentSet, dataCommitmentSet, encrypted_dataSet, matchNonceSet, wrongNonceSet, matchHashSet, wrongHashSet, DHPubKeySet;
@synthesize serverURL;
@synthesize request;
@synthesize serverResponse;
@synthesize allUsers, keyNodes;
@synthesize delegate;


- (id)init: (NSString*)ServerHost version:(int)vnum
{
    self = [super init];
    if (self) {
        // Initialize self.
        wordListsDiffer = NO;
        self.retries = 0;
        
        // host server address
        self.serverURL = [NSURL URLWithString: ServerHost];
        self.request = [[NSMutableURLRequest alloc] initWithURL: serverURL];
        self.serverResponse = [[NSMutableData alloc] init];
        
        self.protocolCommitmentSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.dataCommitmentSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.encrypted_dataSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.matchNonceSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.wrongNonceSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.matchHashSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.matchExtraHashSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.wrongHashSet = [[NSMutableDictionary alloc] initWithCapacity: users];
        self.allUsers = [[NSMutableArray alloc] init];
        self.version = vnum;
        self.keyNodes = [[NSMutableDictionary alloc] initWithCapacity:users];
        self.DHPubKeySet = [[NSMutableDictionary alloc] initWithCapacity:users];
        
        // Group Diffe Hellman
        diffieHellmanKeys = DH_new();
        BN_hex2bn(&(diffieHellmanKeys->p), DH_PRIME);
        BN_hex2bn(&(diffieHellmanKeys->g), DH_GENERATOR);
    }
    return self;
}

-(void) FreeProtocolStructures
{
    DH_free(diffieHellmanKeys);
    
    if(allUsers)[allUsers removeAllObjects];
	if(protocolCommitmentSet)[protocolCommitmentSet removeAllObjects];
	if(dataCommitmentSet)[dataCommitmentSet removeAllObjects];
	if(encrypted_dataSet)[encrypted_dataSet removeAllObjects];
	if(matchNonceSet)[matchNonceSet removeAllObjects];
	if(wrongNonceSet)[wrongNonceSet removeAllObjects];
	if(matchHashSet)[matchHashSet removeAllObjects];
	if(wrongHashSet)[wrongHashSet removeAllObjects];
    
    retries = 0;
}

-(void) dealloc
{
    [self FreeProtocolStructures];
}

-(void) generateData: (NSData*)exchangeData
{
    // key = sha3(1||match_nonce)
    NSString *k = @"1";
    NSData* encryptionKey = [sha3 Keccak256HMAC:match_nonce withKey:[k dataUsingEncoding:NSUTF8StringEncoding]];
    self.encrypted_data = [exchangeData AES256EncryptWithKey:encryptionKey matchNonce: match_nonce];
}

-(void) generateNonce
{
	unsigned char arr[NONCELEN];
    // generate match nonce Nmi using SHA3
    SecRandomCopyBytes(kSecRandomDefault, NONCELEN, arr);
	self.match_nonce = [NSData dataWithBytes: arr length: NONCELEN];
    // compute hash Hmi
    self.match_extrahash = [sha3 Keccak256Digest: self.match_nonce];
	
    // generate wrong nonce Nwi using SHA3
    SecRandomCopyBytes(kSecRandomDefault, NONCELEN, arr);
	self.wrong_nonce = [NSData dataWithBytes: arr length: NONCELEN];
    // wrong hash commitment, replace with sha3
    self.wrong_hash = [sha3 Keccak256Digest: self.wrong_nonce];
}

-(void) doPostToPage: (NSString *) page withBody: (NSData *) body
{
	DEBUGMSG(@"Do Async POST to Relative URL: %@", page);
	DEBUGMSG(@"Data: %@", body);
	
	[request setURL: [NSURL URLWithString: page relativeToURL: serverURL]];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: body];
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    // set minimum version as TLS v1.0
    defaultConfigObject.TLSMinimumSupportedProtocol = kTLSProtocol12;
    NSURLSession *HttpsSession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:nil delegateQueue:[NSOperationQueue mainQueue]];
    
    [[HttpsSession dataTaskWithRequest: request
                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error){
                            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                            if(error)
                            {
                                state = NetworkFailure;
                                [self.delegate DisplayMessage: [error localizedDescription]];
                            }else{
                                DEBUGMSG(@"received data = %@", [data hexadecimalString]);
                                [serverResponse setData:data];
                                [self handleSafeSlingerState];
                            }
                        }] resume];
}

-(void) handleSafeSlingerState
{
    const char *buf = [serverResponse bytes];
    int statusCode = ntohl(*(int *)buf);
    if(statusCode==0)
    {
        NSString *msg = [NSString stringWithCString:buf+4 encoding:NSASCIIStringEncoding];
        state = NetworkFailure;
        [self.delegate DisplayMessage:msg];
    }else{
        switch (state)
        {
            case AssignUser:
                [self handleAssignUser];
                break;
            case SyncUsers:
                [self handleSyncUsers];
                break;
            case SyncData:
                [self handleSyncData];
                break;
            case SyncSigs:
                [self handleSyncSigs];
                break;
            case SyncDHKeyNodes:
                [self handleSyncKeyNodes];
                break;
            case SyncMatch:
                [self handleSyncMatch];
                break;
            default:
                break;
        }
    }
}

-(NSData*) generateHashForPhrases
{
    int DHPubKeySize = DH_size(diffieHellmanKeys);
	int len = 0;
	NSMutableArray *keys = [NSMutableArray arrayWithArray: [encrypted_dataSet allKeys]];
	[keys sortUsingSelector: @selector(compareUID:)];
	NSMutableArray *dataArray = [[NSMutableArray alloc] initWithCapacity: users];
	NSMutableArray *protocolCommitmentArray = [[NSMutableArray alloc] initWithCapacity: users];
	NSMutableArray *DHPubKeyArray = [[NSMutableArray alloc]initWithCapacity: users];
    for (int i = 0; i < users; i++)
	{
		NSString *k = [keys objectAtIndex: i];
		NSData *d = [encrypted_dataSet objectForKey: k];
		NSData *pc = [protocolCommitmentSet objectForKey: k];
        NSData *pubkey = [DHPubKeySet objectForKey:k];
        
		[dataArray insertObject: d atIndex: i];
		[protocolCommitmentArray insertObject: pc atIndex: i];
		[DHPubKeyArray insertObject:pubkey atIndex:i];
        
        len += [d length] + HASHLEN + DHPubKeySize;
	}
	
	unsigned char *ptr = malloc(len);
	for (int i = 0; i < users; i++)
	{
		NSData *d = [dataArray objectAtIndex: i];
		NSData *pc = [protocolCommitmentArray objectAtIndex: i];
		NSData *pubkey = [DHPubKeyArray objectAtIndex:i];
        
        memcpy(ptr, [pc bytes], HASHLEN);
		ptr += HASHLEN;
        
        memcpy(ptr, [pubkey bytes], DHPubKeySize);
        ptr += DHPubKeySize; 
        
		memcpy(ptr, [d bytes], [d length]);
		ptr += [d length];
	}
	ptr -= len;
	
    NSData *hash = [sha3 Keccak256Digest: [NSData dataWithBytes:ptr length:len]];
    
	free(ptr);
	return hash;
}

-(void) startProtocol: (NSData*)input
{
    [delegate.actWindow DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"lib_name", @"SafeSlinger Exchange") Detail:NSLocalizedStringFromBundle(delegate.res, @"prog_RequestingUserId", @"requesting membership...")];
    [delegate.sizePicker.view addSubview:delegate.actWindow.view];
    
    // produce correct & wrong nonces
    [self generateNonce];
    // encrypt contact data
    [self generateData: input];
    DEBUGMSG(@"ENCRYPTED DATA %@", self.encrypted_data);
    
    // oroduce hash Hmi'
    self.match_hash = [sha3 Keccak256Digest: match_extrahash];
    
    NSMutableData *buffer = [NSMutableData data];
    [buffer appendData: match_hash];
    [buffer appendData: wrong_hash];
    
    // compute HNi
    self.protocol_commitment = [sha3 Keccak256Digest: buffer];
    DEBUGMSG(@"protocolCommitment (HNi) = %@", protocol_commitment);
    
    // Diffie hellman Key, Gi = g^ni mod p
    DH_generate_key(diffieHellmanKeys);
    int DHPubKeySize = DH_size(diffieHellmanKeys);
    
    // Allocate memory for data commitment
	unsigned char *ptr = malloc(HASHLEN + DHPubKeySize + [encrypted_data length]);
    
    // part 1: protcol commitment
	[protocol_commitment getBytes: ptr length: HASHLEN];
    // part 2: DH Public Key
    BN_bn2bin(diffieHellmanKeys->pub_key, (unsigned char*)(ptr + HASHLEN));
    self.DHPubKey = [NSData dataWithBytes:ptr + HASHLEN length:DHPubKeySize];
    // part 3: encrypted contact
    [self.encrypted_data getBytes: ptr + DHPubKeySize + HASHLEN length: [encrypted_data length]];
    // Hash to create data commitment using sha3
    self.data_commitment = [sha3 Keccak256Digest: [NSData dataWithBytes:ptr length: DHPubKeySize + [encrypted_data length] + HASHLEN]];
	free(ptr);
    
    // commitment
    DEBUGMSG(@"dataCommitment (Ci) = %@", data_commitment);
	
	ptr = malloc(HASHLEN + 4);
	*(int *)ptr = htonl(version);
	[data_commitment getBytes: ptr + 4 length:HASHLEN];
    
	self.state = AssignUser;
	[self doPostToPage: @"assignUser" withBody: [NSData dataWithBytes: ptr length: HASHLEN + 4]];
	free(ptr);
}

-(void) handleAssignUser
{
	[delegate.actWindow.view removeFromSuperview];
    const char *response = [serverResponse bytes];
	self.serverVersion = ntohl(*(int *)response);
    if(self.serverVersion==0)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server Message: %@"),
                         [NSString stringWithCString:response+8 encoding:NSUTF8StringEncoding]];
        state = NetworkFailure;
        [self.delegate DisplayMessage: msg];
    }else{
        self.userID = [NSString stringWithFormat: @"%d", ntohl(*(int *)(response + 4))];
        
        // Add selfcopy
        [allUsers addObject: userID];
        
        [protocolCommitmentSet setObject: protocol_commitment forKey: userID];
        [dataCommitmentSet setObject: data_commitment forKey: userID];
        [DHPubKeySet setObject:DHPubKey forKey:userID];
        [encrypted_dataSet setObject: encrypted_data forKey: userID];
        
        [matchNonceSet setObject: match_nonce forKey: userID];
        [matchHashSet setObject: match_hash forKey: userID];
        [matchExtraHashSet setObject:match_extrahash forKey:userID];
        [wrongNonceSet setObject: wrong_nonce forKey: userID];
        [wrongHashSet setObject: wrong_hash forKey: userID];
        
        // Display assigned unique ID
        [delegate BeginGrouping: self.userID];
    }
}

-(void) sendMinID
{
	char buf[4 + 4 + 4 + 4 + 4 + HASHLEN];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl(minID);
    // initially only one user sent
	*(int *)(buf + 12) = htonl(1);
	*(int *)(buf + 16) = *(int *)(buf + 4);
	[data_commitment getBytes: buf + 20 length:HASHLEN];
    
    NSString *title = [NSString stringWithFormat:@"%@, %@",
                       [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"choice_NumUsers", @"%d users"), users],
                       [NSString stringWithFormat: @"%@ %d", NSLocalizedStringFromBundle(delegate.res, @"label_UserIdHint", @"Lowest"), minID]];
    NSString *detail = [NSString stringWithFormat:@"%@\n%@",
                       NSLocalizedStringFromBundle(delegate.res, @"prog_CollectingOthersItems", @"waiting for all users to join..."),
                        [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"label_ReceivedNItems", @"Recievd %d Items"), 1]];
    
    [delegate.actWindow DisplayMessage: title  Detail:detail];
    [delegate.groupView.view addSubview:delegate.actWindow.view];
    
	self.state = SyncUsers;
	[self doPostToPage: @"syncUsers" withBody: [NSData dataWithBytes:buf length: 20+HASHLEN]];
}

-(void) handleSyncUsers
{
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
    if(self.serverVersion==0)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server Message: %@"),
                         [NSString stringWithCString:response+8 encoding:NSUTF8StringEncoding]];
        state = NetworkFailure;
        [self.delegate DisplayMessage: msg];
        return;
    }
    
    self.minVersion = ntohl(*(int *)(response + 4));
	if (minVersion < MINICVERSION)
	{
        state = NetworkFailure;
		[self.delegate DisplayMessage:NSLocalizedStringFromBundle(delegate.res, @"error_AllMembersMustUpgrade", @"Some members are using an older version; all members must upgrade to the least version.")];
		return;
	}
	
    // skip # of totla users from the server since user already enter the number
    int count = ntohl(*(int *)(response + 8));
	// number of items
    int delta_count = ntohl(*(int *)(response + 12));
    
    if (delta_count > users || count > users) {
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_MoreDataThanUsers", @"Unexpected data found in exchange. Begin the exchange again.")];
		return;
    }
    
    // Collect all data commitments Ci from other users
    if(delta_count>0)
    {
        char *ptr = response + 16;
        for (int i = 0; i < delta_count; i++)
        {
            int uid = ntohl(*(int *)ptr);
            if (uid != [userID intValue])
                [allUsers addObject: [NSString stringWithFormat: @"%d", uid]];
            ptr += 4;
            int commitLen = ntohl(*(int *)ptr);
            ptr += 4;
            NSData *dC = [NSData dataWithBytes:ptr length:HASHLEN];
            [dataCommitmentSet setObject:dC forKey:[NSString stringWithFormat:@"%d",uid]];
            ptr += commitLen;
        }
    }
	
    // Retrieve if necessary
	if ([allUsers count] < users)
	{
		retries++;
		if (retries > MAX_RETRY)
		{
            state = ProtocolTimeout;
            [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_TimeoutWaitingForAllMembers", @"Timeout waiting for some group members to add data.")];
			return;
		}
        
        // display progress
        NSString *title = [NSString stringWithFormat:@"%@, %@",
                           [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"choice_NumUsers", @"%d users"), users],
                           [NSString stringWithFormat: @"%@ %d", NSLocalizedStringFromBundle(delegate.res, @"label_UserIdHint", @"Lowest"), minID]];
        
        NSString *detail = [NSString stringWithFormat:@"%@\n%@",
                            NSLocalizedStringFromBundle(delegate.res, @"prog_CollectingOthersItems", @"waiting for all users to join..."),
                            [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"label_ReceivedNItems", @"Recievd %d Items"), [allUsers count]]];
        [delegate.actWindow DisplayMessage: title  Detail:detail];
        
        // reset timer
		NSTimer *retryTimer = [NSTimer timerWithTimeInterval: retries*RETRYTIMEOUT
                                             target: self
                                           selector: @selector(retrySyncUsers)
                                           userInfo: nil
                                            repeats: NO];
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
		[rl addTimer: retryTimer forMode: NSDefaultRunLoopMode];
		return;
	}
    
    // all data commitments are received
    retries = 0;
	[allUsers removeAllObjects];
	[allUsers addObject: userID];
    
    // prepare datam including HNi, Gi, Ei (Encrypted Contact)
    int DHPubKeySize = DH_size(diffieHellmanKeys);
    int len = 4 + 4 + 4 + 4 + HASHLEN + (int)[encrypted_data length] + DHPubKeySize;
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl(1);
	*(int *)(buf + 12) = *(int *)(buf + 4);
    
    // HNi
    [protocol_commitment getBytes: buf + 16 length:HASHLEN];
    // Gi
    BN_bn2bin(diffieHellmanKeys->pub_key, (unsigned char*)(buf + 16 + HASHLEN));
    // Ei
	[encrypted_data getBytes: buf + 16 + HASHLEN + DHPubKeySize length:[encrypted_data length]];
    
	self.state = SyncData;
	[self doPostToPage: @"syncData" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) retrySyncUsers
{
	int len = 16 + (4 * (int)[allUsers count]);
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl(minID);
	*(int *)(buf + 12) = htonl([allUsers count]);
	char *ptr = buf + 16;
	for (int i = 0; i < [allUsers count]; i++)
	{
		*(int *)ptr = htonl([[allUsers objectAtIndex: i] intValue]);
		ptr += 4;
	}
	[self doPostToPage: @"syncUsers" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) handleSyncData
{
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
    if(self.serverVersion==0)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server Message: %@"),
                         [NSString stringWithCString:response+8 encoding:NSUTF8StringEncoding]];
        state = NetworkFailure;
        [self.delegate DisplayMessage: msg];
        return;
    }
    
    int count = ntohl(*(int *)(response + 4));
    // number of items
    int delta_count = ntohl(*(int *)(response + 8));
    
    if (delta_count > users || count > users) {
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_MoreDataThanUsers", @"Unexpected data found in exchange. Begin the exchange again.")];
        return;
    }
    
    if(delta_count>0)
    {
        char *ptr = response + 12;
        for (int i = 0; i < delta_count; i++)
        {
            NSString *uid = [NSString stringWithFormat: @"%d", ntohl(*(int *)ptr)];
            
            if ([uid isEqualToString: userID])
            {
                // shouldn't happen
                continue;
            }
            
            // parse data
            ptr += 4;
            int len = ntohl(*(int *)ptr);
            ptr += 4;
            
            NSData *pc = [NSData dataWithBytes: ptr length: HASHLEN];
            ptr += HASHLEN;
            
            // Extracting public key value
            int DHPubKeySize = DH_size(diffieHellmanKeys);
            NSData* remoteDHPubKey = [NSData dataWithBytes:ptr length:DHPubKeySize];
            ptr+=DHPubKeySize;
            
            NSData *enc_contact = [NSData dataWithBytes: ptr length: len - HASHLEN - DHPubKeySize];
            ptr += len - HASHLEN - DHPubKeySize;
            
            [allUsers addObject: uid];
            [DHPubKeySet setObject:remoteDHPubKey forKey:uid];
            [protocolCommitmentSet setObject: pc forKey: uid];
            [encrypted_dataSet setObject: enc_contact forKey: uid];
        }
    }
	
    // retry condition
	if ([allUsers count] < users)
	{
		retries++;
		if (retries > MAX_RETRY)
		{
            state = ProtocolTimeout;
            [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_TimeoutWaitingForAllMembers", @"Timeout waiting for some group members to add data.")];
			return;
		}
        
		NSTimer *retryTimer = [NSTimer timerWithTimeInterval: retries*RETRYTIMEOUT
                                                  target: self
                                                selector: @selector(retrySyncData)
                                                userInfo: nil
                                                 repeats: NO];
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
		[rl addTimer: retryTimer forMode: NSDefaultRunLoopMode];
		return;
	}
    
    // process to next step, validate data using received commitments first
    for (NSString* uid in allUsers)
	{
        if([uid isEqualToString:userID]) continue;
        
        // verificaiton for data commitment
        NSMutableData *recData = [NSMutableData data];
        [recData appendData: [protocolCommitmentSet objectForKey:uid]];
        [recData appendData: [DHPubKeySet objectForKey:uid]];
        [recData appendData: [encrypted_dataSet objectForKey:uid]];
        
        NSData *dCCalculated = [sha3 Keccak256Digest: recData];
        NSData *dCRecieved = [dataCommitmentSet objectForKey:uid];
        
        if (![dCCalculated isEqualToData:dCRecieved]) {
            state = ProtocolFail;
            [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_InvalidCommitVerify", @"An error occurred during commitment verification.")];
            return;
        }
	}
    
    retries = 0;
	[delegate.actWindow.view removeFromSuperview];
    
	[allUsers removeAllObjects];
	[allUsers addObject: userID];
	[delegate BeginVerifying];
}

-(void) retrySyncData
{
	int len = 12 + (4 * (int)[allUsers count]);
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl([allUsers count]);
	char *ptr = buf + 12;
	for (int i = 0; i < [allUsers count]; i++)
	{
		*(int *)ptr = htonl([[allUsers objectAtIndex: i] intValue]);
		ptr += 4;
	}
	[self doPostToPage: @"syncData" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) distributeNonces: (BOOL)match Choice: (NSString*)Phrase
{
    int len = 4 + 4 + 4 + 4 + HASHLEN * 2;
    
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl(1);
	*(int *)(buf + 12) = *(int *)(buf + 4);
    
    wordListsDiffer = !match;
    
	if (match)
	{
		[match_extrahash getBytes: buf + 16 length:HASHLEN];
		[wrong_hash getBytes: buf + 16 + HASHLEN length:HASHLEN];
        [delegate.actWindow DisplayMessage:Phrase Detail: NSLocalizedStringFromBundle(delegate.res, @"prog_CollectingOthersCommitVerify", @"waiting for verification from all members...")];
        [delegate.compareView.view addSubview:delegate.actWindow.view];
	}
	else
	{
		[match_hash getBytes: buf + 16 length:HASHLEN];
		[wrong_nonce getBytes: buf + 16 + HASHLEN length:HASHLEN];
	}
    
	state = SyncSigs;
	[self doPostToPage: @"syncSignatures" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) handleSyncSigs
{
    if (wordListsDiffer) {
        DEBUGMSG(@"reported wordListsDiffer");
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_LocalGroupCommitDiffer", @"You have reported a difference in phrases. Begin the exchange again.")];
        return;
    }
    
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
    
    if(self.serverVersion==0)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server Message: %@"),
                         [NSString stringWithCString:response+8 encoding:NSUTF8StringEncoding]];
        state = NetworkFailure;
        [self.delegate DisplayMessage: msg];
        return;
    }
    
    int count = ntohl(*(int *)(response + 4));
    // number of items
    int delta_count = ntohl(*(int *)(response + 8));
    if (delta_count > users || count > users) {
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_MoreDataThanUsers", @"Unexpected data found in exchange. Begin the exchange again.")];
        return;
    }
    
    if(delta_count>0)
    {
        char *ptr = response + 12;
        for (int i = 0; i < delta_count; i++)
        {
            // user id
            NSString *uid = [NSString stringWithFormat: @"%d", ntohl(*(int *)ptr)];
            ptr += 4;
			
            DEBUGMSG(@"len = %d", ntohl(*(int *)ptr));
            ptr += 4;
            
            //first hash Nmh, change to sha3
            NSData *Nmh = [NSData dataWithBytes:ptr length:HASHLEN];
            
            ptr += HASHLEN;
            
            NSData *Sha1Nmh = [sha3 Keccak256Digest: Nmh];
            NSData *wH = [NSData dataWithBytes:ptr length:HASHLEN];
            
            ptr += HASHLEN;
            
            NSMutableData *buffer = [NSMutableData data];
            [buffer appendData: Sha1Nmh];
            [buffer appendData: wH];
            
            NSData *cPC = [sha3 Keccak256Digest: buffer];
            NSData *rPC = [protocolCommitmentSet objectForKey:uid];
            
            // verify if protocol commitments match
            // also make sure that neither is nil
            if (cPC != nil && rPC != nil && [cPC isEqualToData:rPC])
            {
                [matchExtraHashSet setObject:Nmh forKey:uid];
                [wrongHashSet setObject:wH forKey:uid];
                [matchHashSet setObject:Sha1Nmh forKey:uid];
            }
            else
            {
                state = ProtocolFail;
                [delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_OtherGroupCommitDiffer", @"Someone reported a difference in phrases. Begin the exchange again.")];
                return;
            }
            
            if (![uid isEqualToString: userID])
                [allUsers addObject: uid];
        }
    }
	
	if ([allUsers count] < users)
	{
		retries++;
		if (retries > MAX_RETRY)
		{
            state = ProtocolTimeout;
			[self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_TimeoutWaitingForAllMembers", @"Timeout waiting for some group members to add data.")];
			return;
		}
		NSTimer *retryTimer = [NSTimer timerWithTimeInterval: retries*RETRYTIMEOUT
                                                  target: self
                                                selector: @selector(retrySyncSigs)
                                                userInfo: nil
                                                 repeats: NO];
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
		[rl addTimer: retryTimer forMode: NSDefaultRunLoopMode];
		return;
	}
	
    self.retries = 0;
    [self syncKeyNodes];
}

-(void) syncKeyNodes{
    
    // Doing DH group key construction
    int position = 0;
    int currentKeyNodeNumber = 0;
    BOOL firstKeynode = YES;
    
    self.state = SyncDHKeyNodes;
    
    [delegate.actWindow DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"prog_ConstructingGroupKey", @"Constructing Group Key ...") Detail:nil];
    [delegate.compareView.view addSubview:delegate.actWindow.view];
    
    NSArray *userIDs = [self.allUsers sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    // find self position at DH group tree
    for(int i = 0; i<[userIDs count]; i++){
        if([[userIDs objectAtIndex:i] isEqualToString:userID]){
            position = i;
            break;
        }
    }
    
    DEBUGMSG(@"position = %d", position);
    
    /* If position 1 or 0 */
    if(position < 2){
        /* If 1 set keynode 1 to be pubkey 0 and vice versa */
        currentKeyNodeNumber = 2;
        [self.keyNodes setObject:[self.DHPubKeySet objectForKey:[userIDs objectAtIndex:1-position]] forKey:[NSNumber numberWithInt:1]];
    }
    /* Else */
    else{
        /* Check if you have the keynode corresponding to you position. If not try to retrieve it */
        if(![self.keyNodes objectForKey:[NSNumber numberWithInt:position]]){
            int keynodeRequest[2];
            keynodeRequest[0] = htonl(version);
            keynodeRequest[1] = htonl([userID intValue]);
            [self doPostToPage: @"syncKeyNodes" withBody: [NSData dataWithBytes:&keynodeRequest length:4+4]];
            return;
        }
        currentKeyNodeNumber = position + 1;
    }
    
    BN_CTX* expContext = BN_CTX_new();
    DH* currentKeynode = DH_new();
    BN_hex2bn(&(currentKeynode->p), DH_PRIME);
    BN_hex2bn(&(currentKeynode->g), DH_GENERATOR);
    currentKeynode->priv_key = BN_new();
    
    unsigned char* sharedKey = malloc(DH_size(diffieHellmanKeys));
    BIGNUM* pubKey = BN_new();
    BIGNUM* expKeynode = BN_new();
    
    while(currentKeyNodeNumber <= [userIDs count]){
        
        DEBUGMSG(@"currentKeyNodeNumber = %d", currentKeyNodeNumber);
        /* For the first keynode that you generate use your private key and keynode as public key*/
        if(firstKeynode){
            DEBUGMSG(@"firstKeynode");
            BN_bin2bn([[keyNodes objectForKey:[NSNumber numberWithInt:currentKeyNodeNumber - 1]] bytes], DH_size(diffieHellmanKeys), pubKey);
            DH_compute_key(sharedKey, pubKey, diffieHellmanKeys);
            firstKeynode = NO;
        }
        /* For subsequent keynode generations use previous keynode as private key and and user i's public key */
        else{
            DEBUGMSG(@"other Keynode");
            BN_bin2bn([[DHPubKeySet objectForKey:[userIDs objectAtIndex:currentKeyNodeNumber-1]] bytes], DH_size(diffieHellmanKeys), pubKey);
            assert(DH_generate_key(currentKeynode)==1);
            DH_compute_key(sharedKey, pubKey, currentKeynode);
        }
        
        /* Storing generated shared key in DH struct for key node */
        assert(BN_bin2bn(sharedKey, DH_size(diffieHellmanKeys), currentKeynode->priv_key)!=NULL);
        // DEBUGMSG(@"Error: %@", [NSString stringWithFormat:@"ERROR: %s", ERR_error_string(ERR_get_error(),NULL)]);

        /* If position 1 or 0 */
        if((position < 2) && (currentKeyNodeNumber < [userIDs count]))
        {
            /* Send exponentiated keynode to server */
            BN_mod_exp(expKeynode, currentKeynode->g, currentKeynode->priv_key, currentKeynode->p, expContext);
            int keynodeRequest[4+DH_size(diffieHellmanKeys)/sizeof(int)];
            keynodeRequest[0] = htonl(version);
            keynodeRequest[1] = htonl([userID intValue]);
            keynodeRequest[2] = htonl([[userIDs objectAtIndex:currentKeyNodeNumber] intValue]);
            keynodeRequest[3] = htonl(DH_size(diffieHellmanKeys));
            BN_bn2bin(expKeynode, (unsigned char*)(&keynodeRequest[4]));
            [self doPostToPage: @"syncKeyNodes" withBody: [NSData dataWithBytes:&keynodeRequest length:16+DH_size(diffieHellmanKeys)]];
            state = SyncMatch;
        }
        /* Repeat till all keynodes have been generated */ 
        currentKeyNodeNumber++;
    }
    
    // compute group DH key
    self.groupKey = [NSData dataWithBytes:sharedKey length: DH_size(diffieHellmanKeys)];
    DEBUGMSG(@"Group key: %@", [groupKey hexadecimalString]);
    
    BN_CTX_free(expContext);
    BN_free(pubKey);
    BN_free(expKeynode);
    DH_free(currentKeynode);
    free(sharedKey);
    
    [allUsers removeAllObjects];
	[allUsers addObject: userID];
    
    // key = sha3(1||groupKey)
    NSString *k = @"1";
    NSData *keyHMAC = [k dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptionKey = [sha3 Keccak256HMAC:groupKey withKey:keyHMAC];
    match_nonce = [match_nonce AES256EncryptWithKey:encryptionKey matchNonce:groupKey];
    
    int len = 4 + 4 + 4 + 4 + (int)[match_nonce length];
	char buf[len];
    *(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
    // number of userids being sent
	*(int *)(buf + 8) = htonl(1);
    // same user id
	*(int *)(buf + 12) = *(int *)(buf + 4);
    [match_nonce getBytes: buf + 16 length:[match_nonce length]];
    
    self.state = SyncMatch;
    [self doPostToPage: @"syncMatch" withBody: [NSData dataWithBytes: buf length: len]];
    
}
-(void) handleSyncKeyNodes
{
    int position = 0;
    char* response;
    
    NSArray *userIDs = [self.allUsers sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for(int i = 0; i<[userIDs count]; i++){
        if([[userIDs objectAtIndex:i] isEqualToString:userID]) position = i;
    }

    if(position == 0 || position == 1){
        return;
    }
    else{
        
        response = [serverResponse mutableBytes];
        self.serverVersion = ntohl(*(int *)response);
        
        if(self.serverVersion==0)
        {
            NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server Message: %@"),
                             [NSString stringWithCString:response+8 encoding:NSUTF8StringEncoding]];
            state = NetworkFailure;
            [self.delegate DisplayMessage: msg];
            return;
        }
        
        int keyNodeFound = ntohl(*(int *)(response + 4));
        DEBUGMSG(@"keyNodeFound = %d", keyNodeFound);
        if(keyNodeFound){
            int length = ntohl(*(int *)(response + 8));
            DEBUGMSG(@"keyNode size = %d", length);
            NSData *keyNode = [NSData dataWithBytes:response + 12 length:length];
            [self.keyNodes setObject:keyNode forKey:[NSNumber numberWithInt:position]];
            [self syncKeyNodes];
        }
        else{
            retries++;
            if (retries > MAX_RETRY)
            {
                state = ProtocolTimeout;
                [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_TimeoutWaitingForAllMembers", @"Timeout waiting for some group members to add data.")];
                return;
            }
            NSTimer *retryTimer = [NSTimer timerWithTimeInterval: retries*RETRYTIMEOUT
                                                 target: self
                                               selector: @selector(retrySyncKeyNode)
                                               userInfo: nil
                                                repeats: NO];
            NSRunLoop *rl = [NSRunLoop currentRunLoop];
            [rl addTimer: retryTimer forMode: NSDefaultRunLoopMode];
            return;
        }
    }
    self.retries = 0;
}

-(void) retrySyncKeyNode
{
    // try to get DH node according to self position
    int keynodeRequest[2];
    keynodeRequest[0] = htonl(version);
    keynodeRequest[1] = htonl([userID intValue]);
    [self doPostToPage: @"syncKeyNodes" withBody: [NSData dataWithBytes:&keynodeRequest length:4+4]];
}

-(void) handleSyncMatch
{
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
    
    if(self.serverVersion==0)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server Message: %@"),
                         [NSString stringWithCString:response+8 encoding:NSUTF8StringEncoding]];
        state = NetworkFailure;
        [self.delegate DisplayMessage: msg];
        return;
    }
    
    int count = ntohl(*(int *)(response + 4));
    // number of items
    int delta_count = ntohl(*(int *)(response + 8));
    
    if (delta_count > users || count > users) {
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_MoreDataThanUsers", @"Unexpected data found in exchange. Begin the exchange again.")];
        return;
    }
    
    // count of entries
    if(delta_count>0)
    {
        char *ptr = response + 12;
        for (int i = 0; i < delta_count; i++)
        {
            // user id
            NSString *uid = [NSString stringWithFormat: @"%d", ntohl(*(int *)ptr)];
            
            ptr += 4;
            // length
            int length = ntohl(*(int *)ptr);
            ptr += 4;
            
            NSString *k = @"1";
            //for HMAC-SHA1
            NSData *keyHMAC = [k dataUsingEncoding:NSUTF8StringEncoding];
            
            //get key to decrypt contact data.
            NSData *decryptionKey = [sha3 Keccak256HMAC:self.groupKey withKey:keyHMAC];
            NSData* keyNonce = [NSData dataWithBytes:ptr length:length];
            keyNonce = [keyNonce AES256DecryptWithKey:decryptionKey matchNonce: groupKey];
            NSData *nh = [sha3 Keccak256Digest: keyNonce];
            NSData *meh = [matchExtraHashSet objectForKey:uid];
            
            // verify if match
            // SHA1 of nonce match equals matchExtraHash
            // Also make sure that neither is nil
            if (meh != nil && nh != nil && [meh isEqualToData:nh])
            {
                ptr += length;
                [matchNonceSet setValue: keyNonce forKey: uid];
            }
            // if not match
            else
            {
                // Marked by Tenma, this line might be reached while users >= 9
                self.state = ProtocolCancel;
                [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_InvalidCommitVerify", @"An error occurred during commitment verification.")];
                return;
            }
            
            if (![uid isEqualToString: userID])
                [allUsers addObject: uid];
        }
    }
	
	if ([allUsers count] < users)
	{
		retries++;
		if (retries > MAX_RETRY)
		{
            state = ProtocolTimeout;
            [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_TimeoutWaitingForAllMembers", @"Timeout waiting for some group members to add data.")];
			return;
		}
		NSTimer *retryTimer = [NSTimer timerWithTimeInterval: retries*RETRYTIMEOUT
                                                  target: self
                                                selector: @selector(retrySyncMatch)
                                                userInfo: nil
                                                 repeats: NO];
		NSRunLoop *rl = [NSRunLoop currentRunLoop];
		[rl addTimer: retryTimer forMode: NSDefaultRunLoopMode];
		return;
	}
    
    self.retries = 0;
    [allUsers removeAllObjects];
	[allUsers addObject: userID];
    [self decryptExchangedata];
}


- (void) retrySyncMatch
{
    int len = 12 + (4 * (int)[allUsers count]);
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl([allUsers count]);
    
	char *ptr = buf + 12;
	for (int i = 0; i < [allUsers count]; i++)
	{
		*(int *)ptr = htonl([[allUsers objectAtIndex: i] intValue]);
		ptr += 4;
	}
    [self doPostToPage: @"syncMatch" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) retrySyncSigs
{
	int len = 12 + (4 * (int)[allUsers count]);
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl([allUsers count]);
	char *ptr = buf + 12;
	for (int i = 0; i < [allUsers count]; i++)
	{
		*(int *)ptr = htonl([[allUsers objectAtIndex: i] intValue]);
		ptr += 4;
	}
	[self doPostToPage: @"syncSignatures" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) decryptExchangedata
{
    NSMutableArray *GatherDataSet = [NSMutableArray array];
    
    NSArray *allKeys = [encrypted_dataSet allKeys];
    for (int i = 0; i < [allKeys count]; i++)
    {
        NSString *key = [allKeys objectAtIndex: i];
        if ([key isEqualToString: userID])
            continue;
			
        NSData *exchangeData = [encrypted_dataSet objectForKey: key];
        //get matchnonce for particular user id
        NSData *mN = [matchNonceSet objectForKey:key];
        
        NSString *k = @"1";
        NSData *keyHMAC = [k dataUsingEncoding:NSUTF8StringEncoding];
        
        //get key to decrypt contact data. Using SHA3
        NSData *decryptionKey = [sha3 Keccak256HMAC:mN withKey:keyHMAC];
        [GatherDataSet addObject:[exchangeData AES256DecryptWithKey:decryptionKey matchNonce:mN]];
    }
    
    // stop the activity window.
    [delegate.actWindow.view removeFromSuperview];
    // finish the protocol
    state = ProtocolSuccess;
    [delegate DisplayMessage:nil];
    [delegate.mController EndExchange:RESULT_EXCHANGE_OK ErrorString:nil ExchangeSet:GatherDataSet];
}

@end
