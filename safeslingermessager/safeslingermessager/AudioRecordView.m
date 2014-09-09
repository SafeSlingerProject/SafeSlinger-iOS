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


#import "AudioRecordView.h"
#import "AppDelegate.h"
#import "ErrorLogger.h"
#import <safeslingerexchange/iToast.h>

@interface AudioRecordView ()

@end

@implementation AudioRecordView

@synthesize PlayBtn, RecordBtn, SaveBtn, StopBtn, polling_timer, delegate, DiscardBtn, TimeLabel, audio_recorder;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    delegate = [[UIApplication sharedApplication]delegate];
    
    // self.navigationItem.hidesBackButton = YES;
    // Do any additional setup after loading the view from its nib.
    [DiscardBtn.titleLabel setText: NSLocalizedString(@"btn_discard", @"Discard")];
    [SaveBtn.titleLabel setText: NSLocalizedString(@"btn_Done", @"Done")];
    self.navigationItem.title = NSLocalizedString(@"title_soundrecoder", @"Sound Recorder");
    
    
    // check mic permission
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)
    {
        if([[NSUserDefaults standardUserDefaults] boolForKey: kRequireMicrophonePrivacy])
        {
            // Already request before
            [self RequestAudioRecorder];
        }else
        {
            UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
                                                              message: NSLocalizedString(@"iOS_RequestPermissionMicrophone", @"You can record a voice message to send your friends and SafeSlinger will encrypt it for you. To enable this feature, you must allow SafeSlinger access to your Microphone when asked.")
                                                             delegate: self
                                                    cancelButtonTitle: NSLocalizedString(@"btn_Cancel", @"Cancel")
                                                    otherButtonTitles: NSLocalizedString(@"btn_Continue", @"Continue"), nil];
            message.tag = AskPerm;
            [message show];
            message = nil;
        }
        
        
    }else{
        PlayBtn.enabled = StopBtn.enabled = NO;
        [self PrepareAudioRecorder];
    }
}

-(void) RequestAudioRecorder
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
            [ErrorLogger ERRORDEBUG: NSLocalizedString(@"error_AudioRecorderPermissionError", @"Microphone Permission required. Please go to Settings to turn on Microphone privacy access.")];
            
            UIAlertView *message = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"title_find", @"Setup")
                                                              message: NSLocalizedString(@"error_AudioRecorderPermissionError", @"Microphone Permission required. Please go to Settings to turn on Microphone privacy access.")
                                                             delegate:self
                                                    cancelButtonTitle:NSLocalizedString(@"btn_Close", @"Close")
                                                    otherButtonTitles:NSLocalizedString(@"menu_Help", @"Help"), nil];
            message.tag = HelpMicrophone;
            [message show];
            message = nil;
        }
    }];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.tag==HelpMicrophone)
    {
        if(buttonIndex==alertView.cancelButtonIndex)
        {
            [self performSegueWithIdentifier:@"FinishRecording" sender:self];
        }else{
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:kMicrophoneHelpURL]];
        }
    }else if(alertView.tag==AskPerm)
    {
        if(buttonIndex==alertView.cancelButtonIndex)
        {
            [self performSegueWithIdentifier:@"FinishRecording" sender:self];
        }else{
            // reguest microphone permission
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey: kRequireMicrophonePrivacy];
            [self RequestAudioRecorder];
        }
    }
    
}

-(void)PrepareAudioRecorder
{
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyyMMdd-HHmmss"];
    NSString *dateString = [format stringFromDate:[[NSDate alloc] init]];
    
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

- (IBAction) play
{
    if (!audio_recorder.recording)
    {
        StopBtn.enabled = YES;
        RecordBtn.enabled = NO;
        
        if (audio_player) audio_player = nil;
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
            TimeLabel.text = @"00:00";
            NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                              target:self
                                                            selector:@selector(CalPLAYTime)
                                                            userInfo:nil
                                                             repeats:YES];
            polling_timer = timer;
            [audio_player play];
        }
    }
}

- (IBAction) discard
{
    TimeLabel.text = @"00:00";
    StopBtn.enabled = PlayBtn.enabled = NO;
    RecordBtn.enabled = YES;
    
    [DiscardBtn setHidden:YES];
    [SaveBtn setHidden:YES];
    
    [audio_recorder stop];
    // audio_recorder = nil;
}

- (IBAction) save
{
    [DiscardBtn setHidden:YES];
    [SaveBtn setHidden:YES];
    
    [self performSegueWithIdentifier:@"FinishRecording" sender:self];
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
    
    RecordBtn.enabled = StopBtn.enabled = NO;
    PlayBtn.enabled = YES;
    
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end