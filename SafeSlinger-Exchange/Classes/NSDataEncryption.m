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

#import "NSDataEncryption.h"
#import "sha3.h"
#import "SafeSlinger.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import "ErrorLogger.h"

@implementation NSData (AES256)

- (NSData *)AES256EncryptWithKey:(NSData *)key 
                      matchNonce:(NSData *)matchNonce {
    
    NSData *cipher = nil;
    NSUInteger len = [key length];
    Byte *keyPtr = (Byte*)malloc(len);
    memcpy(keyPtr, [key bytes], len);
    
    NSUInteger dataLength = [self length];
    
    NSString *k = @"2";
    
    //for HMAC-SHA3
    NSData *keyHMAC = [k dataUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char iv[16];
    NSData *ivData = [sha3 Keccak256HMAC:matchNonce withKey:keyHMAC];
    [ivData getBytes:iv length:16];
    	
	//For block ciphers, the output size will always be less than or 
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesEncrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256, /* change to 256 because of SHA3 */
										  iv  /* initialization vector */,
										  [self bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesEncrypted);
    DEBUGMSG(@"numBytesEncrypted = %zd", numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
		cipher = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    }else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat:@"ERROR: Encryption error. Reason status = %d", cryptStatus]];
    }
    free(keyPtr);
	free(buffer);
	return cipher;
}

- (NSData *)AES256DecryptWithKey:(NSData *)key 
                      matchNonce:(NSData *)matchNonce {	
    
    NSUInteger len = [key length];
    Byte *keyPtr = (Byte*)malloc(len);
    memcpy(keyPtr, [key bytes], len);
    
    NSUInteger dataLength = [self length];
    
    NSString *k = @"2";
    //for HMAC-SHA3
    NSData *keyHMAC = [k dataUsingEncoding:NSUTF8StringEncoding];
    
    // replaced by SHA3
    unsigned char iv[16];
    NSData *ivData = [sha3 Keccak256HMAC:matchNonce withKey:keyHMAC];
    [ivData getBytes:iv length:16];

	//See the doc: For block ciphers, the output size will always be less than or 
	//equal to the input size plus the size of one block.
	//That's why we need to add the size of one block here
	size_t bufferSize = dataLength + kCCBlockSizeAES128;
	void *buffer = malloc(bufferSize);
	
	size_t numBytesDecrypted = 0;
	CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
										  keyPtr, kCCKeySizeAES256, /* change to 256 because of SHA3 */
										  [ivData bytes] /* initialization vector */,
										  [self bytes], dataLength, /* input */
										  buffer, bufferSize, /* output */
										  &numBytesDecrypted);
    free(keyPtr);
	if (cryptStatus == kCCSuccess) {
		NSData *toReturn = [NSData dataWithBytes:buffer length:numBytesDecrypted];
    	free(buffer); //free the buffer;
        return toReturn;
	}else{
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Decryption error. Reason status = %d", cryptStatus]];
    }
    free(buffer);
	return nil;
}


@end