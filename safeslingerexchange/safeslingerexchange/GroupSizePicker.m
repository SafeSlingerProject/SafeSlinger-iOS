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

#import "GroupSizePicker.h"
#import "safeslingerexchange.h"
#import "Config.h"
#import "iToast.h"

@implementation GroupSizePicker

@synthesize GroupPicker, HintLabel, SubmitBtn, delegate;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}


- (void)viewWillAppear:(BOOL)animated
{
    [HintLabel setText: NSLocalizedStringFromBundle(delegate.res, @"title_size", @"How many users in the exchange?")];
}


- (void)viewDidAppear:(BOOL)animated
{
    
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(IBAction) SubmitGroupSize
{
    if([GroupPicker selectedRowInComponent: 0]==0)
    {
        [[[[iToast makeText: [NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"error_MinUsersRequired", @"A minimum of %d members is required to exchange data."), MIN_USERS]]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        return;
    }
    
    // start grouping
    [delegate BeginGrouping: (int)([GroupPicker selectedRowInComponent: 0] + 1)];
    // adjust picker default value
    [GroupPicker selectRow:0 inComponent:0 animated:NO];
}


#pragma mark UIPickerViewDelegate
-(NSString *) pickerView: (UIPickerView *)pickerView titleForRow: (NSInteger)row forComponent: (NSInteger)component
{
    if(row==0)
        return [NSString stringWithFormat:@""];
    else
        return [NSString stringWithFormat:@"%ld", row+1];
}

#pragma mark UIPickerViewDataSource
-(NSInteger) numberOfComponentsInPickerView: (UIPickerView *)pickerView
{
	return 1;
}
-(NSInteger) pickerView: (UIPickerView *)pickerView numberOfRowsInComponent: (NSInteger)component
{
	return MAX_USERS;
}

@end
