//
//  Scan.swift
//  2Q2R
//
//  Created by Sam Claus on 8/23/16.
//  Copyright © 2016 Tera Insights, LLC. All rights reserved.
//

import AVFoundation
import UIKit
import CoreGraphics

class Scan: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var shouldReceiveInput: Bool = true
    
    @IBOutlet weak var scanFrame: UIView!
    @IBOutlet weak var scanLabel: UIView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        scanFrame.layer.borderWidth = 3
        scanFrame.layer.borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.6).cgColor
        
        // Initialize the camera
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
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
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        // Start camera preview
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer!)
        view.bringSubview(toFront: scanFrame)
        view.bringSubview(toFront: scanLabel)
        
        // Begin video capture
        captureSession?.startRunning()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        shouldReceiveInput = true
        captureSession?.startRunning()
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        captureSession?.stopRunning()
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if !shouldReceiveInput {
            return
        }
        
        if metadataObjects != nil && metadataObjects.count != 0 {
            
            let metadata = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            if metadata.type == AVMetadataObjectTypeQRCode {
                
                if let message = metadata.stringValue {
                    
                    shouldReceiveInput = false
                    navigationController?.popViewController(animated: true)
                    process2Q2RRequest(message)?.execute()
                    
                }
                
            }
            
        }
        
    }
    
}

















