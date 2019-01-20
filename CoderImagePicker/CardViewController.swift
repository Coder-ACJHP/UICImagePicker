//
//  CardViewController.swift
//  CoderImagePicker
//
//  Created by Onur Işık on 19.01.2019.
//  Copyright © 2019 Onur Işık. All rights reserved.
//

import UIKit
import PhotosUI
import AVFoundation

protocol CImagePickerControllerDelegate: class {
    
    func didFinishPickingImage(_ image: UIImage)
    func didCancelPickingImage()
}

class CardViewController: UIViewController {
    
    @IBOutlet weak var handleArea: UIView!
    @IBOutlet weak var miniSeperator: UIView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var previewImgViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var cameraToolView: UIView!
    
    var delegate: CImagePickerControllerDelegate?
    
    var cameraIsRunning: Bool = false
    var firstFetchedImage: UIImage?
    var lastSelectedImage: UIImage?
    var lastIndexPath: IndexPath?
    var assetsList = PHFetchResult<PHAsset>()
    let options = PHImageRequestOptions()
    let cellIdentifier: String = "photoCell"
    let firstIndex: IndexPath = IndexPath(item: 0, section: 0)
    typealias fetchCompletionHandler = (_ success: Bool) -> Void
    
    
    enum CameraState: CGFloat {
        case collapsed = 220
        case expanded = 623
    }
    var session: AVCaptureSession?
    var captureDevice: AVCaptureDevice?
    var stillImageOutput: AVCapturePhotoOutput?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        
        self.setupView()
    }
    
    fileprivate func setupView() {
        
        collectionView.register(UINib(nibName: "PhotoCell", bundle: nil), forCellWithReuseIdentifier: cellIdentifier)
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        let contentFlowLayout: ContentDynamicLayout = InstagramStyleFlowLayout()
        
        contentFlowLayout.delegate = self
        contentFlowLayout.contentPadding = ItemsPadding(horizontal: 0, vertical: 2)
        contentFlowLayout.cellsPadding = ItemsPadding(horizontal: 2, vertical: 2)
        contentFlowLayout.contentAlign = .left
        
        self.collectionView.collectionViewLayout = contentFlowLayout
        
        // Adjust fetch options before fetch op.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        fetchImagesFromLibrary { (isCompleted) in
            
            if isCompleted {
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        }
        
        miniSeperator.layer.cornerRadius = 4
        miniSeperator.layer.masksToBounds = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    fileprivate func fetchImagesFromLibrary(completionHandler: @escaping fetchCompletionHandler) {
        
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                let fetchOptions = PHFetchOptions()
                self.assetsList = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                
                // Fetch first image as high quality to assign it to preview image view.
                PHImageManager.default().requestImage(for: self.assetsList.firstObject!,
                                        targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit,
                                                      options: self.options, resultHandler: { (resultImage, info) in
                    self.firstFetchedImage = resultImage
                    self.previewImageView.image = self.firstFetchedImage
                })
                completionHandler(true)
                
            case .denied, .restricted:
                completionHandler(false)
                
            case .notDetermined:
                completionHandler(false)
            }
        }
    }
    
    func createAndConfigureCellFor(indexPath: IndexPath) -> PhotoCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCell
        
        // Fetch images as thumbnail to avoid bad performance
        let cellOriginSize = cell.frame.size
        let customSize = CGSize(width: cellOriginSize.width * 2, height: cellOriginSize.height * 2)

        PHImageManager.default().requestImage(for: assetsList[indexPath.item], targetSize: customSize, contentMode: .aspectFit, options: options) { (resultImage, info) in
            if resultImage != nil {
                cell.imageView.image = resultImage
            }
        }
        
        return cell
    }
    
    fileprivate func prepareViewToCamera(withPosition: AVCaptureDevice.Position) {
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
            
            self.miniSeperator.isHidden = true
            self.collectionView.isHidden = true
            self.previewImgViewHeightConstraint.constant = CameraState.expanded.rawValue
            self.cameraToolView.isHidden = false
            self.view.bringSubviewToFront(self.cameraToolView)
            
        }) { (_) in
            self.startCamera(withPosition: withPosition)
        }
    }
    
    fileprivate func normalizeView() {
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
            
            self.previewImgViewHeightConstraint.constant = CameraState.collapsed.rawValue
            self.miniSeperator.isHidden = false
            self.collectionView.isHidden = false
            self.cameraToolView.isHidden = true
            
        }) { (_) in
            self.stopCamera()
        }
    }
    
    fileprivate func startCamera(withPosition: AVCaptureDevice.Position) {
        
        session = AVCaptureSession()
        session!.sessionPreset = AVCaptureSession.Preset.photo
        self.captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: withPosition)
        
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: self.captureDevice!)
            stillImageOutput = AVCapturePhotoOutput()
            
            if session!.canAddInput(input) && session!.canAddOutput(stillImageOutput!) {
                
                session!.addInput(input)
                session!.addOutput(stillImageOutput!)
                
                videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session!)
                videoPreviewLayer!.name = "liveCamera"
                videoPreviewLayer!.videoGravity = .resizeAspect
                videoPreviewLayer!.connection?.videoOrientation = .portrait
                previewImageView.layer.addSublayer(videoPreviewLayer!)
                
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session!.startRunning()
                    self.cameraIsRunning = true
                    
                    DispatchQueue.main.async {
                        self.videoPreviewLayer!.frame = self.previewImageView.bounds
                    }
                }
            }
            
        } catch let error {
            input = nil
            print(error.localizedDescription)
        }
    }
    
    fileprivate func stopCamera() {
        
        self.previewImageView.layer.sublayers!.forEach { (videolayer) in
            if videolayer.name == "liveCamera" {
                videolayer.removeFromSuperlayer()
            }
        }
        self.previewImageView.image = lastSelectedImage
        session?.stopRunning()
        cameraIsRunning = false
        session = nil
        stillImageOutput = nil
        videoPreviewLayer = nil
    }
    
    fileprivate func deinitCollectionView() {
        
        if cameraIsRunning {
            stopCamera()
        }
        
        if lastIndexPath != nil {
            collectionView.deselectItem(at: lastIndexPath!, animated: true)
        }
        
        self.previewImageView.image = self.firstFetchedImage
        collectionView.scrollToItem(at: firstIndex, at: .top, animated: false)
        
    }
    
    @IBAction fileprivate func buttonActions(_ sender: UIButton) {
        
        switch sender.tag {
        case 0:
            // open camrea
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                prepareViewToCamera(withPosition: .back)
            } else { print("Sorry cant take picture") }
            
        case 1:
            // Done
            delegate?.didFinishPickingImage(previewImageView.image!)
            deinitCollectionView()
            
        case 2:
            // capture image
            let settings = AVCapturePhotoSettings()
            let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
            let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                                 kCVPixelBufferWidthKey as String: 160,
                                 kCVPixelBufferHeightKey as String: 160]
            settings.previewPhotoFormat = previewFormat
            settings.flashMode = .auto
            stillImageOutput?.capturePhoto(with: settings, delegate: self)
            
        case 3:
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                startCamera(withPosition: .front)
            } else { print("Sorry cant take picture") }
            
        case 4:
            normalizeView()
            // cancel camera
        case 5:
            delegate?.didCancelPickingImage()
            deinitCollectionView()
            
        default: break;
        }
    }
}

extension CardViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assetsList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        return createAndConfigureCellFor(indexPath: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        PHImageManager.default().requestImage(for: assetsList[indexPath.item], targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { (resultImage, info) in
            if resultImage != nil {
                self.previewImageView.image = resultImage
                self.lastSelectedImage = resultImage
            }
        }
        
        self.lastIndexPath = indexPath
        collectionView.scrollToItem(at: self.lastIndexPath!, at: .centeredVertically, animated: true)
    }

}

extension CardViewController: ContentDynamicLayoutDelegate {
    
    func cellSize(indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
}

extension CardViewController: AVCapturePhotoCaptureDelegate {
    
    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        let capturedImage = UIImage(data: imageData)
        previewImageView.image = capturedImage
        lastSelectedImage = capturedImage
    }
    
    @available(iOS 10.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        }
        
        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            let capturedImage = UIImage(data: dataImage)
            previewImageView.image = capturedImage
            lastSelectedImage = capturedImage
        }
    }
}
