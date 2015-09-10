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

#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <assert.h>
#include <stdio.h>

#import <AddressBook/AddressBook.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>
#import <MobileCoreServices/UTType.h>

#include <openssl/aes.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <openssl/bio.h>

#import "Utility.h"
#import "SSEngine.h"
#import "ErrorLogger.h"
#import "AppDelegate.h"
#import "SafeSlingerDB.h"

#define ENCKEYSIZE 2048
#define SIGNKEYSIZE 1024
#define EXPONENT 65537

@implementation SSEngine

+(NSString*)ExtractKeyID: (NSData*)packet
{
    char* keyid[128];
    memset(keyid, 0, 128);
    unsigned char *bytePtr = (unsigned char *)[packet bytes];
    memcpy(keyid, bytePtr, LENGTH_KEYID);
    return [NSString stringWithCString: (const char*)keyid encoding:NSASCIIStringEncoding];
}

+(BOOL)checkCredentialExist
{
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSData *keyid = [delegate.DbInstance GetConfig:@"KEYID"];
    NSData *keydate = [delegate.DbInstance GetConfig:@"KEYGENDATE"];
    NSData *encpub = [delegate.DbInstance GetConfig:@"ENCPUB"];
    NSData *signpub = [delegate.DbInstance GetConfig:@"SIGNPUB"];
    NSData *encpri  = [delegate.DbInstance GetConfig:@"ENCPRI"];
    NSData *signpri = [delegate.DbInstance GetConfig:@"SIGNPRI"];
	
	if (keydate&&keyid&&encpri&&encpub&&signpri&&signpub)
	{
        return YES;
	}else{
        return NO;
    }
}

+(void)LockPrivateKeys: (NSString*)Passphase RawData:(NSData*)plaintext Type:(int)keytype
{
    // infostr did not exist, encrypt anayway
    NSData* cipher = [self AESEncrypt:plaintext withAESKey:[NSData dataWithBytes:[Passphase UTF8String] length:[Passphase lengthOfBytesUsingEncoding:NSUTF8StringEncoding]]];
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    switch (keytype) {
        case ENC_PRI:
            [delegate.DbInstance InsertOrUpdateConfig:cipher withTag:@"ENCPRI"];
            break;
        case SIGN_PRI:
            [delegate.DbInstance InsertOrUpdateConfig:cipher withTag:@"SIGNPRI"];
            break;
        default:
            break;
    }
}

+(NSData*)UnlockPrivateKey: (NSString*)Passphase Size:(int)plen Type:(int)type
{
    NSData* cprikey = nil;
    cprikey = [self getPrivateKey:type];
    cprikey = [self AESDecrypt:cprikey withAESKey:[NSData dataWithBytes:[Passphase UTF8String] length:[Passphase lengthOfBytesUsingEncoding:NSUTF8StringEncoding]] withPlen:plen];
    return cprikey;
}

+(BOOL)TestPassPhase: (NSString*)Passphase KeySize1:(int)plen1 KeySize2:(int)plen2
{
    NSData* cprikey1 = [self getPrivateKey:ENC_PRI];
    NSData* cprikey2 = [self getPrivateKey:SIGN_PRI];
    
    cprikey1 = [self AESDecrypt:cprikey1 withAESKey:[NSData dataWithBytes:[Passphase UTF8String] length:[Passphase lengthOfBytesUsingEncoding:NSUTF8StringEncoding]] withPlen:plen1];
    cprikey2 = [self AESDecrypt:cprikey2 withAESKey:[NSData dataWithBytes:[Passphase UTF8String] length:[Passphase lengthOfBytesUsingEncoding:NSUTF8StringEncoding]] withPlen:plen2];
    
    // key verification
    NSString* key_a = [[NSString alloc]initWithBytes:[cprikey1 bytes] length:[cprikey1 length] encoding:NSASCIIStringEncoding];
    NSString* key_b = [[NSString alloc]initWithBytes:[cprikey2 bytes] length:[cprikey2 length] encoding:NSASCIIStringEncoding];
    
    if([key_a length]>0&&[key_b length]>0)
    {
        return YES;
    }else{
        return NO;
    }
}


+(NSString*)getSelfKeyID
{
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSData* keyid = [delegate.DbInstance GetConfig:@"KEYID"];
    
    if (keyid)
    {
        return [[NSString alloc]initWithBytes:[keyid bytes] length:[keyid length] encoding:NSUTF8StringEncoding];
    }else {
        return nil;
    }
}

+(NSString*)getSelfSubmissionToken
{
    // compute on the fly
    return [Base64 encode:[sha3 Keccak256Digest:[self getPubKey: SIGN_PUB]]];
}

+(NSString*)getSelfGenKeyDate
{
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSData* keygendate = [delegate.DbInstance GetConfig:@"KEYGENDATE"];
    
    if (keygendate)
    {
        return [NSString stringWithUTF8String: [keygendate bytes]];
    }else {
        return nil;
    }
}

+(NSData*)getPackPubKeys
{
    //NSError *error;
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    NSMutableData *pkeydata = [[NSMutableData alloc]initWithCapacity:0];
    
    NSData *pkey = [delegate.DbInstance GetConfig:@"ENCPUB"];
    NSData *spkey = [delegate.DbInstance GetConfig:@"SIGNPUB"];
    
    char* sep = " ";
    char* newline = "\n";
    
    if (pkey&&spkey)
    {
        // field 1: keyid, SHA-512 hash
        NSString* keyid = [self getSelfKeyID];
        if(keyid==nil) {
            NSLog(@"Error reading KeyID.");
            return nil;
        }
        
        [pkeydata appendBytes:[keyid cStringUsingEncoding:NSUTF8StringEncoding] length:[keyid lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        [pkeydata appendBytes:newline length:1];
        
        // field 2: get date string
        NSString *dateString = [self getSelfGenKeyDate];
        if(dateString==nil) {
            NSLog(@"Error reading KeyDate.");
            return nil;
        }
        
        [pkeydata appendBytes:[dateString cStringUsingEncoding:NSUTF8StringEncoding] length:[dateString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        [pkeydata appendBytes:newline length:1];
        // field 3: public keys
        // first public key (for encryption)
        [pkeydata appendData:pkey];
        [pkeydata appendBytes:sep length:1];
        // second public key (for sign)
        [pkeydata appendData:spkey];
        return pkeydata;
    }else {
        return nil;
    }
}

+(NSData*)getPubKey: (int)keytype
{
    NSData *pkey = nil;
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    switch (keytype) {
        case ENC_PUB:
            pkey = [delegate.DbInstance GetConfig:@"ENCPUB"];
            break;
        case SIGN_PUB:
            pkey = [delegate.DbInstance GetConfig:@"SIGNPUB"];
            break;
        default:
            break;
    }
    
    return pkey;
}

+(NSData*)getPrivateKey: (int)keytype
{
    NSData *rkey = nil;
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    switch (keytype) {
        case ENC_PRI:
            rkey = [delegate.DbInstance GetConfig:@"ENCPRI"];
            break;
        case SIGN_PRI:
            rkey = [delegate.DbInstance GetConfig:@"SIGNPRI"];
            break;
        default:
            break;
    }
    
    return rkey;
}

+(int)getSelfPrivateKeySize: (int)keytype
{
    int keysize = -1;
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    switch (keytype) {
        case ENC_PRI:
            keysize = (int)[[delegate.DbInstance GetConfig:@"ENCPRI"]length];
            break;
        case SIGN_PRI:
            keysize = (int)[[delegate.DbInstance GetConfig:@"SIGNPRI"]length];
            break;
        default:
            break;
    }
    return keysize;
}

+(NSData*)GenRandomBytes:(int)len_bytes
{
    unsigned char buf[len_bytes];
    int err = SecRandomCopyBytes(kSecRandomDefault, len_bytes, buf);
    if(err == noErr)
    {
        return [[NSData alloc] initWithBytes:buf length:len_bytes];
    }else{
        return nil;
    }
}

+(NSData*)Encrypt: (NSString*)pubkeyData keysize:(int)bits withData:(NSData*)text
{
    int ret;
    size_t olen;
    char* c;
    RSA *pubKey = NULL;
    unsigned char buf[2048];
    
    // format public key first
    olen = [pubkeyData length];
    c = (char*)[pubkeyData cStringUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *formatkey = [[NSMutableData alloc]initWithLength:0];
    NSString* header = @"-----BEGIN PUBLIC KEY-----\n";
    [formatkey appendBytes:[header cStringUsingEncoding:NSASCIIStringEncoding] length:[header length]];
    while (olen)
    {
        size_t use_len = olen;
        if (use_len > 64) use_len = 64;
        [formatkey appendBytes:c length:use_len];
        olen -= use_len;
        c += use_len;
        [formatkey appendBytes:"\n" length:1];
    }
    header = @"-----END PUBLIC KEY-----\n";
    [formatkey appendBytes:[header cStringUsingEncoding:NSASCIIStringEncoding] length:[header length]];
    
    BIO *mem = BIO_new(BIO_s_mem());
    BIO_puts(mem, [formatkey bytes]);
    pubKey = PEM_read_bio_RSA_PUBKEY(mem, NULL, NULL, NULL);
    if ( !pubKey ) {
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"PEM_read_bio_RSA_PUBKEY ERROR: %s\n", ERR_error_string(ERR_get_error(), NULL)]];
        BIO_free(mem);
        RSA_free(pubKey);
        return nil;
    }
    BIO_free(mem);
    
    if( [text length] > RSA_size(pubKey) )
    {
        [ErrorLogger ERRORDEBUG:@"Input data larger than Public-Key size.\n\n"];
        RSA_free(pubKey);
        return nil;
    }
    
    if ( (ret = RSA_public_encrypt((int)[text length], [text bytes], buf, pubKey, RSA_PKCS1_PADDING)) == -1 ) {
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"RSA_public_encrypt ERROR: %s\n", ERR_error_string(ERR_get_error(), NULL)]];
        RSA_free(pubKey);
        return nil;
    }
    
    NSData *cipher = [NSData dataWithBytes:buf length:ret];
    RSA_free(pubKey);
    return cipher;
}

+(NSData*)Decrypt: (NSData*)cipher withPrikey:(NSData*)keybytes
{
    int ret;
    RSA *priKey;
    unsigned char result[1024];
    unsigned char buf[512];
    
    BIO *mem = BIO_new(BIO_s_mem());
    BIO_puts(mem, [keybytes bytes]);
    priKey = EVP_PKEY_get1_RSA(PEM_read_bio_PrivateKey(mem, NULL, NULL, NULL));
    
    if (!priKey ) {
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"EVP_PKEY_get1_RSA ERROR: %s\n", ERR_error_string(ERR_get_error(), NULL)]];
        BIO_free(mem);
        RSA_free(priKey);
        return nil;
    }
    BIO_free(mem);
    
    memset(result, 0, 1024);
    memset(buf, 0, [cipher length]);
    memcpy(buf, [cipher bytes], [cipher length]);
    
    if ( (ret = RSA_private_decrypt((int)[cipher length], buf, result, priKey, RSA_PKCS1_PADDING)) == -1 ) {
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"RSA_private_decrypt ERROR: %s\n", ERR_error_string(ERR_get_error(), NULL)]];
        RSA_free(priKey);
        return nil;
    }
    
    RSA_free(priKey);
    NSData* decipher = [NSData dataWithBytes:result length:ret];
    return decipher;
}

+(BOOL)Verify: (NSString*)pubkeyData keySize:(int)bits withSig:(NSData*)sig withtext: (NSData*)text
{
    BOOL success = NO;
    int ret;
    int size;
    RSA *pubKey = NULL;
    unsigned char hash[20];
    int i, j, sigsize;
    size_t olen = 2048;
    char* c;
    unsigned char sig_buf[2048];
    CC_SHA1_CTX   ctx;
    
    // format public key first
    olen = [pubkeyData lengthOfBytesUsingEncoding:NSASCIIStringEncoding];
    c = (char*)[pubkeyData cStringUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *formatkey = [[NSMutableData alloc]initWithLength:0];
    NSString* header = @"-----BEGIN PUBLIC KEY-----\n";
    [formatkey appendBytes:[header cStringUsingEncoding:NSASCIIStringEncoding] length:[header length]];
    while (olen)
    {
        size_t use_len = olen;
        if (use_len > 64) use_len = 64;
        [formatkey appendBytes:c length:use_len];
        olen -= use_len;
        c += use_len;
        [formatkey appendBytes:"\n" length:1];
    }
    header = @"-----END PUBLIC KEY-----\n";
    [formatkey appendBytes:[header cStringUsingEncoding:NSASCIIStringEncoding] length:[header length]];
    
    BIO *mem = BIO_new(BIO_s_mem());
    BIO_puts(mem, [formatkey bytes]);
    pubKey = PEM_read_bio_RSA_PUBKEY(mem, NULL, NULL, NULL);
    if ( !pubKey ) {
        DEBUGMSG(@"%s\n", ERR_error_string(ERR_get_error(), NULL));
        BIO_free(mem);
        RSA_free(pubKey);
        return success;
    }
    
    size = bits/8;
    // base64 decoding for signature file
    sigsize = (int)[sig length];
    memset(sig_buf, 0, 2048);
    memcpy(sig_buf, [sig bytes], sigsize);
    
    if( sigsize != RSA_size(pubKey) )
    {
        DEBUGMSG( @"\n  ! Invalid RSA signature format\n\n" );
        BIO_free(mem);
        RSA_free(pubKey);
        return success;
    }
    
    // compute text hash
    int plen = (int)[text length];
    unsigned char* p = (unsigned char*)[text bytes];
    j = (int)ceil((float)(plen/1024.0f));
    
    CC_SHA1_Init(&ctx);
    for( i = 0; i < j; i++)
    {
        if(plen>1024){
            CC_SHA1_Update(&ctx, p, 1024);
            plen = plen - 1024;
            p = p + 1024;
        }else
            CC_SHA1_Update(&ctx, p, plen);
    }
    CC_SHA1_Final(hash, &ctx);
    
    if( ( ret = RSA_verify(NID_sha1, hash, 20, sig_buf, sigsize, pubKey) ) == -1 )
    {
        DEBUGMSG( @" failed\n  ! RSA_verify returned %d\n\n", ret );
        BIO_free(mem);
        RSA_free(pubKey);
        return success;
    }
    
    success = YES;
    BIO_free(mem);
    RSA_free(pubKey);
    return success;
}

+(NSData*)Sign: (NSData*)text withPrikey:(NSData*)keybytes
{
    RSA *priKey;
    int ret, i, j;
    unsigned int sig_size;
    CC_SHA1_CTX   ctx;
    unsigned char hash[20];
    unsigned char buf[2048];
    unsigned char* p;
    int plen = 0;
    
    if(text==nil)
    {
        DEBUGMSG(@" failed\n  !  Plaintext is nil\n\n");
        return nil;
    }
    
    BIO *mem = BIO_new(BIO_s_mem());
    BIO_puts(mem, [keybytes bytes]);
    priKey = EVP_PKEY_get1_RSA(PEM_read_bio_PrivateKey(mem, NULL, NULL, NULL));
    if ( !priKey ) {
        [ErrorLogger ERRORDEBUG:[NSString stringWithFormat: @"EVP_PKEY_get1_RSA ERROR: %s\n", ERR_error_string(ERR_get_error(), NULL)]];
        BIO_free(mem);
        RSA_free(priKey);
        return nil;
    }
 
    plen = (int)[text length];
    p = (unsigned char*)[text bytes];
    j = (int)ceil((float)(plen/1024.0f));
    
    CC_SHA1_Init(&ctx);
    for( i = 0; i < j; i++)
    {
        if(plen>1024){
            CC_SHA1_Update(&ctx, p, 1024);
            plen = plen - 1024;
            p = p + 1024;
        }else
            CC_SHA1_Update(&ctx, p, plen);
    }
    CC_SHA1_Final(hash, &ctx);
    
    if( ( ret = RSA_sign(NID_sha1, hash, 20, buf, &sig_size, priKey) ) == -1 )
    {
        DEBUGMSG( @" failed\n  ! RSA_sign returned %d\n\n", ret );
        BIO_free(mem);
        RSA_free(priKey);
        return nil;
    }
    
    NSData* sig = [NSData dataWithBytes:buf length:sig_size];
    BIO_free(mem);
    RSA_free(priKey);
    return sig;
}

+(int)GenRSAKey:(int)bits WithType:(int)keytype
{
    int ret = 0;
    RSA *rsa = NULL;
    BIGNUM *e = NULL;
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    rsa = RSA_new();
    e = BN_new();
    BN_set_word(e, EXPONENT);
    if (!RSA_generate_key_ex(rsa, bits, e, NULL))
    {
        DEBUGMSG( @" failed\n  ! rsa_gen_key returned %d\n\n", ret );
        RSA_free( rsa );
        return -1;
    }
    
    BIO *prifile = BIO_new(BIO_s_mem());
    if (!PEM_write_bio_RSAPrivateKey(prifile, rsa, NULL, NULL, 0, 0, NULL))
    {
        DEBUGMSG(@"PEM_write_bio_RSAPrivateKey Error.");
        [ErrorLogger ERRORDEBUG: @"PEM_write_bio_RSAPrivateKey Error."];
        RSA_free( rsa );
        BIO_free(prifile);
        return -1;
    }
    
    size_t prikey_s = BIO_ctrl_pending(prifile);
    unsigned char* p = malloc(prikey_s);
    memset(p, 0, prikey_s);
    BIO_read(prifile, p, (int)prikey_s);
    NSData* pridata = [[NSData alloc]initWithBytes:p length:prikey_s];
    
    if(keytype==ENC_PRI)
        [delegate.DbInstance InsertOrUpdateConfig:pridata withTag: @"ENCPRI"];
    else if(keytype==SIGN_PRI)
        [delegate.DbInstance InsertOrUpdateConfig:pridata withTag: @"SIGNPRI"];
    
    free(p);
    BIO_free(prifile);
    
    BIO *pubfile = BIO_new(BIO_s_mem());
    if (!PEM_write_bio_RSA_PUBKEY(pubfile, rsa))
    {
        DEBUGMSG(@"PEM_write_bio_RSA_PUBKEY Error.");
        [ErrorLogger ERRORDEBUG: @"PEM_write_bio_RSA_PUBKEY Error."];
        RSA_free( rsa );
        BIO_free(pubfile);
        return -1;
    }
    
    size_t pubkey_s = BIO_ctrl_pending(pubfile);
    p = malloc(pubkey_s);
    memset(p, 0, pubkey_s);
    BIO_read(pubfile, p, (int)pubkey_s);
    
    NSString* pubstr = [[NSString alloc]initWithBytes:p length:pubkey_s encoding:NSASCIIStringEncoding];
    pubstr = [pubstr stringByReplacingOccurrencesOfString:@"-----BEGIN PUBLIC KEY-----" withString:@""];
    pubstr = [pubstr stringByReplacingOccurrencesOfString:@"-----END PUBLIC KEY-----" withString:@""];
    pubstr = [pubstr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    pubstr = [pubstr stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSData* pubdata = [[NSData alloc]initWithBytes:[pubstr cStringUsingEncoding:NSASCIIStringEncoding] length:[pubstr lengthOfBytesUsingEncoding:NSASCIIStringEncoding]];
    
    if(keytype==ENC_PRI)
        [delegate.DbInstance InsertOrUpdateConfig:pubdata withTag: @"ENCPUB"];
    else if(keytype==SIGN_PRI)
        [delegate.DbInstance InsertOrUpdateConfig:pubdata withTag: @"SIGNPUB"];
    
    pubdata = nil;
    RSA_free(rsa);
    free(p);
    BIO_free(pubfile);
    
    DEBUGMSG(@"GenKey Done.");
    return ret;
}

+(BOOL)GenKeyPairForENC
{
    BOOL ret = NO;
    
	if([self GenRSAKey:ENCKEYSIZE WithType:ENC_PRI]==0)
    {
        DEBUGMSG(@"GenRSAKey Okay.");
        ret = YES;
    }
    
    // Generate Keygen date
    NSDate *today = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [dateFormat setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSString *dateString = [dateFormat stringFromDate:today];
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    [delegate.DbInstance InsertOrUpdateConfig:[dateString dataUsingEncoding:NSUTF8StringEncoding] withTag: @"KEYGENDATE"];
    
    return ret;
}

+(BOOL)GenKeyPairForSIGN
{
    CC_SHA512_CTX   ctx;
    unsigned char keyidarray[64];
    BOOL ret = NO;
	
    if([self GenRSAKey:SIGNKEYSIZE WithType:SIGN_PRI]==0)
    {
        DEBUGMSG(@"GenRSAKey Okay.");
        ret = YES;
    }
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    NSData *pkey = [delegate.DbInstance GetConfig:@"ENCPUB"];
    NSData *spkey = [delegate.DbInstance GetConfig:@"SIGNPRI"];
    
    // Compute KeyID
    NSMutableData *pkeydata = [[NSMutableData alloc]initWithCapacity:0];
    // first public key (for encryption)
    [pkeydata appendData:pkey];
    [pkeydata appendBytes:" " length:1];
    // second public key (for sign)
    [pkeydata appendData:spkey];
    
    // compute sha512 hash
    memset(keyidarray, 0, 64);
    CC_SHA512_Init(&ctx);
    CC_SHA512_Update(&ctx, [pkeydata bytes], (int)[pkeydata length]);
    CC_SHA512_Final(keyidarray, &ctx);
    NSString *idstr = [Base64 encode:[NSData dataWithBytes:keyidarray length:64]];
    
    [delegate.DbInstance InsertOrUpdateConfig:[idstr dataUsingEncoding:NSUTF8StringEncoding] withTag: @"KEYID"];
    
    return ret;
}

+(NSData*)AESEncrypt: (NSData*)plain withAESKey: (NSData*)secret
{
    int i, n;
    off_t psize, offset;
    NSInteger keylen;
    unsigned char IV[16];
    unsigned char key[512];
    unsigned char digest[32];
    unsigned char buffer[16];
    unsigned char* source;
    NSMutableData* output = [NSMutableData dataWithCapacity:[plain length]];
    
    CC_SHA256_CTX   ctx;
    CCHmacContext   hctx;
    AES_KEY         enc_key;
    
    psize = [plain length];
    source = (unsigned char*)[plain bytes];
    
    // copy key to key buffer
    memset( key, 0,  512 );
    memcpy( key, [secret bytes], [secret length]);
    keylen = [secret length];
 
    memset( IV, 0, 16);
 
    [output appendBytes:IV length:16];
 
    memset( digest, 0,  32 );
    
    for( i = 0; i < 8192; i++ )
    {
        CC_SHA256_Init(&ctx);
        CC_SHA256_Update(&ctx, digest, 32);
        CC_SHA256_Update(&ctx, key, (CC_LONG)keylen);
        CC_SHA256_Final(digest, &ctx);
    }
    
    memset( key, 0, sizeof( key ) );
    AES_set_encrypt_key(digest, 256, &enc_key);
    CCHmacInit( &hctx, kCCHmacAlgSHA256, digest, 32);
    for( offset = 0; offset < psize; offset += 16 )
    {
        n = ( psize - offset > 16 ) ? 16 : (int)( psize - offset );
        memset(buffer, 0, n);
        memcpy(buffer, source+offset, n);
        for( i = 0; i < 16; i++ )
            buffer[i] = (unsigned char)( buffer[i] ^ IV[i] );
        AES_ecb_encrypt(buffer, buffer, &enc_key, AES_ENCRYPT);
        CCHmacUpdate( &hctx, buffer, 16 );
        [output appendBytes:buffer length:16];
        memcpy( IV, buffer, 16 );
    }
    CCHmacFinal( &hctx, digest );
    
    [output appendBytes:digest length:32];
    memset( buffer, 0, sizeof( buffer ) );
    memset( digest, 0, sizeof( digest ) );
    
    return [NSData dataWithData: output];
}

+(NSData*)AESDecrypt: (NSData*)cipher withAESKey: (NSData*)secret withPlen: (int)lengthOfPlain
{
    int i, n;
    off_t csize, offset;
    int lastn, keylen;
    unsigned char IV[16];
    unsigned char key[512];
    unsigned char digest[32];
    unsigned char buffer[32];
    unsigned char* source;
    
    CC_SHA256_CTX   ctx;
    CCHmacContext   hctx;
    AES_KEY         enc_key;
    
    NSMutableData* output = [NSMutableData dataWithCapacity:lengthOfPlain];
    
    csize = [cipher length];
    source = (unsigned char*)[cipher bytes];
    
    // copy key to key buffer
    memset( key, 0,  512 );
    memcpy( key, [secret bytes], [secret length]);
    keylen = (int)[secret length];
    
    unsigned char tmp[16];
    
    if( csize < 48 )
    {
        DEBUGMSG(@"Ciphertext is too short to be encrypted.\n" );
        return NULL;
    }
    
    if( ( csize & 0x0F ) != 0 )
    {
        DEBUGMSG(@"File size not a multiple of 16.\n" );
        return NULL;
    }
 
    csize -= ( 16 + 32 );
    
    // memcpy(buffer, source, 16);
    memset( IV, 0,  16 );
    memcpy( IV, source, 16 );
    source = source + 16;
    // lastn is computed directly here
    lastn = lengthOfPlain & 0x0F;
 
    memset( digest, 0,  32 );
    
    for( i = 0; i < 8192; i++ )
    {
        CC_SHA256_Init(&ctx);
        CC_SHA256_Update(&ctx, digest, 32);
        CC_SHA256_Update(&ctx, key, keylen);
        CC_SHA256_Final(digest, &ctx);
    }
    
    memset( key, 0, sizeof( key ) );
    AES_set_decrypt_key(digest, 256, &enc_key);
    CCHmacInit( &hctx, kCCHmacAlgSHA256, digest, 32);
    for( offset = 0; offset < csize; offset += 16 )
    {
        memset( buffer, 0,  32 );
        memcpy( buffer, source+offset, 16 );
        memcpy( tmp, buffer, 16 );
        CCHmacUpdate( &hctx, buffer, 16 );
        AES_ecb_encrypt(buffer, buffer, &enc_key, AES_DECRYPT);
        for( i = 0; i < 16; i++ )
            buffer[i] = (unsigned char)( buffer[i] ^ IV[i] );
        
        memcpy( IV, tmp, 16 );
        n = ( lastn > 0 && offset == csize - 16 ) ? lastn : 16;
        [output appendBytes:buffer length:n];
    }
    CCHmacFinal( &hctx, digest );
    
    memset( buffer, 0, 32);
    memcpy( buffer, source+offset, 32 );
    
    if( memcmp( digest, buffer, 32 ) != 0 )
    {
        DEBUGMSG( @"HMAC check failed: wrong key, or ciphertext corrupted.\n" );
        return NULL;
    }
    
    return [NSData dataWithData:output];
}

+(NSData*)PackMessage:(NSData*)plain PubKey:(NSString*)puk Prikey:(NSData*)pri
{
    int pLen;
    CC_SHA1_CTX   ctx;
    unsigned char hash[20];
    NSString* pubkey;
    
    // handel public key first
    NSArray* pubset = [puk componentsSeparatedByString:@" "];
    pubkey = [pubset objectAtIndex:0];
    
    // prepare packet
    NSMutableData* pack = [NSMutableData dataWithCapacity:0];
    NSMutableData* pubEncData = [NSMutableData dataWithCapacity:0];
    
    // prepare symmetric cipher first
    NSData* skey = [self GenRandomBytes: 64];
    // Encrypt UTF8 Data
    NSData* mcipher = [self AESEncrypt:plain  withAESKey:skey];
    
    // perform Sign/Encrypt/Sign model on symmetric key
    // getSelfPrivateKeyPath; YES for Encrypt, No for Sign
    pLen = htonl([plain length]);
    // Symmetric key || data length
    [pubEncData appendData:skey];
    [pubEncData appendBytes:&pLen length:4];
    
    // decrpyt privet key if possible
    NSData* sig = [self Sign: pubEncData withPrikey:pri];
    
    [pack appendData:pubEncData];
    [pack appendData:sig];
    NSData* cipher = [self Encrypt:pubkey keysize:2048 withData:pack];
    
    [pack setLength:0];
    [pack appendData:cipher];
    // compute public key hash
    CC_SHA1_Init( &ctx );
    CC_SHA1_Update( &ctx, (const unsigned char*)[pubkey cStringUsingEncoding:NSASCIIStringEncoding], (CC_LONG)[pubkey lengthOfBytesUsingEncoding:NSASCIIStringEncoding] );
    CC_SHA1_Final( hash, &ctx);
    
    [pack appendBytes:hash length:20];
    
    // sign again
    sig = [self Sign: pack withPrikey:pri];
    
    // constructu the packet
    [pack setLength:0];
    
    // pack keyid, SHA-512 hash
	AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    NSData* keyid = [delegate.DbInstance GetConfig:@"KEYID"];
    
    [pack appendData:[NSData dataWithBytes:[keyid bytes] length:[keyid length]]];
    [pack appendData:cipher];
    [pack appendData:sig];
    [pack appendData:mcipher];
    
    // release temperal objects
    return pack;
}

+(NSData*)UnpackMessage:(NSData*)cipher PubKey:(NSString*)puk Prikey:(NSData*)pri
{
    // hash
    int clen, plen;
    CC_SHA1_CTX   ctx;
    unsigned char hash[20];
    unsigned char skey[64];
    unsigned char pcipher[ENCKEYSIZE/8];
    unsigned char sig[SIGNKEYSIZE/8];
    char* s = NULL;
    size_t mclen;
    
    // handel public key first
    NSArray* pubset = [puk componentsSeparatedByString:@" "];
    // peer public key for verification
    NSString* pubkey = [pubset objectAtIndex:1];
    
    NSMutableData* unpack = [NSMutableData dataWithCapacity:0];
    s = (char*)[cipher bytes];
    mclen = [cipher length]-(ENCKEYSIZE/8)-(SIGNKEYSIZE/8);
    
    // first we have read the packet each by each
    // 1. public key cipher, 256 bytes
    memset(pcipher, 0, ENCKEYSIZE/8);
    memcpy(pcipher, s, ENCKEYSIZE/8);
    
    // 2. signature, 128 bytes
    s = s + ENCKEYSIZE/8;
    memset(sig, 0, SIGNKEYSIZE/8);
    memcpy(sig, s, SIGNKEYSIZE/8);
    
    // verify signature first
    [unpack setLength:0];
    [unpack appendBytes:pcipher length:ENCKEYSIZE/8];
    NSData* selfpuk = [self getPubKey:YES];
    // compute public key hash
    CC_SHA1_Init( &ctx );
    CC_SHA1_Update( &ctx, (const unsigned char*)[selfpuk bytes], (CC_LONG)[selfpuk length] );
    CC_SHA1_Final( hash, &ctx);
    [unpack appendBytes:hash length:20];
    
    if(![self Verify:pubkey keySize:1024 withSig:[NSData dataWithBytes:sig length:(SIGNKEYSIZE/8)] withtext:unpack])
    {
        [ErrorLogger ERRORDEBUG: @"1st Signature Verificaiton Failed."];
        return nil;
    }
    [unpack setLength:0];
    
    // then decrypt
    NSData* decipher = [self Decrypt: [NSData dataWithBytes:pcipher length:ENCKEYSIZE/8] withPrikey:pri];
    
    if(!decipher)
    {
        [ErrorLogger ERRORDEBUG: @"Public key decryption error, Cipher is zero."];
        return nil;
    }
    
    memset(skey, 0, 64);
    memcpy(skey, [decipher bytes], 64);
    memcpy(&plen, [decipher bytes]+64, 4);
    plen = ntohl(plen);
    
    memset(sig, 0, SIGNKEYSIZE/8);
    memcpy(sig, [decipher bytes]+68, SIGNKEYSIZE/8);
    
    NSRange r;
    r.location = 0;
    r.length = 68;// key+ plen
    
    if(![self Verify:pubkey keySize:1024 withSig:[NSData dataWithBytes:sig length:(SIGNKEYSIZE/8)] withtext:[decipher subdataWithRange:r]])
    {
        [ErrorLogger ERRORDEBUG: @"2nd Signature Verificaiton Failed."];
        return nil;
    }
    
    // 3. remaindering, block cipher
    s = s + SIGNKEYSIZE/8;
    clen = (int)[cipher length]-(SIGNKEYSIZE/8)-(ENCKEYSIZE/8);
    NSData* mciper = [NSData dataWithBytes:s length:clen];
    NSData* mdcipher = [self AESDecrypt:mciper withAESKey:[NSData dataWithBytes:skey length:64] withPlen:plen];
    
    return mdcipher;
}

+ (NSData *)BuildCipher:(NSString *)keyid Message:(NSData *)Message Attach:(NSString *)FileName RawFile:(NSData *)rawFile MIMETYPE:(NSString *)MimeType Cipher:(NSMutableData *)cipher {
    NSData* packnonce = nil;
    NSData* encryptMsg = nil;
    NSData* encryptFile = nil;
    
    AppDelegate *delegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    // get Sign private key
    int PRIKEY_STORE_FORSIGN_SIZE = 0;
    [[delegate.DbInstance GetConfig:@"PRIKEY_STORE_FORSIGN_SIZE"] getBytes:&PRIKEY_STORE_FORSIGN_SIZE length:sizeof(PRIKEY_STORE_FORSIGN_SIZE)];
    NSData* SignKey = [SSEngine UnlockPrivateKey:delegate.tempralPINCode Size:PRIKEY_STORE_FORSIGN_SIZE Type:SIGN_PRI];
    
    // get Token
    NSString* token = [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"ptoken"];
    NSString* username = [NSString humanreadable: [delegate.DbInstance QueryStringInTokenTableByKeyID:keyid Field:@"pid"]];
    int devtype = [delegate.DbInstance GetDeviceType: keyid];
    
    // encrypt the file first if necessary
    if(FileName) {
        encryptFile = [SSEngine PackMessage:rawFile PubKey:[delegate.DbInstance GetRawKey: keyid] Prikey:SignKey];
    }
    
    //Prepare Message Format
    NSMutableData *msgchunk = [[NSMutableData alloc] init];
    
    // 1 Version
    int version = htonl([delegate getVersionNumberByInt]);
    [msgchunk appendBytes: &version length: 4];
    
    // 2 local time
    NSString *dateString = [NSString GetLocalTimeString: DATABASE_TIMESTR];
    NSString *GTMdateString = [NSString GetGMTString: DATABASE_TIMESTR];
    
    // 3 localdate length, localdate
    int len = htonl([dateString length]);
    [msgchunk appendBytes: &len length: 4];
    [msgchunk appendData:[dateString dataUsingEncoding:NSASCIIStringEncoding]];
    
    // 4 File size, unencrypted size
    if(FileName) {
        len = htonl([rawFile length]);
    } else {
        len = htonl(0);
    }
    [msgchunk appendBytes: &len length: 4];
    
    // file name and size
    if(FileName) {
        len = htonl([FileName lengthOfBytesUsingEncoding:NSASCIIStringEncoding]);
        [msgchunk appendBytes: &len length: 4];
        [msgchunk appendData:[FileName dataUsingEncoding:NSASCIIStringEncoding]];
    } else {
        len = htonl(0);
        [msgchunk appendBytes: &len length: 4];
    }
    
    // file type size
    if(FileName) {
        len = htonl([MimeType lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
        [msgchunk appendBytes: &len length: 4];
        [msgchunk appendData:[MimeType dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
        len = htonl(0);
        [msgchunk appendBytes: &len length: 4];
    }
    
    // 9 Text length
    if([Message length] > 0) {
        len = htonl(Message.length);
        [msgchunk appendBytes: &len length: 4];
        [msgchunk appendData:Message];
    } else {
        len = htonl(0);
        [msgchunk appendBytes: &len length: 4];
    }
    
    // 11 Person length, 12 Person
    len = htonl([username lengthOfBytesUsingEncoding: NSUTF8StringEncoding]);
    [msgchunk appendBytes: &len length: 4];
    [msgchunk appendData:[username dataUsingEncoding: NSUTF8StringEncoding]];
    
    // 13 GMT date len, 14 GMT date
    len = htonl([GTMdateString length]);
    [msgchunk appendBytes: &len length: 4];
    [msgchunk appendData:[GTMdateString dataUsingEncoding:NSASCIIStringEncoding]];
    
    // 14 hash of file
    if(FileName) {
        // hash attachment
        NSData* filehash = [sha3 Keccak256Digest:encryptFile];
        len = htonl([filehash length]);
        [msgchunk appendBytes: &len length: 4];
        [msgchunk appendData:filehash];
    } else {
        // no hash
        len = htonl(0);
        [msgchunk appendBytes: &len length: 4];
    }
    
    // Encrypt/Sign/Encrypt
    encryptMsg = [SSEngine PackMessage:msgchunk PubKey:[delegate.DbInstance GetRawKey: keyid] Prikey:SignKey];
    
    [cipher setLength:0];
    //E1: Version (4bytes)
    version = htonl([delegate getVersionNumberByInt]);
    [cipher appendBytes: &version length: 4];
    //E2: ID_length (4bytes)
    packnonce = [sha3 Keccak256Digest:encryptMsg];
    len = htonl([packnonce length]);
    [cipher appendBytes: &len length: 4];
    //E3: ID
    [cipher appendData: packnonce];
    //E4: Token_length, UAirship token string
    len = htonl([token length]);
    [cipher appendBytes: &len length: 4];
    //E5: Token, push token
    [cipher appendBytes: [token cStringUsingEncoding: NSASCIIStringEncoding] length: [token length]];
    //E6: Message len
    len = htonl([encryptMsg length]);
    [cipher appendBytes: &len length: 4];
    //E7: Message
    [cipher appendData:encryptMsg];
    
    //E8: File data
    if(FileName) {
        len = htonl([encryptFile length]);
        [cipher appendBytes: &len length: 4];
        [cipher appendData:encryptFile];
    } else {
        len = htonl(0);
        [cipher appendBytes: &len length: 4];
    }
    
    // E9: Device type
    len = htonl(devtype);
    [cipher appendBytes: &len length: 4];
    
    return packnonce;
}


@end

