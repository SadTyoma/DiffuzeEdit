//
//  PhotoViewController.swift
//  term_project
//
//  Created by Artem Shuneyko on 24.11.22.
//

import UIKit
import Photos

class PhotoViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var clearAllButton: UIBarButtonItem!
    @IBOutlet weak var photoView: UIImageViewForDrawing!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var lineSizeSlider: UISlider!
    
    private var asset: PHAsset
    private let url = "http://127.0.0.1:1324/api/v1/imageanalysis"
    
    public var currentColor: UIColor = .black
    public var lineSize = 10.0
    public var imageArray = [UIImage?]()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    init?(asset: PHAsset, coder: NSCoder) {
        self.asset = asset
        super.init(coder: coder)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        if imageArray.isEmpty{
            imageArray.append(photoView.image)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.photoView.phVC = self
        self.photoView.isUserInteractionEnabled = true
        getPhoto()
        
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true

        PHPhotoLibrary.shared().register(self)
        
        updateUndoButton()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    @IBAction func clearAllClicked(_ sender: Any) {
        photoView.image = imageArray.first!
        photoView.incrementalImage = imageArray.first!
        imageArray.removeSubrange(1...imageArray.count - 1)
        updateUndoButton()
    }
    
    @IBAction func undoClicked(_ sender: Any) {
        if imageArray.count > 1{
            imageArray.removeLast()
            updateUndoButton()
            photoView.image = imageArray.last!
            photoView.incrementalImage = imageArray.last!
        }
    }
    
    private func updateUndoButton() {
        let flag = imageArray.count > 1
        undoButton.isEnabled = flag
        undoButton.tintColor = flag ? .white : .lightGray
    }
    
    @IBAction func lineSizeChanged(_ sender: Any) {
        lineSize = Double(lineSizeSlider.value)
    }
    @IBAction func nextStepClicked(_ sender: Any) {
        showAlert()
    }
    @objc func saveButtonClicked(){
        askSaveType()
    }
    
    func showAlert(){
        let alert = UIAlertController(title: "", message: "What you want on image", preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: {field in
            field.placeholder = "Text"
            field.returnKeyType = .continue
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: {_ in
            guard let fields = alert.textFields, fields.count == 1 else {
                return
            }
            guard let text = fields[0].text, !text.isEmpty else{
                return
            }
            
            //self.uploadImage(text: text, image: self.photoView.image!)
            self.performSegue(withIdentifier: "ToResultImage", sender: nil)
        }))
        
        present(alert, animated: true)
    }
    
    func uploadImage(text: String, image: UIImage) {
            let url = URL(string: url)
            let boundary = UUID().uuidString

            let session = URLSession.shared

            var urlRequest = URLRequest(url: url!)
            urlRequest.httpMethod = "POST"

            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var data = Data()
            
            // Add the image data to the raw http request data
            data.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
            let paramName = "text"
            data.append("Content-Disposition: form-data; name=\"\(paramName)\"; filename=\"\(text)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            data.append(image.pngData()!)
            
            data.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            session.uploadTask(with: urlRequest, from: data, completionHandler: { responseData, response, error in
                    if error == nil {
                        let jsonData = try? JSONSerialization.jsonObject(with: responseData!, options: .allowFragments)
                        if let json = jsonData as? [String: Any] {
                            print(json)
                        }
                    }
                }).resume()
        }
    
    private func askSaveType(){
        let refreshAlert = UIAlertController(title: "Save Type", message: "Save image without borders?", preferredStyle: UIAlertController.Style.alert)

        refreshAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction!) in
            let image = self.getImageWithoutBorders()
            if let image = image{
                UIImageWriteToSavedPhotosAlbum(image, self, nil, nil)
            }
        }))

        refreshAlert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { (action: UIAlertAction!) in
            let image = self.imageArray.last!
            if let image = image{
                UIImageWriteToSavedPhotosAlbum(image, self, nil, nil)
            }
        }))

        present(refreshAlert, animated: true, completion: nil)
    }
    
    private func getImageWithoutBorders()->UIImage?{
        guard let imageSize = photoView.imageSize, let imageOrigin = photoView.imageOrigin  else {return nil}
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0.0)
        photoView.image!.draw(at: CGPoint(x: -imageOrigin.x, y: -imageOrigin.y))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        
        return newImage
    }
    
    private func getPhoto() {
        photoView.fetchImageAsset(asset, targetSize: photoView.bounds.size, completionHandler: nil)
    }
    
    public func addToImageArray(_ image:UIImage?){
        imageArray.append(image)
        updateUndoButton()
    }
    
    public func drawImage(_ incrementalImage:UIImage?){
        if let incrementalImage = incrementalImage, let image = self.photoView.image{
            let size = image.size
            UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
            image.draw(in: CGRect(origin: .zero, size: size))
            incrementalImage.draw(in: CGRect(origin: .zero, size: size))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self.photoView.image = newImage
        }
    }
}

extension PhotoViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            let lastImage = imageArray.last!
            imageArray.removeAll()
            imageArray.append(lastImage)
            
            updateUndoButton()
        }
    }
}
