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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class GroupSizePicker;         // select group size
@class GroupingViewController;  // Lowest ID comparison
@class WordListViewController;  // Word comparison
@class ActivityWindow;          // Acitivity window
@class SafeSlingerExchange;     // Safeslinger protocol
@class Reachability;            // Network Reachability

enum ReturnStatus
{
    RESULT_EXCHANGE_OK = 0,
    RESULT_EXCHANGE_CANCELED
};

@protocol SafeSlingerDelegate
@required
- (void)EndExchange:(int)status_code ErrorString:(NSString*)error_str ExchangeSet: (NSArray*)exchange_set;
@end

@interface safeslingerexchange : NSObject
{
    GroupSizePicker *sizePicker;
    GroupingViewController *groupView;
    WordListViewController *compareView;
    ActivityWindow *actWindow;
    
    // protocol object
    SafeSlingerExchange *protocol;
    NSTimer *pro_expire;
    
    // data for excahnge
    NSData *exchangeInput;
    // bundle object to access all UIs and localized Strings
    NSBundle *res;
    // Navigation Controller Delegate
    UIViewController<SafeSlingerDelegate> *mController;
}

@property (nonatomic, retain) UIViewController<SafeSlingerDelegate> *mController;
@property (nonatomic, retain) GroupSizePicker *sizePicker;
@property (nonatomic, retain) GroupingViewController *groupView;
@property (nonatomic, retain) WordListViewController *compareView;
@property (nonatomic, retain) ActivityWindow *actWindow;
@property (nonatomic, retain) SafeSlingerExchange *protocol;
@property (nonatomic, retain) NSBundle *res;
@property (nonatomic, retain) NSData *exchangeInput;
@property (nonatomic, retain) NSTimer *pro_expire;
@property (nonatomic) Reachability *internetReachability;

// Public interfaces
-(BOOL)SetupExchange: (UIViewController<SafeSlingerDelegate>*)mainController ServerHost: (NSString*) host VersionNumber:(NSString*)vNum;
-(void)BeginExchange: (NSData*)input;
-(void)RequestUniqueID: (int)NumOfUsers;
-(void)BeginGrouping: (NSString*)UserID;
-(void)BeginVerifying;
-(void)DisplayMessage: (NSString*)showMessage;

@end

