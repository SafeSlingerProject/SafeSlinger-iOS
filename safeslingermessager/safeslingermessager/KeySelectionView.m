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

#import "KeySelectionView.h"
#import "SSEngine.h"
#import "Utility.h"
#import "AppDelegate.h"
#import "Passphase.h"

@interface KeySelectionView ()

@end

@implementation KeySelectionView

@synthesize keyitem, keylist, parent;

- (void)viewDidLoad
{
    [super viewDidLoad];
    keyitem = [[NSMutableArray alloc]init];
    keylist = [[NSMutableArray alloc]init];
}

- (void)viewWillAppear:(BOOL)animated
{
    // load all files in Share folder
    [keylist removeAllObjects];
    [keylist setArray: [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_KEY]];
    [keyitem removeAllObjects];
    [keyitem setArray: [[NSUserDefaults standardUserDefaults] stringArrayForKey: kDB_LIST]];
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
    return [keyitem count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"KeyOptionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey: kDEFAULT_DB_KEY];
    
	if(indexPath.row == index) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
	} else {
        cell.accessoryType = UITableViewCellAccessoryNone;
	}
	
    NSArray *keyinfo = [[keyitem objectAtIndex:indexPath.row] componentsSeparatedByString:@"\n"];
    cell.textLabel.text = [keyinfo objectAtIndex:0];
    cell.detailTextLabel.text = [keyinfo objectAtIndex:1];
    
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    // load the database when user select
    if(indexPath.row!=[[NSUserDefaults standardUserDefaults] integerForKey:kDEFAULT_DB_KEY])
    {
        [[NSUserDefaults standardUserDefaults] setInteger:indexPath.row forKey:kDEFAULT_DB_KEY];
        [parent SelectDifferentKey];
    }
    [self.navigationController popViewControllerAnimated: YES];
}


@end
