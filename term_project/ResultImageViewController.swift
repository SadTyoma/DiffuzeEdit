//
//  ResultImageViewController.swift
//  term_project
//
//  Created by Artem Shuneyko on 30.01.23.
//

import UIKit

class ResultImageViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
        
    public var resultImage: UIImage?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = resultImage
    }
    
    @IBAction func downloadTapped(_ sender: Any) {
        guard let selectedImage = imageView.image else {
            print("Image not found!")
            return
        }
        UIImageWriteToSavedPhotosAlbum(selectedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showAlertWith(title: "Save error", message: error.localizedDescription)
        } else {
            showAlertWith(title: "Saved!", message: "Your image has been saved to your photos.")
        }
    }
    
    func showAlertWith(title: String, message: String){
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }
}
