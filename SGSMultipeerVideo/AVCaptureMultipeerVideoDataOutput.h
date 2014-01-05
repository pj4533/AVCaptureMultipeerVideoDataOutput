//
//  AVCaptureMultipeerVideoDataOutput.h
//  SGSMultipeerVideo
//
//  Created by PJ Gray on 1/5/14.
//  Copyright (c) 2014 Say Goodnight Software. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@protocol AVCaptureMultipeerVideoDataOutputDelegate <NSObject>
@optional
- (void) raiseFramerate;
- (void) lowerFramerate;
@end

@interface AVCaptureMultipeerVideoDataOutput : AVCaptureVideoDataOutput

@property (strong, nonatomic) id delegate;

- (instancetype) initWithDisplayName:(NSString*) displayName;

@end
