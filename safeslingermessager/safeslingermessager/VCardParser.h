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

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@class ContactEntry;

@interface VCardParser : NSObject

+(NSData*) GetSimpleVCard: (ContactEntry*)contact RawPubkey: (NSString*)Pubkey;

// Parse contact object record into a NSString output accoring to profile stored in the database.
+(NSString*) vCardWithNameOnly: (NSString*)FN LastName:(NSString*)LN;

// Parse contact object record into a NSString output accoring to contact labels, field values, categoories, and user selection.
+(NSString *) vCardFromContact: (ABRecordRef)record labels: (NSArray *)labels values: (NSArray *)values selections: (NSArray *)selections category: (NSArray *)category;

// Translate NSString object vCard to a personal contact object ABRecordRef
+(ABRecordRef) vCardToContact: (NSString *)vCard;

@end
