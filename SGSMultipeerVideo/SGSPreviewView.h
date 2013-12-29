//
//  SGSPreviewView.h
//  SGSMultipeerVideo
//
//  Created by PJ Gray on 12/29/13.
//  Copyright (c) 2013 Say Goodnight Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface SGSPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
