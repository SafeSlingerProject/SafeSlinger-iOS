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

#import <UIKit/UIKit.h>
#import "Config.h"

@class KeySlingerAppDelegate;
@class SSContactSelector;
@class SSContactEntry;

typedef enum UserTags{
    User1Tag = 1,
    User2Tag
}UserTags;

@interface SecureIntroduce : UIViewController
{
    UIButton *User1Btn, *User2Btn, *IntroduceBtn;
    UIImageView *User1Photo, *User2Photo;
    UILabel *HintLabel;
    
    KeySlingerAppDelegate *delegate;
    // Contact Selector
    SSContactSelector *USelector;
    // Messages for introdcution
    NSString *messageForU1, *messageForU2;
}

@property (nonatomic, retain) IBOutlet UIImageView *User1Photo;
@property (nonatomic, retain) IBOutlet UIImageView *User2Photo;
@property (nonatomic, retain) IBOutlet UILabel *HintLabel;
@property (nonatomic, retain) IBOutlet UIButton *IntroduceBtn;
@property (nonatomic, retain) IBOutlet UIButton *User1Btn;
@property (nonatomic, retain) IBOutlet UIButton *User2Btn;

@property (nonatomic, retain) KeySlingerAppDelegate *delegate;
@property (nonatomic, retain) SSContactSelector *USelector;

@property (nonatomic, strong) SSContactEntry *pickU1, *pickU2;
@property (nonatomic, retain) NSData *nonce1, *nonce2;
@property (nonatomic, retain) NSString *messageForU1, *messageForU2;

@property (nonatomic, readwrite) int UserTag;
//@property (nonatomic, readwrite) BOOL U1Picked, U2Picked;
@property (atomic, readwrite) BOOL U1Sent, U2Sent;

-(IBAction) pickUser:(id)sender;

-(void)setRecipient: (SSContactEntry*)GivenUser;


@end

