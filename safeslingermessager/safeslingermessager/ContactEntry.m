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

#import "ContactEntry.h"
#import "Utility.h"
#import "SafeSlingerDB.h"
#import "ErrorLogger.h"

@implementation ContactEntry

- (NSString *)printContact {
	// plaintext
	NSMutableString* detail = [NSMutableString stringWithCapacity:0];
	
	[detail appendFormat:@"Name:%@\n", [NSString compositeName:_firstName withLastName:_lastName]];
	[detail appendFormat:@"KeyID:%@\n", _keyId];
	[detail appendFormat:@"KeyGenDate:%@\n", _keygenDate];
	[detail appendFormat:@"PushToken:%@\n", _pushToken];
	
	switch (_exchangeType) {
		case Exchanged:
			[detail appendFormat:@"Type: %@\n", NSLocalizedString(@"label_exchanged", @"exchanged")];
			break;
		case Introduced:
			[detail appendFormat:@"Type: %@\n", NSLocalizedString(@"label_introduced", @"introduced")];
			break;
	}
	
	[detail appendFormat:@"Exchange(Introduce) Date:%@\n", _exchangeDate];
	
	switch (_devType) {
		case Android:
			[detail appendString:@"DEV: Android\n"];
			break;
		case iOS:
			[detail appendString:@"DEV: iOS\n"];
			break;
		default:
			[detail appendFormat:@"DEV: %d", _devType];
			break;
	}
	
	return detail;
}

- (BOOL)setKeyInfo:(NSData *)key {
	NSString* rawdata = [NSString stringWithCString:[key bytes] encoding:NSASCIIStringEncoding];
	rawdata = [rawdata substringToIndex:[key length]];
	
	NSArray* keyarray = [rawdata componentsSeparatedByString:@"\n"];
	if([keyarray count]!=3) {
		[ErrorLogger ERRORDEBUG: (@"ERROR: Exchange public key is not well-formated!")];
		return NO;
	}
	
	_keyId = keyarray[0];
	_keygenDate = keyarray[1];
	_keyString = keyarray[2];
	
	return YES;
}

@end
