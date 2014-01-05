//
//  SGSViewController.m
//  SGSMultipeerVideo
//
//  Created by PJ Gray on 12/29/13.
//  Copyright (c) 2013 Say Goodnight Software. All rights reserved.
//

#import "SGSViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <malloc/malloc.h>
#import "AVCaptureMultipeerVideoDataOutput.h"

@interface SGSViewController () {
}

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (nonatomic) AVCaptureSession *captureSession;

@end

@implementation SGSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Create the AVCaptureSession
    self.captureSession = [[AVCaptureSession alloc] init];

	// Setup the preview view
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    captureVideoPreviewLayer.frame = CGRectMake(0,0, 320, 320);
    [self.previewView.layer addSublayer:captureVideoPreviewLayer];

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    [self.captureSession addInput:videoDeviceInput];
    
    
    AVCaptureMultipeerVideoDataOutput *multipeerVideoOutput = [[AVCaptureMultipeerVideoDataOutput alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    
    [self.captureSession addOutput:multipeerVideoOutput];
    
    [self setFrameRate:15 onDevice:videoDevice];

    [self.captureSession startRunning];

}

- (void) setFrameRate:(NSInteger) framerate onDevice:(AVCaptureDevice*) videoDevice {
    if ([videoDevice lockForConfiguration:nil]) {
        videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,framerate);
        videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,framerate);
        [videoDevice unlockForConfiguration];
    }
}

@end
