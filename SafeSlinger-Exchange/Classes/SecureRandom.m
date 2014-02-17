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

#import "sha3.h"
#import "SecureRandom.h"
#import <CommonCrypto/CommonDigest.h>

@implementation SecureRandom

@synthesize state, remainder, digestState, remCount;

-(id) initWithSeed: (NSData *)seed
{
	if ((self = [super init]))
	{
		self.remainder = [NSMutableData dataWithCapacity: DIGESTSIZE];
		self.digestState = [NSMutableData dataWithCapacity: DIGESTSIZE];
		self.remCount = 0;
		[digestState appendData: seed];
		
        // change to sha3
		self.state = [NSMutableData dataWithData:[sha3 Keccak256Digest: seed]];
	}
	return self;
}

-(void)dealloc
{
    [state release];
    [remainder release];
    [digestState release];
    [super dealloc];
}


-(void) nextBytes: (NSMutableData *)result
{
	int index = 0;
	int todo;
	unsigned char output[DIGESTSIZE];
	[remainder getBytes: output];
	char *resultBytes = [result mutableBytes];
	
	int r = remCount;
	if (r > 0)
	{
		todo = ([result length] ) < (DIGESTSIZE - r) ? [result length] : DIGESTSIZE - r;
		for (int i = 0; i < todo; i++)
		{
			resultBytes[i] = output[r];
			output[r++] = 0;
		}
		remCount += todo;
		index += todo;
	}
	
	while (index < [result length])
	{
		[digestState appendData: state];
		const char *stateBytes = [state bytes];
		CC_SHA1(stateBytes, [state length], output);
		[self updateState: state output: output];
		
		todo = ([result length] - index) > DIGESTSIZE ? DIGESTSIZE : [result length] - index;
		for (int i = 0; i < todo; i++)
		{
			resultBytes[index++] = output[i];
			output[i] = 0;
		}
		remCount += todo;
	}
	
	self.remainder = [NSMutableData dataWithBytes: output length: DIGESTSIZE];
	remCount %= DIGESTSIZE;
	[result setData: [NSData dataWithBytes: resultBytes length: [result length]]];
}

-(void) updateState: (NSMutableData *)aState output: (unsigned char *)output
{
	int last = 1;
	int v = 0;
	char t = 0;
	BOOL zf = NO;
	char *stateBytes = [aState mutableBytes];
	
	for (int i = 0; i < [aState length]; i++)
	{
		//DEBUGMSG(@"stateBytes[%d] = %d, output[%d] = %d", i, (int)stateBytes[i], i, (int)output[i]);
		v = (int)stateBytes[i] + (int)output[i] + last;
		t = (char)v;
		zf = zf | (stateBytes[i] != t);
		stateBytes[i] = t;
		last = v >> 8;
		//DEBUGMSG(@"    [%d] = %d", i, (int)stateBytes[i]);
	}
	if (!zf)
		stateBytes[0]++;
}

-(int) nextInt
{
	NSMutableData *result = [[NSMutableData alloc] initWithLength: 4];
	[self nextBytes: result];
	char *bytes = [result mutableBytes];
	int n = 0;
	
	for (int i = 0; i < 4; i++)
		n = (n << 8) + (bytes[i] & 0xff);
	
	[result release];
	return n;
}

-(int) nextIntUnder: (int)n
{
	int bits, val;
	do {
		bits = [self nextInt];
		bits = (bits >> 1) & 0x7fffffff;
		val = bits % n;
	} while (bits - val + (n-1) < 0);
	return val;
}

@end
