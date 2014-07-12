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

#import "safeslingerexchange.h"
// UI implementation
#import "GroupSizePicker.h"
#import "GroupingViewController.h"
#import "WordListViewController.h"
#import "ActivityWindow.h"
// protocol
#import "SafeSlinger.h"
#import "iToast.h"
// reachability
#import "Reachability.h"

@implementation safeslingerexchange

@synthesize sizePicker, groupView, compareView, actWindow;
@synthesize mController, protocol, res;
@synthesize exchangeInput, pro_expire;

-(BOOL)SetupExchange: (UIViewController<SafeSlingerDelegate>*)mainController ServerHost: (NSString*) host VersionNumber:(NSString*)vNum
{
    if(![mainController isKindOfClass:[UIViewController class]])
        return NO;
    else{
        mController = mainController;
        // set to default if null string
        if([host length]==0) host = DEFAULT_SERVER;
        // parse version number
        NSArray *versionArray = [vNum componentsSeparatedByString:@"."];
        int version = 0;
        for(int i=0;i<[versionArray count];i++)
        {
            NSString* tmp = [versionArray objectAtIndex:i];
            version = version | ([tmp intValue] << (8*(3-i)));
        }
        
        protocol = [[SafeSlingerExchange alloc]init:host version:version];
        protocol.delegate = self;
        res = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"exchangeui" withExtension:@"bundle"]];
        
        // UI resource allocation
        actWindow = [[ActivityWindow alloc] initWithNibName: @"ActivityWindow" bundle:res];
        sizePicker = [[GroupSizePicker alloc]initWithNibName:@"GroupSizePicker" bundle:res];
        [sizePicker setDelegate: self];
        groupView = [[GroupingViewController alloc] initWithNibName: @"GroupingViewController" bundle:res];
        [groupView setDelegate: self];
        compareView = [[WordListViewController alloc] initWithNibName: @"WordListViewController" bundle: res];
        [compareView setDelegate:self];
        
        // Add network reachability test
        self.internetReachability = [Reachability reachabilityForInternetConnection];
        [self.internetReachability startNotifier];
        [self updateInterfaceWithReachability:self.internetReachability];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
        
        return YES;
    }
}

- (void) reachabilityChanged:(NSNotification *)note
{
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isMemberOfClass:[Reachability class]]);
    [self updateInterfaceWithReachability:curReach];
}

- (void)updateInterfaceWithReachability:(Reachability *)reachability
{
    if (reachability == self.internetReachability)
    {
        NetworkStatus netStatus = [reachability currentReachabilityStatus];
        BOOL connectionRequired = [reachability connectionRequired];
        
        switch (netStatus)
        {
            case NotReachable:
            {
                [[[[iToast makeText: NSLocalizedStringFromBundle(res, @"error_CorrectYourInternetConnection", @"Internet not available, check your settings.")] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
                connectionRequired = NO;
                break;
            }
            case ReachableViaWWAN:
            case ReachableViaWiFi:
            {
                break;
            }
        }
    }
    
}


- (void)configureTextField:(UITextField *)textField imageView:(UIImageView *)imageView reachability:(Reachability *)reachability
{
    
}

-(void)BeginExchange: (NSData*)input
{
    if([input length]==0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromBundle(res, @"lib_name", @"SafeSlinger Exchange")
                                                        message: NSLocalizedStringFromBundle(res, @"error_NoDataToExchange", @"The exchange is missing required data.")
                                                       delegate: self
                                              cancelButtonTitle: NSLocalizedStringFromBundle(res, @"btn_No", @"No")
                                              otherButtonTitles: nil];
        [alert show];
        alert = nil;
        return;
    }
    
    exchangeInput = input;
    // push view
    [mController.navigationController pushViewController:sizePicker animated:YES];
}

-(void)BeginGrouping: (int)NumOfUsers
{
    // start overall counter
    pro_expire = [NSTimer scheduledTimerWithTimeInterval: PROTOCOLTIMEOUT
                                                  target: self
                                                selector:@selector(ProtocolExpired:)
                                                userInfo: nil repeats:NO];
    
    // start sending data to server when only user finish select group size
    [protocol startProtocol: exchangeInput];
    protocol.users = NumOfUsers;
    
    // push view
    [mController.navigationController pushViewController:groupView animated:YES];
}

-(void)BeginVerifying
{
    // push view
    [mController.navigationController pushViewController:compareView animated:YES];
}

-(void)ProtocolExpired: (id)sender
{
    // cancel all possible indicator
    [actWindow.view removeFromSuperview];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromBundle(res, @"lib_name", @"SafeSlinger Exchange")
                                                    message: NSLocalizedStringFromBundle(res, @"error_ExchangeProtocolTimeoutExceeded", @"Exchange timeout exceeded. Begin the exchange again.")
                                                   delegate: nil
                                          cancelButtonTitle: NSLocalizedStringFromBundle(res, @"btn_OK", @"OK")
                                          otherButtonTitles: nil];
    [alert show];
    alert = nil;
    [mController EndExchange:RESULT_EXCHANGE_CANCELED ErrorString: NSLocalizedStringFromBundle(res, @"error_ExchangeProtocolTimeoutExceeded", @"Exchange timeout exceeded. Begin the exchange again.") ExchangeSet:nil];
}

-(void)DisplayMessage: (NSString*)showMessage
{
    // disable the timer
    [pro_expire invalidate];
    
    // cancel all possible indicator
    [actWindow.view removeFromSuperview];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // notify the app
    switch (protocol.state) {
        case ProtocolFail:
        case ProtocolTimeout:
        case NetworkFailure:
        {
            DEBUGMSG(@"ERROR: %@", showMessage);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedStringFromBundle(res, @"lib_name", @"SafeSlinger Exchange")
                                                            message: showMessage
                                                           delegate: nil
                                                  cancelButtonTitle: NSLocalizedStringFromBundle(res, @"btn_OK", @"OK")
                                                  otherButtonTitles: nil];
            [alert show];
            alert = nil;
            [mController EndExchange:RESULT_EXCHANGE_CANCELED ErrorString:showMessage ExchangeSet:nil];
        }
            break;
        case ProtocolCancel:
            [[[[iToast makeText: showMessage] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [mController EndExchange:RESULT_EXCHANGE_CANCELED ErrorString:showMessage ExchangeSet:nil];
            break;
        default:
            break;
    }
}

@end
