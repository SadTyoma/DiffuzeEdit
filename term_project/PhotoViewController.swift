//
//  PhotoViewController.swift
//  term_project
//
//  Created by Artem Shuneyko on 24.11.22.
//

import UIKit
import Photos

class PhotoViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var clearAllButton: UIBarButtonItem!
    @IBOutlet weak var photoView: UIImageViewForDrawing!
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var lineSizeSlider: UISlider!
    
    private var asset: PHAsset
    private let url = "http://api.proposer.ai:3000/inpaint"
    private var resultImage: UIImage?{
        didSet{
            guard let resultImage = resultImage else {
                return
            }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.performSegue(withIdentifier: "ToResultImage", sender: resultImage)
            }
        }
    }
    
    public var currentColor: UIColor = .black
    public var lineSize = 10.0
    public var imageArray = [UIImage?]()
    public var maskArray = [UIImage?]()
    
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
        
        if maskArray.isEmpty{
            let size = CGSize(width: photoView.bounds.width, height: photoView.bounds.height)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: CGPoint.zero, size: size))
            let whiteImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            maskArray.append(whiteImage)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = .large
        activityIndicator.color = .gray
        
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
            
            self.uploadImage(text: text)
        }))
        
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ToResultImage" {
            let destinationVC = segue.destination as! ResultImageViewController
            destinationVC.resultImage = sender as? UIImage
        }
    }
    
    func uploadImage(text: String) {
        activityIndicator.startAnimating()

        let image = getImageWithoutBorders(image: imageArray.first!!)!
        let mask = getImageWithoutBorders(image: self.maskArray.last!!)!
        let imageData = image.jpegData(compressionQuality: 1.0)!
        let maskData = mask.jpegData(compressionQuality: 1.0)!
        
        let resultURL = url.appending("?prompt=\(text)")
        let url = URL(string: resultURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mask\"; filename=\"mask.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(maskData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                print("Invalid response")
                return
            }
            
            if (200...299).contains(response.statusCode) {
                if let data = data {
                    self.resultImage = UIImage(data: data)
                }
                print("Images uploaded successfully")
            } else if response.statusCode == 422 {
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let detail = json["detail"] as? [[String: Any]], let errorMessage = detail.first?["msg"] as? String {
                    print("Validation error: \(errorMessage)")
                } else {
                    print("Error parsing JSON")
                }
            }else {
                print("Error uploading images: \(response.statusCode)")
            }
        }
        
        task.resume()
    }
    
    private func getImageWithoutBorders(image: UIImage)->UIImage?{
        guard let imageSize = photoView.imageSize, let imageOrigin = photoView.imageOrigin  else {return nil}
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0.0)
        image.draw(at: CGPoint(x: -imageOrigin.x, y: -imageOrigin.y))
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
