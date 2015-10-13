//
//  MessageSender.h
//  safeslingermessager
//
//  Created by Bruno Nunes on 1/23/15.
//  Copyright (c) 2015 CyLab. All rights reserved.
//

@import Foundation;
#import "AppDelegate.h"
#import "SSEngine.h"

@protocol MessageSenderDelegate

- (void)updatedOutgoingStatusForMessage:(MsgEntry *)message;

@end

@interface MessageSender : NSObject

@property (strong, atomic) MsgEntry *outgoingMessage;
@property (weak, nonatomic) id<MessageSenderDelegate> delegate;

- (void)sendMessage:(MsgEntry *)message packetData:(NSData *)packetData;

@end
