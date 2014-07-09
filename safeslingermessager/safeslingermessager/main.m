//
//  main.m
//  safeslingermessager
//
//  Created by Yueh-Hsun Lin on 6/8/14.
//  Copyright (c) 2014 CyLab. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "IdleHandler.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, NSStringFromClass([IdleHandler class]), NSStringFromClass([AppDelegate class]));
    }
}
