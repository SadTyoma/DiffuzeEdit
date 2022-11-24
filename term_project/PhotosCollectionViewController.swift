//
//  PhotosCollectionViewController.swift
//  term_project
//
//  Created by Artem Shuneyko on 24.11.22.
//

import UIKit
import Photos

class PhotosCollectionViewController: UICollectionViewController {
    private var assets: PHFetchResult<PHAsset>
    private var imagesInRow = 3.0
    private let step = 2.0
    private let minImagesInRow = 1.0
    private let maxImagesInRow = 5.0
    private var gesture: UIPinchGestureRecognizer?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented.")
    }
    
    init?(assets: PHFetchResult<PHAsset>, title: String, coder: NSCoder) {
        self.assets = assets
        super.init(coder: coder)
        self.title = title
        self.navigationItem.setHidesBackButton(true, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PHPhotoLibrary.shared().register(self)
        
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        
        gesture = UIPinchGestureRecognizer(target: self, action: #selector(didReceivePinchGesture(_:)))
        if let gesture = self.gesture {
            collectionView.addGestureRecognizer(gesture)
        }
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    @IBSegueAction func makePhotoViewController(_ coder: NSCoder) -> PhotoViewController? {
        guard let selectedIndexPath = collectionView.indexPathsForSelectedItems?.first else { return nil }
        return PhotoViewController(asset: assets[selectedIndexPath.item], coder: coder)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCollectionViewCell.reuseIdentifier,
            for: indexPath) as? PhotoCollectionViewCell else {
            fatalError("Unable to dequeue PhotoCollectionViewCell")
        }
        let asset = assets[indexPath.item]
        let cellSize = cellSizeCalculation()
        cell.imageView.fetchImageAssetWithCropping(asset, targetSize: cellSize, completionHandler: nil)
        
        return cell
    }
    
    private func cellSizeCalculation()->CGSize{
        let viewSize = self.collectionView.frame.size.width
        let totalSpacingSize = 2 * (imagesInRow - 1)
        let fittedWidth = (viewSize - totalSpacingSize) / imagesInRow
        
        return CGSize(width: fittedWidth, height: fittedWidth)
    }

    @objc func didReceivePinchGesture(_ gesture: UIPinchGestureRecognizer){
        if (gesture.state == .changed)
        {
            if gesture.scale < 1{
                imagesInRow += step
            }else{
                imagesInRow -= step
            }
            
            if imagesInRow < minImagesInRow{
                imagesInRow = minImagesInRow
            }else if imagesInRow > maxImagesInRow{
                imagesInRow = maxImagesInRow
            }
            
            self.collectionView.removeGestureRecognizer(self.gesture!)
            let newLayout = UICollectionViewFlowLayout()
            self.collectionView.setCollectionViewLayout(newLayout, animated: true) { finished in
                self.collectionView.addGestureRecognizer(self.gesture!)
            }
            if let indexPaths = collectionView?.indexPathsForVisibleItems {
                collectionView?.reconfigureItems(at: indexPaths)
            }
        }
    }
}

extension PhotosCollectionViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let change = changeInstance.changeDetails(for: assets) else {
            return
        }
        DispatchQueue.main.sync {
            assets = change.fetchResultAfterChanges
            collectionView.reloadData()
        }
    }
}

extension PhotosCollectionViewController : UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSizeCalculation()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
