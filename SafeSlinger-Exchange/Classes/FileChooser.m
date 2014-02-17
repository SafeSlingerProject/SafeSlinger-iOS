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

#import "FileChooser.h"
#import "KeySlingerAppDelegate.h"
#import "MessageComposer.h"

@implementation FileChooser

@synthesize filelist, delegate;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.delegate = [[UIApplication sharedApplication] delegate];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // init the array
    self.filelist = [NSMutableArray arrayWithCapacity:0];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [filelist release];
    filelist = nil;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    // load all files in Share folder
    [filelist removeAllObjects];
    int filecount = 0;
    NSArray *arr = [[NSArray alloc] initWithArray: NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)];
    NSString* sharefolder = [arr objectAtIndex: 0];
    NSDirectoryEnumerator *filePathsArray = [[NSFileManager defaultManager] enumeratorAtPath:sharefolder];
    
    for(NSString* file in filePathsArray)
    {
        // if the file is a "File"
        if ([[[filePathsArray fileAttributes] fileType] isEqualToString:NSFileTypeDirectory])
		{
			// Ignore any subdirectories
			[filePathsArray skipDescendents];
		}else {
            NSURL *fileurl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", sharefolder, file]];
            [self.filelist addObject:fileurl];
            filecount++;
        }
    }
    [arr release];
    self.navigationItem.title = [NSString stringWithFormat: NSLocalizedString(@"label_numsharedfiles", @"%d Files to Share:"), filecount];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.filelist removeAllObjects];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
        NSURL *target = [self.filelist objectAtIndex:indexPath.row];
        NSString* filename = [target lastPathComponent];
        // remove file
        NSError* error = nil;
        [[NSFileManager defaultManager]removeItemAtURL:target error:&error];
        
        if(error)
        {
            DEBUGMSG(@"There was an error in the file operation: %@", [error localizedDescription]);
            [[[[iToast makeText:[NSString stringWithFormat:NSLocalizedString(@"error_ShareFileDelError", @"Cannot remove the shared file."), [target lastPathComponent]]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }else{
            [self.filelist removeObjectAtIndex:indexPath.row];
            [self.tableView reloadData];
            // show hint to user
            [[[[iToast makeText:[NSString stringWithFormat:NSLocalizedString(@"state_FileDeleted", @"Delete File %@."), filename]] setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if([self.filelist count]>0) {
        return NSLocalizedString(@"label_InstSharedFile", @"Pick a file to attach:");
    }
    else {
        // no files
        return NSLocalizedString(@"label_InstNoSharedFile", @"No shared file. Connect your device with iTunes and Drag files to the shared folder.");
    }
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
    return [self.filelist count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FileCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    cell.textLabel.text = [[self.filelist objectAtIndex:indexPath.row] lastPathComponent];
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSURL *fileurl = [self.filelist objectAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath: indexPath animated: YES];
    MessageComposer *composer = [[self.delegate.navController viewControllers]objectAtIndex:[[self.delegate.navController viewControllers]count]-2];
    [composer setAttachment: fileurl];
    [self.delegate.navController popViewControllerAnimated:YES];
}

@end
