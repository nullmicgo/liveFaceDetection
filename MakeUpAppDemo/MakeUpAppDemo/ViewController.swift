//
//  ViewController.swift
//  MakeUpAppDemo
//
//  Created by michael on 19/1/2017.
//  Copyright © 2017 michael. All rights reserved.
//


import UIKit
import GLKit
import AVFoundation
import CoreMedia

class ViewController: UIViewController
{
    let eaglContext = EAGLContext(api: .openGLES2)
    let captureSession = AVCaptureSession()
    
    let imageView = GLKView()
    
    let comicEffect = CIFilter(name: "CIComicEffect")!
    let eyeballImage = CIImage(image: UIImage(named: "iwant.png")!)!
    
    var cameraImage: CIImage?
    
    lazy var ciContext: CIContext =
        {
            [unowned self] in
            
            return  CIContext(eaglContext: self.eaglContext!)
            }()
    
    lazy var detector: CIDetector =
        {
            [unowned self] in
            
            CIDetector(ofType: CIDetectorTypeFace,
                       context: self.ciContext,
                       options: [
                        CIDetectorAccuracy: CIDetectorAccuracyHigh,
                        CIDetectorTracking: true])
            }()!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        initialiseCaptureSession()
        
        view.addSubview(imageView)
        imageView.context = eaglContext!
        imageView.delegate = self
    }
    
    
    
    func initialiseCaptureSession()
    {
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        guard let frontCamera = (AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice])
            .filter({ $0.position == .front })
            .first else
        {
            fatalError("Unable to access front camera")
        }
        
        do
        {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.addInput(input)
        }
        catch
        {
            fatalError("Unable to access front camera")
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.startRunning()
    }
    
    /// Detects either the left or right eye from `cameraImage` and, if detected, composites
    /// `eyeballImage` over `backgroundImage`. If no eye is detected, simply returns the
    /// `backgroundImage`.
    func eyeImage(_ cameraImage: CIImage, backgroundImage: CIImage, leftEye: Bool) -> CIImage
    {
        let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
        let transformFilter = CIFilter(name: "CIAffineTransform")!
        
        let halfEyeWidth = eyeballImage.extent.width / 2
        let halfEyeHeight = eyeballImage.extent.height / 2
        
        if let features = detector.features(in: cameraImage).first as? CIFaceFeature, leftEye ? features.hasLeftEyePosition : features.hasRightEyePosition
        {
            let eyePosition = CGAffineTransform(
                translationX: leftEye ? features.leftEyePosition.x - halfEyeWidth : features.rightEyePosition.x - halfEyeWidth,
                y: leftEye ? features.leftEyePosition.y - halfEyeHeight : features.rightEyePosition.y - halfEyeHeight)
            
            transformFilter.setValue(eyeballImage, forKey: "inputImage")
            transformFilter.setValue(NSValue(cgAffineTransform: eyePosition), forKey: "inputTransform")
            let transformResult = transformFilter.value(forKey: "outputImage") as! CIImage
            
            compositingFilter.setValue(backgroundImage, forKey: kCIInputBackgroundImageKey)
            compositingFilter.setValue(transformResult, forKey: kCIInputImageKey)
            
            return  compositingFilter.value(forKey: "outputImage") as! CIImage
        }
        else
        {
            return backgroundImage
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        imageView.frame = view.bounds
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!)
    {
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        cameraImage = CIImage(cvPixelBuffer: pixelBuffer!)
        
        DispatchQueue.main.async
            {
                self.imageView.setNeedsDisplay()
        }
    }
}

extension ViewController: GLKViewDelegate
{
    func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        guard let cameraImage = cameraImage else
        {
            return
        }
        
        let leftEyeImage = eyeImage(cameraImage, backgroundImage: cameraImage, leftEye: true)
        let rightEyeImage = eyeImage(cameraImage, backgroundImage: leftEyeImage, leftEye: false)
        
        // comicEffect.setValue(rightEyeImage, forKey: kCIInputImageKey)
        
        let outputImage =  rightEyeImage// comicEffect.value(forKey: kCIOutputImageKey) as! CIImage
        
        ciContext.draw(outputImage,
                       in: CGRect(x: 0, y: 0,
                                  width: imageView.drawableWidth,
                                  height: imageView.drawableHeight),
                       from: outputImage.extent)
    }
}





