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
@synthesize first_use;

-(BOOL)SetupExchange: (UIViewController<SafeSlingerDelegate>*)mainController ServerHost: (NSString*) host VersionNumber:(NSString*)vNum FirstUse:(BOOL)isFirstuse
{
    if(![mainController isKindOfClass:[UIViewController class]])
        return NO;
    else{
        mController = mainController;
        // set to default if null string
        if(![host hasPrefix:@"http"])
            host = [NSString stringWithFormat:@"https://%@", host];
        
        int version = 0;
        if(vNum)
        {
            // parse version number
            NSArray *versionArray = [vNum componentsSeparatedByString:@"."];
            for(int i=0;i<[versionArray count];i++)
            {
                NSString* tmp = [versionArray objectAtIndex:i];
                version = version | ([tmp intValue] << (8*(3-i)));
            }
        }else{
            // default version
            version = MINICVERSION;
        }
        
        protocol = [[SafeSlingerExchange alloc]init:host version:version];
        protocol.delegate = self;
        self.first_use = isFirstuse;
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

-(void)BeginExchange: (NSData*)input
{
    if([input length]==0)
    {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromBundle(res, @"lib_name", @"SafeSlinger Exchange")
                                                                       message:NSLocalizedStringFromBundle(res, @"error_NoDataToExchange", @"The exchange is missing required data.")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(res, @"btn_OK", @"OK")
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action){}];
        
        [alert addAction:okAction];
        [mController presentViewController:alert animated:YES completion:nil];
    }else{
        exchangeInput = input;
        // push view
        [mController.navigationController pushViewController:sizePicker animated:YES];
    }
}

-(void)RequestUniqueID: (int)NumOfUsers
{
    // start overall counter
    pro_expire = [NSTimer scheduledTimerWithTimeInterval: PROTOCOLTIMEOUT
                                                  target: self
                                                selector:@selector(ProtocolExpired:)
                                                userInfo: nil repeats:NO];
    
    // start sending data to server when only user finish select group size
    [protocol startProtocol: exchangeInput];
    protocol.users = NumOfUsers;
}

-(void)BeginGrouping: (NSString*)UserID
{
    // push view
    groupView.UniqueID = UserID;
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
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromBundle(res, @"lib_name", @"SafeSlinger Exchange")
                                                                   message:NSLocalizedStringFromBundle(res, @"error_ExchangeProtocolTimeoutExceeded", @"Exchange timeout exceeded. Begin the exchange again.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(res, @"btn_OK", @"OK")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action){}];
    
    [alert addAction:okAction];
    [mController presentViewController:alert animated:YES completion:nil];
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
            NSLog(@"ERROR: %@", showMessage);
            [mController EndExchange:RESULT_EXCHANGE_CANCELED ErrorString:showMessage ExchangeSet:nil];
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromBundle(res, @"lib_name", @"SafeSlinger Exchange")
                                                                           message:showMessage
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* okAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(res, @"btn_OK", @"OK")
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action){}];
            
            [alert addAction:okAction];
            [mController presentViewController:alert animated:YES completion:nil];
        }
            break;
        case ProtocolCancel:
            [mController EndExchange:RESULT_EXCHANGE_CANCELED ErrorString:showMessage ExchangeSet:nil];
            [[[[iToast makeText: showMessage] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            break;
        default:
            break;
    }
}

@end
