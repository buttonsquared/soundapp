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


class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,UIPickerViewDataSource, UIPickerViewDelegate
{
    let mainGroup = UIStackView()
    let imageView = UIImageView(frame: CGRectZero)
    let frameRateSelection = ["24","30","60","90"]
    var previousBrightness = CGFloat(0.0)
    var previousDecible = Float();
    var currentDecible = Float();
    var fpsRate = Float()
    var roomLevel = Float();
    var whiteLight = NSDate()
    var pop = NSDate()
    var whiteLightFound = false
    var popHeard = false
    var start = false;
    var fps = Double();
    var count = 0;
    var previousSecond = 0;
    var starting = NSDate();
    var current = 1;
    var countCurrent = 0;
    var isCalibrating = false;
    var offset = Float(25);

    @IBOutlet weak var calibrateButton: UIButton!
    @IBOutlet weak var calibrate: UITextField!
    @IBOutlet weak var fpsRunningRate: UILabel!
    @IBOutlet weak var fpsPicket: UIPickerView!
    @IBOutlet weak var decibleLevel: UILabel!
    @IBOutlet weak var second: UILabel!
    @IBOutlet weak var frameRateLabel: UILabel!
    var recorder: AVAudioRecorder!
    var levelTimer = NSTimer()
    var lowPassResults: Double = 0.0
    var text = ""
    let file = "settings.txt"
    
    
    @IBAction func doCalibrate(sender: AnyObject) {
        calibrate.hidden = !calibrate.hidden;
        isCalibrating = !isCalibrating;
    }
    
    @IBAction func startSync(sender: UIButton) {
        second.text = " "
        frameRateLabel.text = " "
        whiteLightFound = false
        popHeard = false
        start = true;
        
    }
    
    @IBAction func stopSync(sender: UIButton) {
        whiteLightFound = false
        popHeard = false;
        start = false;
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        loadSettings();
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try! audioSession.setActive(true)

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
        
        //instantiate a timer to be called with whatever frequency we want to grab metering values
        self.levelTimer = NSTimer.scheduledTimerWithTimeInterval(0.02, target: self, selector: Selector("levelTimerCallback"), userInfo: nil, repeats: true)
        


        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        let backCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        do
        {
            
            let input = try AVCaptureDeviceInput(device: backCamera)
           
            var finalFormat = AVCaptureDeviceFormat()
            var maxFps: Double = 0
            for vFormat in backCamera!.formats {
                var ranges      = vFormat.videoSupportedFrameRateRanges as!  [AVFrameRateRange]
                let frameRates  = ranges[0]
                
                
                if frameRates.maxFrameRate >= maxFps {
                    maxFps = frameRates.maxFrameRate
                    finalFormat = vFormat as! AVCaptureDeviceFormat
                }
            }
            print(maxFps);
            if maxFps != 0 {
                let timeValue = Int64(1200.0 / maxFps)
                let timeScale: Int32 = 1200
                try backCamera!.lockForConfiguration()
                backCamera!.activeFormat = finalFormat
                backCamera!.activeVideoMinFrameDuration = CMTimeMake(1, Int32(maxFps))
                backCamera!.activeVideoMaxFrameDuration = CMTimeMake(1, Int32(maxFps))
                backCamera!.focusMode = AVCaptureFocusMode.AutoFocus
                backCamera!.unlockForConfiguration()
            }
            
            
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
        count = count + 1;
        if (abs(Int(starting.timeIntervalSinceNow)) != current) {
            self.countCurrent = self.count;
            dispatch_async(dispatch_get_main_queue()) {
                self.fpsRunningRate.text = String(self.countCurrent)
            }
            current = abs(Int(starting.timeIntervalSinceNow));
            count = 0;
        }


        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let cameraImage = CIImage(CVPixelBuffer: pixelBuffer!)
        
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

        totalBrightness = 0;
        //for index in 1...height {
            //for index1 in 1...width / 4 {
        var index1 = (width / 4) / 2
        var index = height / 2;
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
 
            //}
        //}
        
        var percentageChange = ((totalBrightness - previousBrightness) / previousBrightness) * 100
        if (percentageChange > 40 && start && !whiteLightFound) {
            print("brightness=\(totalBrightness) \(previousBrightness) \(percentageChange)")
            whiteLight = NSDate();
            whiteLightFound = true;
            if (popHeard) {
                dispatch_async(dispatch_get_main_queue()) {
                    self.fpsRate = Float(self.frameRateSelection[self.fpsPicket.selectedRowInComponent(0)])!
                    let timeElapsed = abs(Float(self.pop.timeIntervalSinceDate(self.whiteLight)))
                    let seconds = Int(timeElapsed)
                    var mili = 0;
                    if (timeElapsed >= 1) {
                        mili = Int((timeElapsed - Float(seconds)) * 1000)
                    } else {
                        mili = Int((timeElapsed) * 1000)
                    }
                    print("\(seconds) \(abs(mili))");
                    var frameRate = Int(Float(seconds) * self.fpsRate);
                    var displayString = String(frameRate);
                    if (abs(mili) < 250) {
                        displayString = displayString + " 1/4";
                    } else if (abs(mili) >= 250 && abs(mili) < 500) {
                        displayString = displayString + " 2/4";
                    } else if (abs(mili) >= 500 && abs(mili) < 750) {
                        displayString = displayString + " 3/4";
                    } else {
                        displayString = String((frameRate + 1))
                    }
                    self.frameRateLabel.text = displayString
                    self.second.text = self.stringFromTimeInterval(self.pop.timeIntervalSinceDate(self.whiteLight)) as String
                }
            }
        }
        previousBrightness = totalBrightness;

//
        
    }
    
    func runAfterDelay(delay: NSTimeInterval, block: dispatch_block_t) {
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
        dispatch_after(time, dispatch_get_main_queue(), block)
    }
    
    func levelTimerCallback() {
        recorder.updateMeters()
        currentDecible = recorder.averagePowerForChannel(0);
        var percentageChange = ((abs(currentDecible) - abs(previousDecible)) / abs(previousDecible)) * 100
        if (abs(percentageChange) > 40 && !popHeard && start) {
            print("audio=\(currentDecible) \(previousDecible) \(percentageChange)")
            popHeard = true
            pop = NSDate();
            if (whiteLightFound) {
                dispatch_async(dispatch_get_main_queue()) {
                    self.fpsRate = Float(self.frameRateSelection[self.fpsPicket.selectedRowInComponent(0)])!
                    let timeElapsed = abs(Float(self.pop.timeIntervalSinceDate(self.whiteLight)))
                    let seconds = Int(timeElapsed)
                    var mili = 0;
                    if (timeElapsed >= 1) {
                        mili = Int((timeElapsed - Float(seconds)) * 1000)
                    } else {
                        mili = Int((timeElapsed) * 1000)
                    }
                    print("\(seconds) \(abs(mili))");
                    var frameRate = Int(Float(seconds) * self.fpsRate);
                    var displayString = String(frameRate);
                    if (abs(mili) < 250) {
                        displayString = displayString + " 1/4";
                    } else if (abs(mili) >= 250 && abs(mili) < 500) {
                        displayString = displayString + " 2/4";
                    } else if (abs(mili) >= 500 && abs(mili) < 750) {
                        displayString = displayString + " 3/4";
                    } else {
                        displayString = String((frameRate + 1))
                    }
                    self.frameRateLabel.text = displayString
                    self.second.text = self.stringFromTimeInterval(self.pop.timeIntervalSinceDate(self.whiteLight)) as String
                }
                
            }
        }
        previousDecible = currentDecible;
        
    }
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return frameRateSelection.count
    }
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String! {
        return frameRateSelection[row]
    }
    
    func stringFromTimeInterval(interval:NSTimeInterval) -> NSString {
        
        var ti = NSInteger(interval)
        
        var ms = Int((interval % 1) * 1000)
        
        var seconds = ti % 60
        
        return NSString(format: "%0.2d.%0.3d",abs(seconds),abs(ms))
    }
    
    func saveSettings() {
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(file);
            
            //writing
            do {
                try text.writeToFile(path, atomically: false, encoding: NSUTF8StringEncoding)
            }
            catch {/* error handling here */}
            
            //reading
            
        }
    }
    
    func loadSettings() {
        if let dir : NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let path = dir.stringByAppendingPathComponent(file);
        
            do {
                text = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding) as String
            } catch {
            
            }
        }
    }
    
   
    @IBAction func calculateDecible(sender: UIButton) {
        dispatch_async(dispatch_get_main_queue()) {
            if (self.isCalibrating) {
                var dbLevel = Int(round(20 * log10(5 * powf(10, (self.currentDecible/20)) * 160) + self.offset));
                self.text = self.calibrate.text!
                if (Float(self.calibrate.text!) != nil  && dbLevel != self.calibrate) {
                    self.offset = self.offset + Float(self.text)! - Float(dbLevel)
                }
                self.saveSettings();
            }
            self.decibleLevel.text = String(Int(round(20 * log10(5 * powf(10, (self.currentDecible/20)) * 160) + self.offset)));
        }
    }
    
    
}


