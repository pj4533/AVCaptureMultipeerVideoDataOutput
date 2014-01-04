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
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface SGSViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,MCAdvertiserAssistantDelegate, MCSessionDelegate> {
    MCPeerID *_myDevicePeerId;
    MCSession *_session;
    MCAdvertiserAssistant *_advertiserAssistant;
    NSString* _displayName;
}

@property (weak, nonatomic) IBOutlet UIView *previewView;

@property (nonatomic) dispatch_queue_t sampleQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *captureSession;

@end

@implementation SGSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (!_displayName) {
        _displayName = [[UIDevice currentDevice] name];
    }
    _myDevicePeerId = [[MCPeerID alloc] initWithDisplayName:_displayName];
    
    _session = [[MCSession alloc] initWithPeer:_myDevicePeerId securityIdentity:nil encryptionPreference:MCEncryptionNone];
    _session.delegate = self;
    
    _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:@"multipeer-video" discoveryInfo:nil session:_session];
    [_advertiserAssistant start];

    
    
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
    
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self setFrameRate:5 onDevice:videoDevice];
    

    self.sampleQueue = dispatch_queue_create("VideoSampleQueue", DISPATCH_QUEUE_SERIAL);
    [videoDataOutput setSampleBufferDelegate:self queue:self.sampleQueue];
    videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    [self.captureSession addOutput:videoDataOutput];

    [self.captureSession startRunning];

}

- (UIImage*) cgImageBackedImageWithCIImage:(CIImage*) ciImage {
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef ref = [context createCGImage:ciImage fromRect:ciImage.extent];
    UIImage* image = [UIImage imageWithCGImage:ref scale:[UIScreen mainScreen].scale orientation:UIImageOrientationRight];
    CGImageRelease(ref);
    
    return image;
}

- (void) lowerFramerate {
    AVCaptureDeviceInput* deviceInput = self.captureSession.inputs[0];
    CMTime frameDuration = deviceInput.device.activeVideoMaxFrameDuration;
    [self setFrameRate:frameDuration.timescale-1 onDevice:deviceInput.device];
}

- (void) raiseFramerate {
    AVCaptureDeviceInput* deviceInput = self.captureSession.inputs[0];
    CMTime frameDuration = deviceInput.device.activeVideoMaxFrameDuration;
    [self setFrameRate:frameDuration.timescale+1 onDevice:deviceInput.device];
}

- (void) setFrameRate:(NSInteger) framerate onDevice:(AVCaptureDevice*) videoDevice {
    if ([videoDevice lockForConfiguration:nil]) {
        videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,framerate);
        videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,framerate);
        [videoDevice unlockForConfiguration];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

    if (_session.connectedPeers.count) {
        NSNumber* timestamp = @(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)));
        
        CVImageBufferRef cvImage = CMSampleBufferGetImageBuffer(sampleBuffer);
        CGRect cropRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(320, 320), CGRectMake(0,0, CVPixelBufferGetWidth(cvImage),CVPixelBufferGetHeight(cvImage)) );
        CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:cvImage];
        CIImage* croppedImage = [ciImage imageByCroppingToRect:cropRect];
        
        NSData *imageData = UIImageJPEGRepresentation([self cgImageBackedImageWithCIImage:croppedImage], 0.2);
        
        AVCaptureDeviceInput* deviceInput = self.captureSession.inputs[0];
        CMTime frameDuration = deviceInput.device.activeVideoMaxFrameDuration;
        NSDictionary* dict = @{
                               @"image": imageData,
                               @"timestamp" : timestamp,
                               @"framesPerSecond": @(frameDuration.timescale)
                               };
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dict];

        
        [_session sendData:data toPeers:_session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    }
}


#pragma mark - MCSessionDelegate Methods

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
	switch (state) {
		case MCSessionStateConnected:
            NSLog(@"PEER CONNECTED: %@", peerID.displayName);
			break;
		case MCSessionStateConnecting:
            NSLog(@"PEER CONNECTING: %@", peerID.displayName);
			break;
		case MCSessionStateNotConnected:
            NSLog(@"PEER NOT CONNECTED: %@", peerID.displayName);
			break;
	}
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSString* commandString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([commandString isEqualToString:@"raiseFramerate"]) {
        [self raiseFramerate];
    } else if ([commandString isEqualToString:@"lowerFramerate"]) {
        [self lowerFramerate];
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
}

@end
