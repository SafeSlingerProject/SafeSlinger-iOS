//
//  InvitationView.h
//  safeslingermessager
//
//  Created by Yueh-Hsun Lin on 6/30/14.
//  Copyright (c) 2014 CyLab. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface InvitationView : UIViewController

@property (nonatomic, strong) NSString* InviterName;
@property (nonatomic, strong) UIImage* InviterFaceImg;
@property (nonatomic, strong) IBOutlet UILabel *MeLabel;
@property (nonatomic, strong) IBOutlet UILabel *InviterLabel;
@property (nonatomic, strong) IBOutlet UILabel *InviteeLabel;
@property (nonatomic, strong) IBOutlet UIImageView *MyFace;
@property (nonatomic, strong) IBOutlet UIImageView *InviterFace;
@property (nonatomic, strong) IBOutlet UIImageView *InviteeFacel;
@property (nonatomic, strong) IBOutlet UIButton *AcceptBtn;
@property (nonatomic) ABRecordRef InviteeVCard;

-(IBAction) BeginImport: (id)sender;

@end
