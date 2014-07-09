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

#import <openssl/rand.h>
#import <openssl/err.h>

#import "Base64.h"
#import <sha3/sha3.h>

#define DH_PRIME "B028E9B70DEE5D3C1EACA1E0FACE73ECC89B9B90B106062BDA9D622C58CB47D4FEFD539DE528B68B90B8A93E9142735AFAD0D2D8D67B32528306D0E66AF77BB3"
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
@synthesize connection;
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
	
	self.serverResponse = [[NSMutableData alloc] init];
	NSURL *url = [NSURL URLWithString: page relativeToURL: serverURL];
	[request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: body];
	self.connection = [NSURLConnection connectionWithRequest: request delegate: self];
	[connection start];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	[serverResponse resetBytesInRange: NSMakeRange(0, [serverResponse length])];
}

-(void) doSyncPostToPage: (NSString *) page withBody: (NSData*) body
{
	DEBUGMSG(@"Do Sync POST to Relatuve URL: %@", page);
	DEBUGMSG(@"DATA: %@", body);
    
    // Synchronously grab the data
   	NSURL *url = [NSURL URLWithString: page relativeToURL: serverURL];
	[request setURL: url];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody: body];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    NSError        *error;
    NSURLResponse  *response;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSInteger status = [(NSHTTPURLResponse *)response statusCode];
	
    DEBUGMSG(@"HTTP response code: %ld", (long)status);
    if (status != 200)
	{
		DEBUGMSG(@"HTTP header: %@", [(NSHTTPURLResponse *)response allHeaderFields]);
        NSString* err = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_HttpCode", @"Server HTTP error: %d"), status];
        state = NetworkFailure;
        [self.delegate DisplayMessage: err];
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
	DEBUGMSG(@"Start SafeSlinger Exchange Protocol.");
	
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
	[data_commitment getBytes: ptr + 4];
    
    [delegate.actWindow DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"lib_name", @"SafeSlinger Exchange") Detail:NSLocalizedStringFromBundle(delegate.res, @"prog_RequestingUserId", @"requesting membership...")];
    [delegate.groupView.view addSubview:delegate.actWindow.view];
    
	self.state = AssignUser;
	[self doPostToPage: @"assignUser" withBody: [NSData dataWithBytes: ptr length: HASHLEN + 4]];
	free(ptr);
}

-(void) handleAssignUser
{
	[delegate.actWindow.view removeFromSuperview];
	
    const char *response = [serverResponse bytes];
	self.serverVersion = ntohl(*(int *)response);
    if(ntohl(*(int *)(response + 4))==0)
    {
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessage", @"Server message: '%@'"), response + 8];
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
        delegate.groupView.AssignedID.text = userID;
        [delegate.groupView.LowestID becomeFirstResponder];
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
	[data_commitment getBytes: buf + 20];
    
    NSString *title = [NSString stringWithFormat:@"%@, %@",
                       [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"choice_NumUsers", @"%d users"), users],
                       [NSString stringWithFormat: @"%@ %d", NSLocalizedStringFromBundle(delegate.res, @"label_UserIdHint", @"Lowest"), minID]];
    // NSLocalizedString(@"prog_CollectingOthersItems", @"waiting for all users to join...") ];
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
    DEBUGMSG(@"handleSyncUsers, data: %@", serverResponse);
    
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
	self.minVersion = ntohl(*(int *)(response + 4));
    DEBUGMSG(@"serverVersion = %02X, minVersion = %02X", serverVersion, minVersion);
	
	if (minVersion < MINICVERSION)
	{
        NSString* formatstring = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_AllMembersMustUpgrade", @"Some members are using an older version, all members must at least use %d."), self.version];
        state = NetworkFailure;
		[self.delegate DisplayMessage:formatstring];
		return;
	}
	
	// number of users
    int count = ntohl(*(int *)(response + 12));
    if (count >= users) {
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_MoreDataThanUsers", @"Unexpected data found in exchange. Begin the exchange again.")];
		return;
    }
    
    // Collect all data commitments Ci from other users
	char *ptr = response + 16;
	for (int i = 0; i < count; i++)
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
    int len = 4 + 4 + 4 + 4 + HASHLEN + [encrypted_data length] + DHPubKeySize;
	char buf[len];
	*(int *)buf = htonl(version);
	*(int *)(buf + 4) = htonl([userID intValue]);
	*(int *)(buf + 8) = htonl(1);
	*(int *)(buf + 12) = *(int *)(buf + 4);
    
    // HNi
    [protocol_commitment getBytes: buf + 16];
    // Gi
    BN_bn2bin(diffieHellmanKeys->pub_key, (unsigned char*)(buf + 16 + HASHLEN));
    // Ei
	[encrypted_data getBytes: buf + 16 + HASHLEN + DHPubKeySize];
    
	self.state = SyncData;
	[self doPostToPage: @"syncData" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) retrySyncUsers
{
	int len = 16 + (4 * [allUsers count]);
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
	DEBUGMSG(@"handleSyncData, data: %@", serverResponse);
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
	int total = ntohl(*(int *)(response + 4));
	if (total == 0)
	{
		NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessageCStr", @"Server Message: '%s'"), response + 8];
        state = NetworkFailure;
        [self.delegate DisplayMessage:msg];
		return;
	}
    
	int count = ntohl(*(int *)(response + 8));
	char *ptr = response + 12;
	for (int i = 0; i < count; i++)
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
	int len = 12
    + (4 * [allUsers count]);
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
		[match_extrahash getBytes: buf + 16];
		[wrong_hash getBytes: buf + 16 + HASHLEN];
        [delegate.actWindow DisplayMessage:Phrase Detail: NSLocalizedStringFromBundle(delegate.res, @"prog_CollectingOthersCommitVerify", @"waiting for verification from all members...")];
        [delegate.compareView.view addSubview:delegate.actWindow.view];
	}
	else
	{
		[match_hash getBytes: buf + 16];
		[wrong_nonce getBytes: buf + 16 + HASHLEN];
	}
    
	state = SyncSigs;
	[self doPostToPage: @"syncSignatures" withBody: [NSData dataWithBytes: buf length: len]];
}

-(void) handleSyncSigs
{
    if (wordListsDiffer) {
        state = ProtocolFail;
        [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_LocalGroupCommitDiffer", @"You have reported a difference in phrases. Begin the exchange again.")];
        return;
    }
    
	char *response = [serverResponse mutableBytes];
	self.serverVersion = ntohl(*(int *)response);
    
    // total signatures 
	int total = ntohl(*(int *)(response + 4));
	if (total == 0)
	{
        NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessageCStr", @"Server Message: '%s'"), response + 8];
        state = NetworkFailure;
		[self.delegate DisplayMessage: msg];
		return;
	}
    
    // count of entries
	int count = ntohl(*(int *)(response + 8));
	char *ptr = response + 12;
	for (int i = 0; i < count; i++)
	{
        // user id
		NSString *uid = [NSString stringWithFormat: @"%d", ntohl(*(int *)ptr)];
		ptr += 4;
		//int len = ntohl(*(int *)ptr);
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
            DEBUGMSG(@"Word List Match");
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
        
        // [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: %s", ERR_error_string(ERR_get_error(),NULL)]];

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
            [self doSyncPostToPage: @"syncKeyNodes" withBody: [NSData dataWithBytes:&keynodeRequest length:16+DH_size(diffieHellmanKeys)]];
            state = SyncMatch;
        }
        /* Repeat till all keynodes have been generated */ 
        currentKeyNodeNumber++;
    }
    
    // compute group DH key
    self.groupKey = [NSData dataWithBytes:sharedKey length: DH_size(diffieHellmanKeys)];
    DEBUGMSG(@"Group key %@", groupKey);
    
    BN_CTX_free(expContext);
    BN_free(pubKey);
    BN_free(expKeynode);
    DH_free(currentKeynode);
    free(sharedKey);
    
    [allUsers removeAllObjects];
	[allUsers addObject: userID];
    
    
    NSString *k = @"1";
    //for HMAC-SHA1
    NSData *keyHMAC = [k dataUsingEncoding:NSUTF8StringEncoding];
    
    // using sha3
    NSData *encryptionKey = [sha3 Keccak256HMAC:groupKey withKey:keyHMAC];
    match_nonce = [match_nonce AES256EncryptWithKey:encryptionKey matchNonce:groupKey];
    
    
    int len = 4 + 4 + 4 + 4 + [match_nonce length];
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
    int position;
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
        int keyNodeFound = ntohl(*(int *)(response + 4));
        
        DEBUGMSG(@"keyNodeFound = %d", keyNodeFound);
        if(keyNodeFound){
            int length = ntohl(*(int *)(response + 8));
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
    
    // total signatures 
	int total = ntohl(*(int *)(response + 4));
	if (total == 0)
	{
		NSString *msg = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_ServerAppMessageCStr", @"Server Message: '%s'"), response + 8];
        state = NetworkFailure;
		[self.delegate DisplayMessage: msg];
		return;
	}
    
    // count of entries
	int count = ntohl(*(int *)(response + 8));
    char *ptr = response + 12;
	for (int i = 0; i < count; i++)
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
			//NSData *mn = [NSData dataWithBytes: ptr length: NONCELEN];
			ptr += length;
			[matchNonceSet setValue: keyNonce forKey: uid];
		}
        // if not match
		else
		{
            // Marked by Tenma, this line might be reached while users >= 9
            [self.delegate DisplayMessage: NSLocalizedStringFromBundle(delegate.res, @"error_InvalidCommitVerify", @"An error occurred during commitment verification.")];
            return;
		}
        
		if (![uid isEqualToString: userID])
			[allUsers addObject: uid];
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
    int len = 12 + (4 * [allUsers count]);
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
	int len = 12 + (4 * [allUsers count]);
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
        [GatherDataSet addObject:[exchangeData AES256DecryptWithKey:decryptionKey matchNonce:mN] ];
    }
    
    // stop the activity window.
    [delegate.actWindow.view removeFromSuperview];
    // finish the protocol
    state = ProtocolSuccess;
    [delegate DisplayMessage:nil];
    [delegate.mController EndExchange:RESULT_EXCHANGE_OK ErrorString:nil ExchangeSet:GatherDataSet];
}

#pragma mark NSURLConnectionDelegate Methods
- (BOOL)connection: (NSURLConnection *)connection canAuthenticateAgainstProtectionSpace: (NSURLProtectionSpace *)protectionSpace
{
	return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection: (NSURLConnection *)connection didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *)challenge
{
	SecTrustRef trust = challenge.protectionSpace.serverTrust;
    SecTrustResultType trustResult;
    /* Check trust for chertificate. Important! */
    if (SecTrustEvaluate(trust, &trustResult) == errSecSuccess)
    {
        /* Handle cases where we trust the certificate here */
        if (trustResult == kSecTrustResultUnspecified ||
            trustResult == kSecTrustResultProceed)
        {
            /* For added security, we could add pinning here. */
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        } else {
            DEBUGMSG(@"ERROR: authentication challenge denied with validated result %d", trustResult);
            [challenge.sender cancelAuthenticationChallenge:challenge];
            state = NetworkFailure;
            [self.delegate DisplayMessage: [[challenge error]localizedDescription] ];
        }
    }else{
        /* not errSecSuccess */
        DEBUGMSG(@"ERROR: SecTrustEvaluate Failed.");
        [challenge.sender cancelAuthenticationChallenge:challenge];
        state = NetworkFailure;
        [self.delegate DisplayMessage: [[challenge error]localizedDescription] ];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	DEBUGMSG(@"connection error: %@ %@", [error localizedDescription], [[error userInfo] objectForKey: NSURLErrorFailingURLStringErrorKey]);
    state = NetworkFailure;
    [self.delegate DisplayMessage: [error localizedDescription]];
}

-(void) connection: (NSURLConnection *)connection didReceiveResponse: (NSURLResponse *)response
{
	int status = [(NSHTTPURLResponse *)response statusCode];
	DEBUGMSG(@"HTTP response code: %d", status);
	if (status != 200)
	{
		DEBUGMSG(@"HTTP header: %@", [(NSHTTPURLResponse *)response allHeaderFields]);
		NSString* err = [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_HttpCode", @"Server HTTP error: %d"), status];
        state = NetworkFailure;
        [self.delegate DisplayMessage:err];
	}
}

-(void) connection: (NSURLConnection *)connection didReceiveData: (NSData *) receivedData
{
	[serverResponse appendData: receivedData];
}

-(void) connectionDidFinishLoading: (NSURLConnection *)connection
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	const char *buf = [serverResponse bytes];
	DEBUGMSG(@"Response length: %lu", (unsigned long)[serverResponse length]);
    
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

@end
