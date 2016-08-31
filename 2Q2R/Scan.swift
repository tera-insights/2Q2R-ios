//
//  Scan.swift
//  2Q2R
//
//  Created by Sam Claus on 8/23/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import AVFoundation
import UIKit

class Scan: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var shouldReceiveInput: Bool = true
    
    @IBOutlet weak var scanLabel: UIView!
    @IBOutlet weak var label: UIView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Initialize the camera
        let captureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        do {
            
            let input: AnyObject! = try AVCaptureDeviceInput(device: captureDevice)
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input as! AVCaptureInput)
            
        } catch let error {
            
            print(error)
            return
            
        }
        
        // Describe what codes should be captured
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession?.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        // Start camera preview
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer!)
        view.bringSubviewToFront(scanLabel)
        
        // Begin video capture
        captureSession?.startRunning()
        
    }
    
    override func viewDidAppear(animated: Bool) {
        
        shouldReceiveInput = true
        captureSession?.startRunning()
        
    }
    
    override func viewDidDisappear(animated: Bool) {
        
        captureSession?.stopRunning()
        
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        
        if !shouldReceiveInput {
            return
        }
        
        if metadataObjects != nil && metadataObjects.count != 0 {
            
            let metadata = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            if metadata.type == AVMetadataObjectTypeQRCode {
                
                if let message = metadata.stringValue {
                    
                    shouldReceiveInput = false
                    navigationController?.popViewControllerAnimated(true)
                    processU2F(message: message)
                    
                }
                
            }
            
        }
        
    }
    
}

















