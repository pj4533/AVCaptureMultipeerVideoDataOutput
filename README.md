AVCaptureMultipeerVideoDataOutput
=================

Advertises one stream of video over a multipeer connection.

Use [SGSMultipeerVideoMixer](https://github.com/pj4533/SGSMultipeerVideoMixer) for an example of how to view.

## Details

Multipeer connection stuff is abstracted inside an AVCaptureVideoDataOutput subclass so setup is easy using the normal AV pipeline:

```objective-c
// Create the AVCaptureSession
self.captureSession = [[AVCaptureSession alloc] init];

// Setup the preview view
AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
captureVideoPreviewLayer.frame = CGRectMake(0,0, 320, 320);
[self.previewView.layer addSublayer:captureVideoPreviewLayer];

// Create video device input
AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
[self.captureSession addInput:videoDeviceInput];

// Create output
AVCaptureMultipeerVideoDataOutput *multipeerVideoOutput = [[AVCaptureMultipeerVideoDataOutput alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
[self.captureSession addOutput:multipeerVideoOutput];

[self.captureSession startRunning];
```

Thats it!  Look in the AVCaptureMultipeerVideoDataOutput class for more details on the format & size of the image sent.  The NSData that gets sent over the wire is described below.

### Peer Setup

The peer needs to be looking for service type 'multipeer-video'.  If you use the built in browser viewcontroller (like [SGSMultipeerVideoMixer](https://github.com/pj4533/SGSMultipeerVideoMixer) uses) it will look something like this:

```objective-c
- (void) showAssistant {
    MCBrowserViewController* browserVC = [[MCBrowserViewController alloc] initWithServiceType:@"multipeer-video" session:_session];
    browserVC.delegate = self;
    [self presentViewController:browserVC animated:YES completion:nil];
}
```

AVCaptureMultipeerVideoDataOutput sends a NSDictionary structured like this:

```objective-c
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    
    NSDictionary* dict = (NSDictionary*) [NSKeyedUnarchiver unarchiveObjectWithData:data];

    // the actual image data (as JPG)
    UIImage* image = [UIImage imageWithData:dict[@"image"] scale:2.0];
    
    // the current FPS 
    NSNumber* framesPerSecond = dict[@"framesPerSecond"];
    
    // the timestamp of this frame
    NSNumber* timestamp = dict[@"timestamp"];
}
```


### Advertiser Setup

Uses cocoapods, so just add to your Podfile

```pod "AVCaptureMultipeerVideoDataOutput"```

See the Sample project for an example implementation.  To run the sample:

```
pod install
```

Then open 'MultipeerVideoOutputSample.xcworkspace'

## To Do

* Expose more of the output format variables

## Contact

PJ Gray

- http://github.com/pj4533
- http://twitter.com/pj4533
- pj@pj4533.com

## License

AVCaptureMultipeerVideoDataOutput is available under the MIT license. See the LICENSE file for more info.
