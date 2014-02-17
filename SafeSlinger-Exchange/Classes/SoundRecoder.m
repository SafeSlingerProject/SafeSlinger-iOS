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

#import "SoundRecoder.h"
#import "KeySlingerAppDelegate.h"
#import "ErrorLogger.h"

@implementation SoundRecoder

@synthesize PlayBtn, RecordBtn, SaveBtn, StopBtn, polling_timer, delegate, DiscardBtn, TimeLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        delegate = [[UIApplication sharedApplication]delegate];
    }
    return self;
}

- (void)dealloc
{
    [audio_recorder release];audio_recorder = nil;
    [audio_player release];audio_player = nil;
    delegate = nil;
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    // Do any additional setup after loading the view from its nib.
    [DiscardBtn.titleLabel setText: NSLocalizedString(@"btn_discard", @"Discard")];
    [SaveBtn.titleLabel setText: NSLocalizedString(@"btn_Done", @"Done")];
    self.navigationItem.title = NSLocalizedString(@"title_soundrecoder", @"Sound Recorder");
    
    
    // check mic permission
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (granted) {
                // Microphone enabled
                AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
                [audioSession setActive:YES error:nil];
                PlayBtn.enabled = StopBtn.enabled = NO;
                RecordBtn.enabled = YES;
                [self PrepareAudioRecorder];
            }
            else {
                // Microphone disabled
                PlayBtn.enabled = StopBtn.enabled = RecordBtn.enabled = NO;
                self.TimeLabel.text = @"--:--";
                [[[[iToast makeText: NSLocalizedString(@"error_AudioRecorderPermissionError", @"Microphone Permission required. Please go to Settings to turn on Microphone privacy access.")]
                   setGravity:iToastGravityCenter] setDuration:iToastDurationLong] show];
                [ErrorLogger ERRORDEBUG: @"ERROR: Microphone is disabled."];
            }
        }];
    }else{
        PlayBtn.enabled = StopBtn.enabled = NO;
        [self PrepareAudioRecorder];
    }
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    
}

-(void)PrepareAudioRecorder
{
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyyMMdd-HHmmss"];
    NSString *dateString = [format stringFromDate:[[NSDate alloc] init]];
    [format release];
    
    // create tempral file to store sound
    NSString* soundFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat:@"sound-%@.aac", dateString]];
    if([[NSFileManager defaultManager] fileExistsAtPath: soundFilePath])
        [[NSFileManager defaultManager] removeItemAtPath:soundFilePath error:nil];
    
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:AVAudioQualityMin],
                                    AVEncoderAudioQualityKey,
                                    [NSNumber numberWithInt: kAudioFormatMPEG4AAC],
                                    AVFormatIDKey,
                                    [NSNumber numberWithInt:16],
                                    AVEncoderBitRateKey,
                                    [NSNumber numberWithInt: 2],
                                    AVNumberOfChannelsKey,
                                    [NSNumber numberWithFloat:44100.0],
                                    AVSampleRateKey,
                                    nil];
    NSError *error = nil;
    
    audio_recorder = [[AVAudioRecorder alloc]
                     initWithURL:soundFileURL
                     settings:recordSettings
                     error:&error];
    
    if (error)
    {
        [[[[iToast makeText: NSLocalizedString(@"error_RecoderError", @"Cannot prepare the audio recorder.")]
           setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
        [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error: %@", [error localizedDescription]]];
        PlayBtn.enabled = StopBtn.enabled = RecordBtn.enabled = NO;
        self.TimeLabel.text = @"--:--";
    } else {
        [audio_recorder prepareToRecord];
    }
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    RecordBtn.enabled = YES;
    StopBtn.enabled = NO;
}
-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    [[[[iToast makeText: NSLocalizedString(@"error_AudioPlayerDecodeError", @"Audio Player Decoding Error.")]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    [ErrorLogger ERRORDEBUG: @"ERROR: AudioPlayer Decode Error."];
}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder
                          successfully:(BOOL)flag
{
    
}

-(void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                  error:(NSError *)error
{
    [[[[iToast makeText: NSLocalizedString(@"error_AudioRecorderEncodeError", @"Audio Recorder Encoding Error.")]
       setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
    [ErrorLogger ERRORDEBUG: @"ERROR: AudioPlayer Encode Error."];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction) play
{
    if (!audio_recorder.recording)
    {
        StopBtn.enabled = YES;
        RecordBtn.enabled = NO;
        
        if (audio_player)[audio_player release];
        NSError *error;
        audio_player = [[AVAudioPlayer alloc]
                       initWithContentsOfURL:audio_recorder.url
                       error:&error];
        audio_player.delegate = self;
        
        if (error)
        {
            [[[[iToast makeText: NSLocalizedString(@"error_AudioPlayerError", @"Cannot Play The Recodring.")]
               setGravity:iToastGravityCenter] setDuration:iToastDurationNormal] show];
            [ErrorLogger ERRORDEBUG: [NSString stringWithFormat: @"Error: %@", [error localizedDescription]]];
        }else {
            [audio_player play];
            TimeLabel.text = @"00:00";
            NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                              target:self
                                                            selector:@selector(CalPLAYTime)
                                                            userInfo:nil
                                                             repeats:YES];
            polling_timer = timer;
        }
    }
}

- (IBAction) discard
{
    TimeLabel.text = @"00:00";
    StopBtn.enabled = NO;
    PlayBtn.enabled = RecordBtn.enabled = YES;
    
    [DiscardBtn setHidden:YES];
    [SaveBtn setHidden:YES];
    
    [audio_recorder stop];
    [audio_recorder release];
    audio_recorder = nil;
    
    // push back to the composer
    MessageComposer *precontroller = [[self.delegate.navController viewControllers]objectAtIndex:[[self.delegate.navController viewControllers]count]-2];
    // save url for attachment
    [precontroller setAttachment: audio_recorder.url];
    [delegate.navController popViewControllerAnimated:YES];
}

- (IBAction) save
{
    [DiscardBtn setHidden:YES];
    [SaveBtn setHidden:YES];
    // push back to the composer
    MessageComposer *precontroller = [[self.delegate.navController viewControllers]objectAtIndex:[[self.delegate.navController viewControllers]count]-2];
    // save url for attachment
    [precontroller setAttachment: [audio_recorder.url retain]];
    [delegate.navController popViewControllerAnimated:YES];
}

- (IBAction) record
{
    if (!audio_recorder.recording)
    {
        [DiscardBtn setHidden:YES];
        [SaveBtn setHidden:YES];
        TimeLabel.text = @"00:00";
        
        RecordBtn.enabled = NO;
        PlayBtn.enabled = NO;
        StopBtn.enabled = YES;
        [audio_recorder record];
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                          target:self
                                                        selector:@selector(CalRECTime)
                                                        userInfo:nil
                                                           repeats:YES];
        polling_timer = timer;
    }
}

- (IBAction) stop
{
    if(polling_timer.isValid)
        [polling_timer invalidate];
    
    StopBtn.enabled = NO;
    PlayBtn.enabled = YES;
    RecordBtn.enabled = YES;
    
    if (audio_recorder.recording)
    {
        [audio_recorder stop];
        [DiscardBtn setHidden:NO];
        [SaveBtn setHidden:NO];
    } else if (audio_player.playing) {
        [audio_player stop];
    }
}

- (void) CalRECTime
{
    NSString *sec_label = nil, *min_label = nil;
    int min = 0, sec = 0;
    if (audio_recorder.recording) {
        min = audio_recorder.currentTime/60;
        sec = audio_recorder.currentTime - min*60;
    }
    sec_label = (sec<10) ? [NSString stringWithFormat:@"0%d", sec]: [NSString stringWithFormat:@"%d", sec];
    min_label = (min<10) ? [NSString stringWithFormat:@"0%d", min]: [NSString stringWithFormat:@"%d", min];
    TimeLabel.text = [NSString stringWithFormat:@"%@:%@", min_label, sec_label];
}

- (void) CalPLAYTime
{
    NSString *sec_label = nil, *min_label = nil;
    int min = 0, sec = 0;
    if(audio_player.playing) {
        min = audio_player.currentTime/60;
        sec = audio_player.currentTime - min*60;
    }else{
        if(polling_timer.isValid)[polling_timer invalidate];
    }
    sec_label = (sec<10) ? [NSString stringWithFormat:@"0%d", sec]: [NSString stringWithFormat:@"%d", sec];
    min_label = (min<10) ? [NSString stringWithFormat:@"0%d", min]: [NSString stringWithFormat:@"%d", min];
    TimeLabel.text = [NSString stringWithFormat:@"%@:%@", min_label, sec_label];
}

@end
