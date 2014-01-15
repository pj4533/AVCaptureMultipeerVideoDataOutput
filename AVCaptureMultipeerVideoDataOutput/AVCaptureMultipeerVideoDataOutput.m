//
//  AVCaptureMultipeerVideoDataOutput.m
//
// Copyright (c) 2014 Say Goodnight Software
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AVCaptureMultipeerVideoDataOutput.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface AVCaptureMultipeerVideoDataOutput () <AVCaptureVideoDataOutputSampleBufferDelegate,MCAdvertiserAssistantDelegate, MCSessionDelegate,MCNearbyServiceAdvertiserDelegate> {
    dispatch_queue_t _sampleQueue;
    
    // Multipeer stuff - assistant is optional
    MCPeerID *_myDevicePeerId;
    MCSession *_session;
    MCAdvertiserAssistant *_advertiserAssistant;
    MCNearbyServiceAdvertiser *_nearbyAdvertiser;
}

@end

@implementation AVCaptureMultipeerVideoDataOutput

- (instancetype) initWithDisplayName:(NSString*) displayName {
    return [self initWithDisplayName:displayName withAssistant:YES];
}

- (instancetype) initWithDisplayName:(NSString*) displayName withAssistant:(BOOL) useAssistant {
    self = [super init];
    if (self) {
        _myDevicePeerId = [[MCPeerID alloc] initWithDisplayName:displayName];
        
        _session = [[MCSession alloc] initWithPeer:_myDevicePeerId securityIdentity:nil encryptionPreference:MCEncryptionNone];
        _session.delegate = self;
        
        NSString* serviceType = @"multipeer-video";
        
        if (useAssistant) {
            _advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:serviceType discoveryInfo:nil session:_session];
            [_advertiserAssistant start];
        } else {
            _nearbyAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_myDevicePeerId discoveryInfo:nil serviceType:serviceType];
            _nearbyAdvertiser.delegate = self;
            [_nearbyAdvertiser startAdvertisingPeer];
        }
        
        _sampleQueue = dispatch_queue_create("VideoSampleQueue", DISPATCH_QUEUE_SERIAL);
        [self setSampleBufferDelegate:self queue:_sampleQueue];
        self.alwaysDiscardsLateVideoFrames = YES;
    }
    return self;
}

- (UIImage*) cgImageBackedImageWithCIImage:(CIImage*) ciImage {
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef ref = [context createCGImage:ciImage fromRect:ciImage.extent];
    UIImage* image = [UIImage imageWithCGImage:ref scale:[UIScreen mainScreen].scale orientation:UIImageOrientationRight];
    CGImageRelease(ref);
    
    return image;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (_session.connectedPeers.count) {
        NSNumber* timestamp = @(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)));
        
        CVImageBufferRef cvImage = CMSampleBufferGetImageBuffer(sampleBuffer);
        CGRect cropRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(320, 320), CGRectMake(0,0, CVPixelBufferGetWidth(cvImage),CVPixelBufferGetHeight(cvImage)) );
        CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:cvImage];
        CIImage* croppedImage = [ciImage imageByCroppingToRect:cropRect];
        
        CIFilter *scaleFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        [scaleFilter setValue:croppedImage forKey:@"inputImage"];
        [scaleFilter setValue:[NSNumber numberWithFloat:0.25] forKey:@"inputScale"];
        [scaleFilter setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputAspectRatio"];
        CIImage *finalImage = [scaleFilter valueForKey:@"outputImage"];
        UIImage* cgBackedImage = [self cgImageBackedImageWithCIImage:finalImage];
        
        NSData *imageData = UIImageJPEGRepresentation(cgBackedImage, 0.2);
        
        // maybe not always the correct input?  just using this to send current FPS...
        AVCaptureInputPort* inputPort = connection.inputPorts[0];
        AVCaptureDeviceInput* deviceInput = (AVCaptureDeviceInput*) inputPort.input;
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

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
    if (invitationHandler) {
        invitationHandler(YES, _session);
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
        if (self.delegate && [self.delegate respondsToSelector:@selector(raiseFramerate)]) {
            [self.delegate raiseFramerate];
        }
    } else if ([commandString isEqualToString:@"lowerFramerate"]) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(lowerFramerate)]) {
            [self.delegate lowerFramerate];
        }
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
}

@end
