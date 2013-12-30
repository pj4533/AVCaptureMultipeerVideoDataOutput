//
//  SGSViewController.m
//  SGSMultipeerVideo
//
//  Created by PJ Gray on 12/29/13.
//  Copyright (c) 2013 Say Goodnight Software. All rights reserved.
//

#import "SGSViewController.h"
#import "SGSPreviewView.h"
#import <AVFoundation/AVFoundation.h>
#import <malloc/malloc.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface SGSViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,MCAdvertiserAssistantDelegate, MCSessionDelegate> {
    MCPeerID *_myDevicePeerId;
    MCSession *_session;
    MCAdvertiserAssistant *_advertiserAssistant;
    NSString* _displayName;
}

@property (weak, nonatomic) IBOutlet SGSPreviewView *previewView;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureVideoDataOutput *videoDataOutput;

@property BOOL deviceAuthorized;


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
    self.previewView.session = self.captureSession;
	
	// Check for device authorization
	[self checkDeviceAuthorizationStatus];
	
	// Dispatch the rest of session setup to the sessionQueue so that the main queue isn't blocked.
    self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	
	dispatch_async(self.sessionQueue, ^{

		NSError *error = nil;
		
		AVCaptureDevice *videoDevice = [SGSViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
		
		if (error)
		{
			NSLog(@"%@", error);
		}
		
		if ([self.captureSession canAddInput:videoDeviceInput])
		{
			[self.captureSession addInput:videoDeviceInput];
            self.videoDeviceInput = videoDeviceInput;
		}
				
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([self.captureSession canAddOutput:videoDataOutput]) {
            
            if ([videoDevice lockForConfiguration:nil]) {
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,5);
                videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,5);
                [videoDevice unlockForConfiguration];
            }
            

            [self.captureSession addOutput:videoDataOutput];
            self.videoDataOutput = videoDataOutput;
            [self.videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey]];
            [self.videoDataOutput setSampleBufferDelegate:self queue:self.sessionQueue];
            
        }
	});
}

- (void)viewWillAppear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[self.captureSession startRunning];
	});
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context1 = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                  bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context1);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context1);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    //I modified this line: [UIImage imageWithCGImage:quartzImage]; to the following to correct the orientation:
    UIImage *image =  [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:UIImageOrientationRight];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

    if (_session.connectedPeers.count) {
        UIImage* image = [self imageFromSampleBuffer:sampleBuffer];
        NSData *data = UIImageJPEGRepresentation(image, 0.2);
        
        [_session sendData:data toPeers:_session.connectedPeers withMode:MCSessionSendDataReliable error:nil];
    }
}


#pragma mark - utilities

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted) {
			//Granted access to mediaType
			self.deviceAuthorized = YES;
		}
		else {
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
											message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
                self.deviceAuthorized = NO;
			});
		}
	}];
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
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
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
}

@end
