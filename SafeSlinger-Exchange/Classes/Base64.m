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

#import "Base64.h"
#include <openssl/bio.h>
#include <openssl/evp.h>

#define ArrayLength(x) (sizeof(x)/sizeof(*(x)))

@implementation Base64

static char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static char decodingTable[128];

+(void) initialize {
	if (self == [Base64 class]) {
		memset(decodingTable, 0, ArrayLength(decodingTable));
		for (NSInteger i = 0; i < ArrayLength(encodingTable); i++) {
			decodingTable[encodingTable[i]] = i;
		}
	}
}

+(NSString *) encode: (NSData *)inputData
{
	const uint8_t *input = [inputData bytes];
	NSMutableData *outputData = [NSMutableData dataWithLength: ([inputData length] + 2) / 3 * 4];
	uint8_t *output = (uint8_t *)[outputData mutableBytes];
	
	for (int i = 0; i < [inputData length]; i += 3)
	{
		int value = 0;
		for (int j = i; j < i + 3; j++)
		{
			value <<= 8;
			if (j < [inputData length])
				value |= 0xff & input[j];
		}
		int index = (i / 3) * 4;
		output[index] = encodingTable[(value >> 18) & 0x3f];
		output[index + 1] = encodingTable[(value >> 12) & 0x3f];
		output[index + 2] = (i + 1) < [inputData length] ? encodingTable[(value >> 6) & 0x3f] : '=';
		output[index + 3] = (i + 2) < [inputData length] ? encodingTable[value & 0x3f] : '=';
	}
	return [[[NSString alloc] initWithData: outputData encoding: NSASCIIStringEncoding]autorelease];
}

+(NSData *) decode: (NSString *)string
{
	return [self decode: [string cStringUsingEncoding: NSASCIIStringEncoding] length: [string length]];
}


+(NSData *)decode: (const char*)string length: (NSInteger)inputLength
{
	if ((string == NULL) || (inputLength % 4 != 0)) {
		return nil;
	}
	
	while (inputLength > 0 && string[inputLength - 1] == '=') {
		inputLength--;
	}
	
	NSInteger outputLength = inputLength * 3 / 4;
    uint8_t output[outputLength];
	
	NSInteger inputPoint = 0;
	NSInteger outputPoint = 0;
	while (inputPoint < inputLength) {
		char i0 = string[inputPoint++];
		char i1 = string[inputPoint++];
		char i2 = inputPoint < inputLength ? string[inputPoint++] : 'A'; 
		char i3 = inputPoint < inputLength ? string[inputPoint++] : 'A';
		
		output[outputPoint++] = (decodingTable[i0] << 2) | (decodingTable[i1] >> 4);
		if (outputPoint < outputLength) {
			output[outputPoint++] = ((decodingTable[i1] & 0xf) << 4) | (decodingTable[i2] >> 2);
		}
		if (outputPoint < outputLength) {
			output[outputPoint++] = ((decodingTable[i2] & 0x3) << 6) | decodingTable[i3];
		}
	}
    
    return [[NSData alloc]initWithBytes:output length:outputLength];
}

@end
