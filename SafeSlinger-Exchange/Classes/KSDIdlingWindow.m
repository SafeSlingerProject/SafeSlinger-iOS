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

#import "KSDIdlingWindow.h"
#import "KeySlingerAppDelegate.h"

NSString * const KSDIdlingWindowIdleNotification   = @"KSDIdlingWindowIdleNotification";
NSString * const KSDIdlingWindowActiveNotification = @"KSDIdlingWindowActiveNotification";

@interface KSDIdlingWindow (PrivateMethods)
- (void)windowIdleNotification;
- (void)windowActiveNotification;
@end


@implementation KSDIdlingWindow
@synthesize idleTimeInterval, idleTimer;

- (id) init {
	if (self = [super init]) {
		self.idleTimeInterval = 0.0f;
	}
	return self;
}

#pragma mark activity timer
- (void)sendEvent: (UIEvent *)event {
    [super sendEvent:event];
    NSSet *allTouches = [event allTouches];
    if ([allTouches count] > 0) {
		// To reduce timer resets only reset the timer on a Began or Ended touch.
        UITouchPhase phase = ((UITouch *)[allTouches anyObject]).phase;
		if (phase == UITouchPhaseBegan || phase == UITouchPhaseEnded)
        {
            KeySlingerAppDelegate *delegate = [[UIApplication sharedApplication]delegate];
			if (idleTimeInterval > 0 && delegate.hasAccess) {
                [self DisableTimer];
                _count = 0;
                idleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                             target:self
                                                           selector:@selector(checkLogout)
                                                           userInfo:nil
                                                            repeats:YES];
                [idleTimer fire];
			}
		}
	}
}

- (void)DisableTimer
{
    if ( [idleTimer isValid] ) {
        [idleTimer invalidate];
        idleTimer = nil;
    }
}

- (void)ResetTimer: (NSTimeInterval)newT
{
    [self DisableTimer];
    idleTimeInterval = newT;
    if (idleTimeInterval > 0 ) {
        _count = 0;
        idleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                     target:self
                                                   selector:@selector(checkLogout)
                                                   userInfo:nil
                                                    repeats:YES];
        [idleTimer fire];
    }
}

- (void)checkLogout
{
    _count++;
    if(_count>idleTimeInterval)
    {
        [self DisableTimer];
        KeySlingerAppDelegate *delegate = [[UIApplication sharedApplication]delegate];
        if(delegate.myID!=-1)[delegate Logout];
    }
}

- (void)dealloc {
	if (idleTimer)[idleTimer release];
    [super dealloc];
}


@end
