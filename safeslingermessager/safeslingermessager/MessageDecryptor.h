//
//  MessageDecryptor.h
//  safeslingermessager
//
//  Created by Bruno Nunes on 5/21/15.
//  Copyright (c) 2015 CyLab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UniversalDB.h"

@interface MessageDecryptor : NSObject

+ (BOOL)DecryptCipherMessage:(MsgEntry *)msg;

@end
