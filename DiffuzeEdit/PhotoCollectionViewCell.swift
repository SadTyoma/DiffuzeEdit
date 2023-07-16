//
//  PhotoCollectionViewCell.swift
//  term_project
//
//  Created by Artem Shuneyko on 24.11.22.
//

import UIKit
import Photos

class PhotoCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "photoCell"
    @IBOutlet weak var imageView: UIImageView!
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}

extension UIImageView {
    func fetchImageAssetWithCropping(_ asset: PHAsset?, targetSize size: CGSize, contentMode: PHImageContentMode = .aspectFill, options: PHImageRequestOptions? = nil, completionHandler: ((Bool) -> Void)?) {
        guard let asset = asset else {
            completionHandler?(false)
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        
        let resultHandler: (UIImage?, [AnyHashable: Any]?) -> Void = { [self] image, info in
            if let img = image{
                let croppedImage = cropImage(sourceImage: img)
                let scaledImage = croppedImage.scalePreservingAspectRatio(
                    targetSize: size
                )
                
                self.image = scaledImage
                completionHandler?(true)
            }
        }
        let imageSize = CGSize(width: size.width * 2, height: size.width * 2)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: imageSize,
            contentMode: contentMode,
            options: options,
            resultHandler: resultHandler)
    }
    
    private func cropImage(sourceImage:UIImage)->UIImage{
        let sideLength = min(
            sourceImage.size.width,
            sourceImage.size.height
        )
        
        let sourceSize = sourceImage.size
        let xOffset = (sourceSize.width - sideLength) / 2.0
        let yOffset = (sourceSize.height - sideLength) / 2.0
        
        let cropRect = CGRect(
            x: xOffset,
            y: yOffset,
            width: sideLength,
            height: sideLength
        ).integral
        
        let sourceCGImage = sourceImage.cgImage!
        let croppedCGImage = sourceCGImage.cropping(
            to: cropRect
        )!
        
        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: sourceImage.imageRendererFormat.scale,
            orientation: sourceImage.imageOrientation
        )
        
        return croppedImage
    }
}

