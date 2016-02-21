//
//  ViewController.swift
//  LiveCameraFiltering
//
//  Created by Simon Gladman on 05/07/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//
// Thanks to: http://www.objc.io/issues/21-camera-and-photos/camera-capture-on-ios/

import UIKit
import AVFoundation
import CoreMedia

let CMYKHalftone = "CMYK Halftone"
let CMYKHalftoneFilter = CIFilter(name: "CICMYKHalftone", withInputParameters: ["inputWidth" : 20, "inputSharpness": 1])

let ComicEffect = "Comic Effect"
let ComicEffectFilter = CIFilter(name: "CIComicEffect")

let Crystallize = "Crystallize"
let CrystallizeFilter = CIFilter(name: "CICrystallize", withInputParameters: ["inputRadius" : 30])

let Edges = "Edges"
let EdgesEffectFilter = CIFilter(name: "CIEdges", withInputParameters: ["inputIntensity" : 10])

let HexagonalPixellate = "Hex Pixellate"
let HexagonalPixellateFilter = CIFilter(name: "CIHexagonalPixellate", withInputParameters: ["inputScale" : 40])

let Invert = "Invert"
let InvertFilter = CIFilter(name: "CIColorInvert")

let Pointillize = "Pointillize"
let PointillizeFilter = CIFilter(name: "CIPointillize", withInputParameters: ["inputRadius" : 30])

let LineOverlay = "Line Overlay"
let LineOverlayFilter = CIFilter(name: "CILineOverlay")

let Posterize = "Posterize"
let PosterizeFilter = CIFilter(name: "CIColorPosterize", withInputParameters: ["inputLevels" : 5])

let Filters = [
    CMYKHalftone: CMYKHalftoneFilter,
    ComicEffect: ComicEffectFilter,
    Crystallize: CrystallizeFilter,
    Edges: EdgesEffectFilter,
    HexagonalPixellate: HexagonalPixellateFilter,
    Invert: InvertFilter,
    Pointillize: PointillizeFilter,
    LineOverlay: LineOverlayFilter,
    Posterize: PosterizeFilter
]

let FilterNames = [String](Filters.keys).sort()

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate
{
    let mainGroup = UIStackView()
    let imageView = UIImageView(frame: CGRectZero)
    let filtersControl = UISegmentedControl(items: FilterNames)

    var recorder: AVAudioRecorder!
    var levelTimer = NSTimer()
    var lowPassResults: Double = 0.0
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        /*
        Sound Stuff
        */
        //make an AudioSession, set it to PlayAndRecord and make it active
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! audioSession.setActive(true)
        
        //set up the URL for the audio file
        let documents: AnyObject = NSSearchPathForDirectoriesInDomains( NSSearchPathDirectory.DocumentDirectory,  NSSearchPathDomainMask.UserDomainMask, true)[0]
        let str =  documents.stringByAppendingPathComponent("recordTest.caf")
        let url = NSURL.fileURLWithPath(str as String)
        
        // make a dictionary to hold the recording settings so we can instantiate our AVAudioRecorder
        let recordSettings:[String : AnyObject] = [
            AVFormatIDKey: NSNumber(unsignedInt:kAudioFormatAppleLossless),
            AVEncoderAudioQualityKey : AVAudioQuality.Max.rawValue,
            AVEncoderBitRateKey : 320000,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey : 44100.0
        ]
        
        //Instantiate an AVAudioRecorder
        try! recorder = AVAudioRecorder(URL:url, settings: recordSettings)
        //If there's an error, print that shit - otherwise, run prepareToRecord and meteringEnabled to turn on metering (must be run in that order)
        recorder.prepareToRecord()
        recorder.meteringEnabled = true
        
        //start recording
        recorder.record()
        
        print(recorder.averagePowerForChannel(0))
        
        //instantiate a timer to be called with whatever frequency we want to grab metering values
        self.levelTimer = NSTimer.scheduledTimerWithTimeInterval(0.02, target: self, selector: Selector("levelTimerCallback"), userInfo: nil, repeats: true)
        
        
        
        view.addSubview(mainGroup)
        mainGroup.axis = UILayoutConstraintAxis.Vertical
        mainGroup.distribution = UIStackViewDistribution.Fill
        
        mainGroup.addArrangedSubview(imageView)
        mainGroup.addArrangedSubview(filtersControl)
        
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        filtersControl.selectedSegmentIndex = 0
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        let backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        do
        {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            captureSession.addInput(input)
        }
        catch
        {
            print("can't access camera")
            return
        }
        
        // although we don't use this, it's required to get captureOutput invoked
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.startRunning()
        
        
        
        
        
            
    
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        guard let filter = Filters[FilterNames[filtersControl.selectedSegmentIndex]] else
        {
            return
        }
        //print("Capture output running")
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(CVPixelBuffer: pixelBuffer!)
        
        //let imageForDisplay = UIImage(CIImage: cameraImage);
        CVPixelBufferLockBaseAddress(pixelBuffer!,0);
    
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 0);
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!) * 4;
        let width = CVPixelBufferGetWidth(pixelBuffer!);
        let height = CVPixelBufferGetHeight(pixelBuffer!);
        let colorSpace = CGColorSpaceCreateDeviceRGB();
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue)
        let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, bitmapInfo.rawValue);
        CVPixelBufferUnlockBaseAddress(pixelBuffer!,0);
        
        let data = CGBitmapContextGetData(context)
        let dataType = UnsafePointer<UInt8>(data)
        
        var totalBrightness = CGFloat(0.0)
        for index in 1...height {
            for index1 in 1...width / 4 {
                let offset = 4*((Int(width) * Int(index1)) + Int(index))
                let alphaValue = dataType[offset]
                let redColor = dataType[offset+1]
                let greenColor = dataType[offset+2]
                let blueColor = dataType[offset+3]
                
                let redFloat = CGFloat(redColor)/255.0
                let greenFloat = CGFloat(greenColor)/255.0
                let blueFloat = CGFloat(blueColor)/255.0
                let alphaFloat = CGFloat(1)/255.0
                let brightness = redFloat * 0.3 + greenFloat * 0.59 + blueFloat * 0.11;
                totalBrightness = totalBrightness + brightness
                print("brightness=\(brightness)")
            }
        }
        
        
        //print("total=\(totalBrightness / CGFloat(height + width / 4))")

        
        
  
   
//        unsigned char* pixels = [self rgbaPixels];
//        double totalLuminance = 0.0;
//        for(int p=0;p<self.size.width*self.size.height*4;p+=4)
//        {
//            totalLuminance += pixels[p]*0.299 + pixels[p+1]*0.587 + pixels[p+2]*0.114;
//        }
//        totalLuminance /= (self.size.width*self.size.height);
//        totalLuminance /= 255.0;
//        return totalLuminance;
//        
//        totalLuminance = totalLuminance/Double(countPixels);
//        
//        print(totalLuminance);

        filter!.setValue(cameraImage, forKey: kCIInputImageKey)
        
        let filteredImage = UIImage(CIImage: filter!.valueForKey(kCIOutputImageKey) as! CIImage!)

        dispatch_async(dispatch_get_main_queue())
        {
            self.imageView.image = filteredImage;
        }
        
    }
    
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
        let context = CIContext(options: nil)
        return context.createCGImage(inputImage, fromRect: inputImage.extent)
    }
    
    override func viewDidLayoutSubviews()
    {
        let topMargin = topLayoutGuide.length
        
        mainGroup.frame = CGRect(x: 0, y: topMargin, width: view.frame.width, height: view.frame.height - topMargin).insetBy(dx: 5, dy: 5)
    }
    
    func levelTimerCallback() {
        recorder.updateMeters()
        //print(recorder.averagePowerForChannel(0))
        
    }
    
}


