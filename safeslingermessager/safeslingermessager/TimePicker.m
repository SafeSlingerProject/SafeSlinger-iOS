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

#import "TimePicker.h"
#import "IdleHandler.h"

@interface TimePicker ()

@end

@implementation TimePicker

@synthesize cachetimes, sortkeys;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // All cache time entries
    self.cachetimes = [NSDictionary dictionaryWithObjectsAndKeys:
                       NSLocalizedString(@"choice_1min", @"1 min"), [NSNumber numberWithInt:60],
                       NSLocalizedString(@"choice_3mins", @"3 mins"), [NSNumber numberWithInt:180],
                       NSLocalizedString(@"choice_5mins", @"5 mins"), [NSNumber numberWithInt:300],
                       NSLocalizedString(@"choice_10mins", @"10 mins"), [NSNumber numberWithInt:600],
                       NSLocalizedString(@"choice_20mins", @"20 mins"), [NSNumber numberWithInt:1200],
                       NSLocalizedString(@"choice_40mins", @"40 mins"), [NSNumber numberWithInt:2400],
                       NSLocalizedString(@"choice_1hour", @"1 hour"), [NSNumber numberWithInt:3600],
                       NSLocalizedString(@"choice_2hours", @"2 hours"), [NSNumber numberWithInt:7200],
                       NSLocalizedString(@"choice_4hours", @"4 hours"), [NSNumber numberWithInt:14400],
                       NSLocalizedString(@"choice_8hours", @"8 hours"), [NSNumber numberWithInt:28800],
                       NSLocalizedString(@"choice_nolimit", @"No Limit"), [NSNumber numberWithInt:-1],
                       nil];
    // Sort them
    self.sortkeys = [[cachetimes allKeys]sortedArrayUsingComparator:
                     ^NSComparisonResult(id obj1, id obj2)
                     {
                         if ([obj1 integerValue] > [obj2 integerValue]) {
                             return (NSComparisonResult)NSOrderedDescending;
                         }
                         if ([obj1 integerValue] < [obj2 integerValue]) {
                             return (NSComparisonResult)NSOrderedAscending;
                         }
                         return (NSComparisonResult)NSOrderedSame;
                     }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [sortkeys count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TimeUnitCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    // Configure the cell...
    cell.textLabel.text = [cachetimes objectForKey:[sortkeys objectAtIndex:indexPath.row]];
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DEBUGMSG(@"didSelectRowAtIndexPath");
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    // Navigation logic may go here. Create and push another view controller.
    NSInteger period = [[sortkeys objectAtIndex:indexPath.row]integerValue];
    [[NSUserDefaults standardUserDefaults]setInteger:period forKey:kPasshpraseCacheTime];
    IdleHandler *handler = (IdleHandler*)[UIApplication sharedApplication];
    [handler resetIdleTimer];
    [self performSegueWithIdentifier:@"FinishTimePick" sender:self];
}

@end
