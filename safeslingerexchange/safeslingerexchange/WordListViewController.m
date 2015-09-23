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

#import "WordListViewController.h"
#import "SafeSlinger.h"
#import "safeslingerexchange.h"
#import "iToast.h"
#import "Utility.h"
#import <sha3/sha3.h>

#include <stdlib.h>

@implementation WordListViewController

@synthesize correct_index, selected_index, word_lists, even_words, odd_words, wordlist_labels, numberlist_labels;
@synthesize delegate;
@synthesize HintLabel, MatchBtn, NotmatchBtn, WordListRoller, CompareLabel, PreferredLanguage;

// The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Load Dictionaries
        NSBundle *bundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:@"exchangeui" withExtension:@"bundle"]];
        NSString *plistPath = [bundle pathForResource: @"wordlist" ofType: @"plist"];
        NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile: plistPath];
        self.even_words = [dictionary objectForKey: @"even"];
        self.odd_words = [dictionary objectForKey: @"odd"];
        self.wordlist_labels = [[NSMutableArray alloc] init];
        self.numberlist_labels = [[NSMutableArray alloc] init];
        selected_index = NoWordSelect;
    }
    return self;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [MatchBtn setTitle: NSLocalizedStringFromBundle(delegate.res, @"btn_Match", @"Next") forState: UIControlStateNormal];
    [NotmatchBtn setTitle: NSLocalizedStringFromBundle(delegate.res, @"btn_NoMatch", @"No Match") forState: UIControlStateNormal];
    
    // ? button
    UIButton* infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(DisplayHow) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *HomeButton = [[UIBarButtonItem alloc] initWithCustomView: infoButton];
    [self.navigationItem setRightBarButtonItem:HomeButton];
    
    // customized cancel button
    UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc]initWithTitle: NSLocalizedStringFromBundle(delegate.res, @"btn_Cancel", @"Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(ExitProtocol:)];
    [self.navigationItem setLeftBarButtonItem:cancelBtn];
    self.navigationItem.hidesBackButton = YES;
    
    [HintLabel setText: NSLocalizedStringFromBundle(delegate.res, @"label_VerifyInstruct", @"All phones must match one of the 3-word phases. Compare, then pick the matching phrase.")];
}

- (void)DisplayHow
{
    // Display using UIAlertView
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromBundle(delegate.res, @"title_verify", @"Verify")
                                                                   message:NSLocalizedStringFromBundle(delegate.res, @"help_verify", @"Now, you must match one of these 3-word phrases with all users. Every user must must select the same common phrase, and press 'Next'.")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_Close", @"Close")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

-(IBAction) ButtonPressed: (id)sender
{
	if (((UIButton *)sender).tag == NoMatch)
	{
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromBundle(delegate.res, @"title_Question", @"Question")
                                                                       message:NSLocalizedStringFromBundle(delegate.res, @"ask_QuitConfirmation", @"Quit? Are you sure?")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* YesAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_Yes", @"Yes")
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  [delegate.protocol distributeNonces: NO Choice:nil];
                                                              }];
        
        [alert addAction:YesAction];
        UIAlertAction* NoAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_No", @"No")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
        
        [alert addAction:NoAction];
        [self presentViewController:alert animated:YES completion:nil];
	}
    else if(((UIButton *)sender).tag == Match)
    {
        if (selected_index == NoWordSelect)
        {
            [[[[iToast makeText: NSLocalizedStringFromBundle(delegate.res, @"error_NoWordListSelected", @"You must select one of the phrases before proceeding.")]setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        }else if (selected_index == correct_index)
        {
            // correct one
            NSString *label = [NSString stringWithFormat:@"%@\n%@", [wordlist_labels objectAtIndex: selected_index+1], [numberlist_labels objectAtIndex:selected_index+1]];
            [delegate.protocol distributeNonces: YES Choice:label];
        }else{
            // select decoy ones
            [delegate.protocol distributeNonces: NO Choice:nil];
        }
    }
	
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex!=alertView.cancelButtonIndex)
    {
        [delegate.protocol distributeNonces: NO Choice:nil];
    }
}

-(void) ExitProtocol: (id)sender
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromBundle(delegate.res, @"title_Question", @"Question")
                                                                   message:NSLocalizedStringFromBundle(delegate.res, @"ask_QuitConfirmation", @"Quit? Are you sure?")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* YesAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_Yes", @"Yes")
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action) {
                                                          [delegate.protocol distributeNonces: NO Choice:nil];
                                                      }];
    
    [alert addAction:YesAction];
    UIAlertAction* NoAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromBundle(delegate.res, @"btn_No", @"No")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action) {}];
    
    [alert addAction:NoAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) generateWordList: (NSData*)hash_data
{
    unsigned char* hashbytes = (unsigned char*)[hash_data bytes];
    
    NSString *decoyString1 = [NSString stringWithFormat:@""];
    NSString *decoyString2 = [NSString stringWithFormat:@""];
    unsigned int hashint[6] = {0, 0, 0, 0, 0, 0};
    
    // sort array of userIDs - ascending
    NSArray *userIDs = [[delegate.protocol.encrypted_dataSet allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            
    CFMutableBitVectorRef evenVec = CFBitVectorCreateMutable(NULL, 256);
    CFMutableBitVectorRef oddVec = CFBitVectorCreateMutable(NULL, 256);

    CFBitVectorSetCount(evenVec, 256);
    CFBitVectorSetCount(oddVec, 256);
    CFBitVectorSetBitAtIndex(evenVec, hashbytes[0], 1);
    CFBitVectorSetBitAtIndex(oddVec, hashbytes[1], 1);
    CFBitVectorSetBitAtIndex(evenVec, hashbytes[2], 1);
    
    // essentially need to sort list of user ids first
    // generate wordlist for every user id upto ours
    // then generate our wordlist
    int count = 0;
    BOOL foundUser = NO;
    
    for (NSString *id in userIDs) {
        // while its not equal to our user id
        if ([id isEqualToString:delegate.protocol.userID]) {
            foundUser = YES;
        }
            
        unsigned char *buf = malloc(HASHLEN + 1);
            
        *(unsigned char *)(buf) = (unsigned char) count;
        
        // copy elements over to buffer
        for (int i = 0; i < HASHLEN; i++) {
            *(buf + 1 + i) = *(hashbytes + i);
        }
        
        NSData* hash = [sha3 Keccak256Digest:[NSData dataWithBytes:buf length:HASHLEN + 1]];
        free(buf);
        
        unsigned char *hasharray = (unsigned char*)[hash bytes];
        // 2 decoy wordlists for each user
        for (int d = 0; d < 2; d++) {
                                
            // pick words that do not collide with others in the bit vector
            // also assure that we correctly seek back to the first byte if
            // collisions exceed the maximum byte value
            while (CFBitVectorGetBitAtIndex(evenVec,hasharray[0 + 3*d]) == 1) {
                hasharray[0 + 3*d] =  ( hasharray[0 + 3*d] == 255 ) ? (hasharray[0 + 3*d] - 255) : (hasharray[0 + 3*d] + 1);
            } 
            while (CFBitVectorGetBitAtIndex(oddVec,hasharray[1 + 3*d]) == 1) {
                hasharray[1 + 3*d] =  ( hasharray[1 + 3*d] == 255 ) ? (hasharray[1 + 3*d] - 255) : (hasharray[1 + 3*d] + 1);
            }
            while (CFBitVectorGetBitAtIndex(evenVec,hasharray[2 + 3*d]) == 1) {
                hasharray[2 + 3*d] =  ( hasharray[2 + 3*d] == 255 ) ? (hasharray[2 + 3*d] - 255) : (hasharray[2 + 3*d] + 1);
            }
            
            CFBitVectorSetBitAtIndex(evenVec, hasharray[0 + 3*d], 1);
            CFBitVectorSetBitAtIndex(oddVec, hasharray[1 + 3*d], 1);
            CFBitVectorSetBitAtIndex(evenVec, hasharray[2 + 3*d], 1);                
                
            // computer decoy strings only if user is found
            if (d == 0 && foundUser) {
                decoyString1 = [NSString stringWithFormat:@"%@   %@   %@", [even_words  objectAtIndex:hasharray[0]], [odd_words objectAtIndex:hasharray[1]], [even_words objectAtIndex:hasharray[2]]];
                hashint[0] = hasharray[0];
                hashint[1] = hasharray[1];
                hashint[2] = hasharray[2];
            }
            else if (foundUser) {
                decoyString2 = [NSString stringWithFormat:@"%@   %@   %@", [even_words  objectAtIndex:hasharray[3]], [odd_words objectAtIndex:hasharray[4]], [even_words objectAtIndex:hasharray[5]]];
                hashint[3] = hasharray[3];
                hashint[4] = hasharray[4];
                hashint[5] = hasharray[5];
            }
        }
        
        if (foundUser) 
            break;
            
        count++;
    }
    
    // to set the correct wordlist at some random position
    u_int32_t r = arc4random();
    self.correct_index = r % 3;
        
    NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity: 3];
    BOOL d1Added = NO;
    
    // for lazy users
    [wordlist_labels addObject: @""];
    [numberlist_labels addObject: @""];
    
    int number = 0;
    // numeric lables
    for (int i = 0; i < 3; i++) {
        NSMutableString* numericString = [NSMutableString string];
        if (i == correct_index)
        {
            for(int j=0;j<3;j++)
            {
                number = hashbytes[j];
                number = (((j % 2 == 0) ? number : (number + 256)) + 1);
                [numericString appendFormat:@"%d   ", number];
            }
        }
        else {
            // if decoy list 1 is not added, then add it
            if (!d1Added) {
                for(int j=0;j<3;j++)
                {
                    number = hashint[j];
                    number = (((j % 2 == 0) ? number : (number + 256)) + 1);
                    [numericString appendFormat:@"%d   ", number];
                }
                d1Added = YES;
            }
            // add decoy list 2
            else {
                for(int j=0;j<3;j++)
                {
                    number = hashint[j+3];
                    number = (((j % 2 == 0) ? number : (number + 256)) + 1);
                    [numericString appendFormat:@"%d   ", number];
                }
            }
        }
        [numberlist_labels addObject: numericString];
    }
    
    // then wordList
    d1Added = NO;
    for (int i = 0; i < 3; i++) {
        if (i == correct_index)
        {
            [arr addObject: [NSString stringWithFormat: @"%@   %@   %@",
                                [even_words objectAtIndex: (unsigned int)hashbytes[0]],
                                [odd_words objectAtIndex: (unsigned int)hashbytes[1]],
                                [even_words objectAtIndex: (unsigned int)hashbytes[2]]]];
        }
        else {
            // if decoy list 1 is not added, then add it
            if (!d1Added) {
                [arr addObject:decoyString1];
                d1Added = YES;
            }
            // add decoy list 2
            else {
                [arr addObject:decoyString2];
            }
        }
        
        [wordlist_labels addObject: [arr objectAtIndex: i]];
    }    
        
    self.word_lists = arr;
    
    CFRelease(evenVec);
    CFRelease(oddVec);
}
    
        
- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}
    
- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    PreferredLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    [CompareLabel setText:[NSString stringWithFormat: NSLocalizedStringFromBundle(delegate.res, @"label_CompareScreensNDevices", @"Compare screens on %@ devices.."), [NSString stringWithFormat:@"%d", delegate.protocol.users]]];
    [self generateWordList: [delegate.protocol generateHashForPhrases]];
    
    if(delegate.first_use) [self DisplayHow];
}
    
#pragma mark UIPickerViewDelegate
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *pickerLabel = (UILabel *)view;
    
    if (!pickerLabel) {
        CGRect frame = CGRectMake(0.0, 0.0, [[UIScreen mainScreen] bounds].size.width, 70);
        pickerLabel = [[UILabel alloc] initWithFrame:frame];
        pickerLabel.textAlignment = NSTextAlignmentCenter;
        [pickerLabel setBackgroundColor:[UIColor clearColor]];
        [pickerLabel setFont:[UIFont boldSystemFontOfSize:16]];
        [pickerLabel setNumberOfLines:0];
    }
    
    NSString *label = nil;
    if([PreferredLanguage isEqualToString:@"en"])
        label = [NSString stringWithFormat:@"%@\n%@", [wordlist_labels objectAtIndex: row], [numberlist_labels objectAtIndex:row]];
    else
        label = [NSString stringWithFormat:@"%@\n%@", [numberlist_labels objectAtIndex: row], [wordlist_labels objectAtIndex:row]];
    
    [pickerLabel setText:label];
    return pickerLabel;
}

-(void) pickerView: (UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent: (NSInteger)component 
{
    self.selected_index = (int)row-1;
}
    
#pragma mark UIPickerViewDataSource
-(NSInteger) numberOfComponentsInPickerView: (UIPickerView *)pickerView {
    return 1;
}

-(NSInteger) pickerView: (UIPickerView *)pickerView numberOfRowsInComponent: (NSInteger)component   {
    return 4; // 3 phrases + 1 empty
}
    
@end
