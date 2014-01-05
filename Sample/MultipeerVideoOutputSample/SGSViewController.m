//
//  SGSViewController.m
//  MultipeerVideoOutputSample
//
//  Created by PJ Gray on 1/5/14.
//  Copyright (c) 2014 Say Goodnight Software. All rights reserved.
//

#import "SGSViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AVCaptureMultipeerVideoDataOutput.h"

@interface SGSViewController () {
    AVCaptureSession *_captureSession;
}

@property (weak, nonatomic) IBOutlet UIView *previewView;

@end

@implementation SGSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	// Create the AVCaptureSession
    _captureSession = [[AVCaptureSession alloc] init];
    
	// Setup the preview view
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    captureVideoPreviewLayer.frame = CGRectMake(0,0, 320, 320);
    [self.previewView.layer addSublayer:captureVideoPreviewLayer];
    
    // Create video device input
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if (videoDevice) {
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        [_captureSession addInput:videoDeviceInput];
        
        // Create output
        AVCaptureMultipeerVideoDataOutput *multipeerVideoOutput = [[AVCaptureMultipeerVideoDataOutput alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
        [_captureSession addOutput:multipeerVideoOutput];
        
        [self setFrameRate:15 onDevice:videoDevice];
        
        [_captureSession startRunning];
    } else {
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"No video device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) setFrameRate:(NSInteger) framerate onDevice:(AVCaptureDevice*) videoDevice {
    if ([videoDevice lockForConfiguration:nil]) {
        videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,framerate);
        videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,framerate);
        [videoDevice unlockForConfiguration];
    }
}

@end
