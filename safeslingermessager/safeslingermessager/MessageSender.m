//
//  MessageSender.m
//  safeslingermessager
//
//  Created by Bruno Nunes on 1/23/15.
//  Copyright (c) 2015 CyLab. All rights reserved.
//

#import "MessageSender.h"
#import "ErrorLogger.h"
#import "Utility.h"

@interface MessageSender ()
@property (strong, nonatomic) NSURL *serverURL;
@property (weak, nonatomic) AppDelegate *appDelegate;
@end

@implementation MessageSender

- (instancetype)init {
	if(self = [super init]) {
		_serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@/%@", HTTPURL_PREFIX, HTTPURL_HOST_MSG, POSTMSG]];
		_appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	}
	return self;
}

- (void)sendMessage:(MsgEntry *)message packetData:(NSData *)packetData {
	if([message.msgbody length] == 0) {
		// empty message
		[[[[iToast makeText: NSLocalizedString(@"error_selectDataToSend", @"You need an attachment or a text message to send.")]
		   setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
		return;
	}
	
	_outgoingMessage = message;
	[self updatedStatus:MessageOutgoingStatusSending forMessage:message];
	
//	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
//		//Background Thread
//		dispatch_async(dispatch_get_main_queue(), ^(void){
//			//Run UI Updates
//			[InstanceBtn setEnabled:NO];
//			[InstanceMessage setEnabled:NO];
//			[actWindow DisplayMessage: NSLocalizedString(@"prog_encrypting", @"encrypting...") Detail:nil];
//			[self.navigationController.view addSubview: actWindow.view];
//		});
//	});
	
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_serverURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:MESSAGE_TIMEOUT];
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody:packetData];
	
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	[NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
		 if(error) {
			 [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"ERROR: Internet Connection failed. Error - %@ %@",
									   [error localizedDescription],
									   [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]]];
			 
			 message.rTime = nil;
			 [self updatedStatus:MessageOutgoingStatusFailed forMessage:message];
			 _outgoingMessage = nil;
			 
//			 if(error.code == NSURLErrorTimedOut) {
//				 dispatch_async(dispatch_get_main_queue(), ^(void) {
////					 [[[[iToast makeText: NSLocalizedString(@"error_ServerNotResponding", @"No response from server.")]
////						setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
//				 });
//			 } else {
//				 // general errors
//				 dispatch_async(dispatch_get_main_queue(), ^(void) {
////					 [[[[iToast makeText: [NSString stringWithFormat:NSLocalizedString(@"error_ServerAppMessageCStr", @"Server Message: '%@'"), [error localizedDescription]]]
////						setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
//				 });
//			 }
		 } else {
			 if([data length] > 0) {
				 // start parsing data
				 DEBUGMSG(@"Succeeded! Received %lu bytes of data",(unsigned long)[data length]);
				 const char *msgchar = [data bytes];
				 DEBUGMSG(@"Return SerV: %02X", ntohl(*(int *)msgchar));
				 if (ntohl(*(int *)msgchar) > 0) {
					 // Send Response
					 DEBUGMSG(@"Send Message Code: %d", ntohl(*(int *)(msgchar+4)));
					 DEBUGMSG(@"Send Message Response: %s", msgchar+8);
					 
					 message.rTime = [NSString GetGMTString:DATABASE_TIMESTR];
					 [self updatedStatus:MessageOutgoingStatusSent forMessage:message];
					 _outgoingMessage = nil;
									
//					 // reload the view
//					 dispatch_async(dispatch_get_main_queue(), ^(void) {
//						 [[[[iToast makeText: ret]
//							setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
////						 [self reloadTable];
////						 [InstanceBtn setEnabled:YES];
////						 [InstanceMessage setEnabled:YES];
////						 InstanceMessage.text = nil;
//					 });
				 } else if(ntohl(*(int *)msgchar) == 0) {
					 // Error Message
					 NSString* error_msg = [NSString TranlsateErrorMessage:[NSString stringWithUTF8String: msgchar+4]];
					 DEBUGMSG(@"ERROR: error_msg = %@", error_msg);
					 
					 message.rTime = nil;
					 [self updatedStatus:MessageOutgoingStatusFailed forMessage:message];
					 _outgoingMessage = nil;
					 
//					 dispatch_async(dispatch_get_main_queue(), ^(void) {
////						 [actWindow.view removeFromSuperview];
//						 [[[[iToast makeText: error_msg]
//							setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
////						 [InstanceBtn setEnabled:YES];
////						 [InstanceMessage setEnabled:YES];
////						 InstanceMessage.text = nil;
//					 });
				 }
			 }
		 }
	 }];
}

- (void)updatedStatus:(MessageOutgoingStatus)newStatus forMessage:(MsgEntry *)message {
	message.outgoingStatus = newStatus;
	
	if(_delegate) {
		dispatch_async(dispatch_get_main_queue(), ^(void){
			if(newStatus == MessageOutgoingStatusSent || newStatus == MessageOutgoingStatusFailed) {
				[_appDelegate.DbInstance InsertMessage:message];
			}
			
			[_delegate updatedOutgoingStatusForMessage:message];
		});
	}
}

@end
