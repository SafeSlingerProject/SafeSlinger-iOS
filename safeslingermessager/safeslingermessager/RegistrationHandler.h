//
//  RegistrationHandler.h
//  safeslingermessager
//
//  Created by Yueh-Hsun Lin on 1/25/15.
//  Copyright (c) 2015 CyLab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RegistrationHandler : NSObject

- (void)registerToken: (NSString*)hex_submissiontoken DeviceHex: (NSString*)hex_token KeyHex: (NSString*)hex_keyid ClientVer: (int)int_clientver;

@end
