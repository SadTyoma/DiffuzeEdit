//
//  UIImageViewForDrawing.swift
//  term_project
//
//  Created by Artem Shuneyko on 24.11.22.
//

import UIKit
import Photos

class UIImageViewForDrawing: UIImageView {
    private var drawingQueue = DispatchQueue(label: "com.termproject.drawing")
    private var lastImage: UIImage?
    private var pts = [CGPoint](repeating: CGPoint.zero, count: 5)
    private var ctr = 0
    private var pointsBuffer = [CGPoint](repeating: CGPoint.zero, count: Constants.CAPACITY)
    private var bufIdx = 0
    private var isFirstTouchPoint = false
    private var lastSegmentOfPrev: LineSegment?
    private var fullPath = UIBezierPath()
    private var points = [CGPoint]()
    
    public var phVC: PhotoViewController?
    private var photoVC: PhotoViewController{ get{ return phVC! } }
    
    public var incrementalImage: UIImage?
    public var imageSize: CGSize?
    public var imageOrigin: CGPoint?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let location = (touch?.location(in: self))!
        
        ctr = 0
        bufIdx = 0
        pts[0] = location
        isFirstTouchPoint = true
        lastImage = image
        fullPath = UIBezierPath()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let p = touch?.location(in: self)
        points.append(p!)
        ctr += 1
        pts[ctr] = p!
        if ctr == 4 {
            pts[3] = CGPoint(x: (pts[2].x + pts[4].x) / 2.0, y: (pts[2].y + pts[4].y) / 2.0)
            
            for i in 0..<4 {
                pointsBuffer[bufIdx + i] = pts[i]
            }
            
            bufIdx += 4
            
            let bounds = self.bounds
            
            drawingQueue.async{ [self] in
                let offsetPath = UIBezierPath()
                if bufIdx == 0 {
                    return
                }
                
                var ls = [LineSegment](repeating: LineSegment(firstPoint: CGPoint.zero, secondPoint: CGPoint.zero), count: 4)
                var i = 0
                while i < bufIdx {
                    if isFirstTouchPoint {
                        ls[0] = LineSegment(firstPoint: pointsBuffer[0], secondPoint: pointsBuffer[0])
                        offsetPath.move(to: ls[0].firstPoint)
                        isFirstTouchPoint = false
                    } else {
                        if let lastSegmentOfPrev = lastSegmentOfPrev {
                            ls[0] = lastSegmentOfPrev
                        }
                    }
                    
                    let frac1: Double = Constants.FF / clamp(len_sq(pointsBuffer[i], pointsBuffer[i + 1]), Constants.LOWER, Constants.UPPER)
                    let frac2: Double = Constants.FF / clamp(len_sq(pointsBuffer[i + 1], pointsBuffer[i + 2]), Constants.LOWER, Constants.UPPER)
                    let frac3: Double = Constants.FF / clamp(len_sq(pointsBuffer[i + 2], pointsBuffer[i + 3]), Constants.LOWER, Constants.UPPER)
                    ls[1] = lineSegmentPerpendicular(to: LineSegment(firstPoint: pointsBuffer[i], secondPoint: pointsBuffer[i + 1]), ofRelativeLength: frac1)
                    ls[2] = lineSegmentPerpendicular(to: LineSegment(firstPoint: pointsBuffer[i + 1], secondPoint: pointsBuffer[i + 2]), ofRelativeLength: frac2)
                    ls[3] = lineSegmentPerpendicular(to: LineSegment(firstPoint: pointsBuffer[i + 2], secondPoint: pointsBuffer[i + 3]), ofRelativeLength: frac3)
                    
                    offsetPath.move(to: ls[0].firstPoint)
                    
                    offsetPath.addCurve(to: ls[3].firstPoint, controlPoint1: ls[1].firstPoint, controlPoint2: ls[2].firstPoint)
                    
                    offsetPath.addLine(to: ls[3].secondPoint)
                    
                    offsetPath.addCurve(to: ls[0].secondPoint, controlPoint1: ls[2].secondPoint, controlPoint2: ls[1].secondPoint)
                    
                    offsetPath.close()
                    
                    lastSegmentOfPrev = ls[3]
                    i += 4
                }
                UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0.0)
                if incrementalImage == nil{
                    lastImage!.draw(in: CGRect(origin: .zero, size: bounds.size))
                }
                if let incrementalImage = incrementalImage {
                    incrementalImage.draw(at: .zero)
                    photoVC.currentColor.setStroke()
                    photoVC.currentColor.setFill()
                    offsetPath.lineWidth = photoVC.lineSize
                    offsetPath.stroke()
                    offsetPath.fill()
                }
                
                self.incrementalImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                let copy = offsetPath.copy()
                fullPath.append(copy as! UIBezierPath)
                offsetPath.removeAllPoints()
                DispatchQueue.main.async(execute: { [self] in
                    photoVC.drawImage(incrementalImage)
                    bufIdx = 0
                    self.setNeedsDisplay()
                })
            }
            pts[0] = pts[3]
            pts[1] = pts[4]
            ctr = 1
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fullPath.close()
        
        let newImage = drawLine()
        incrementalImage = newImage
        points = [CGPoint]()
        fullPath.removeAllPoints()
        
        self.image = newImage
        self.setNeedsDisplay()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchesEnded(touches, with: event)
    }
    
    public func lineSegmentPerpendicular(to pp: LineSegment, ofRelativeLength fraction: Double) -> LineSegment {
        let x0 = pp.firstPoint.x
        let y0 = pp.firstPoint.y
        let x1 = pp.secondPoint.x
        let y1 = pp.secondPoint.y
        
        var dx: CGFloat
        var dy: CGFloat
        dx = x1 - x0
        dy = y1 - y0
        
        var xa: CGFloat
        var ya: CGFloat
        var xb: CGFloat
        var yb: CGFloat
        xa = x1 + CGFloat(fraction / 2) * dy
        ya = y1 - CGFloat(fraction / 2) * dx
        xb = x1 - CGFloat(fraction / 2) * dy
        yb = y1 + CGFloat(fraction / 2) * dx
        
        return LineSegment(firstPoint: CGPoint(x: xa, y: ya), secondPoint: CGPoint(x: xb, y: yb))
        
    }
    
    private func len_sq(_ p1: CGPoint,_ p2: CGPoint)->Double{
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        return dx * dx + dy * dy
    }
    
    private func clamp(_ value: Double,_ lower: Double,_ higher: Double)->Double{
        if value < lower{
            return lower
        }
        if value > higher{
            return higher
        }
        return value
    }
    
    private func drawLine()->UIImage?{
        let bounds = self.bounds
        guard let image = lastImage else {return nil}
        UIGraphicsBeginImageContextWithOptions(bounds.size, true, 0.0)
        image.draw(in: CGRect(origin: .zero, size: bounds.size))
        var incImage = UIGraphicsGetImageFromCurrentImageContext()
        
        incImage!.draw(at: .zero)
        photoVC.currentColor.setStroke()
        photoVC.currentColor.setFill()
        fullPath.lineWidth = photoVC.lineSize
        fullPath.stroke()
        fullPath.fill()
        incImage = UIGraphicsGetImageFromCurrentImageContext()
        
        image.draw(in: CGRect(origin: .zero, size: bounds.size))
        incImage!.draw(in: CGRect(origin: .zero, size: bounds.size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        photoVC.addToImageArray(newImage)
        
        return newImage
    }
}

extension UIImageViewForDrawing{
    func fetchImageAsset(_ asset: PHAsset?, targetSize size: CGSize, contentMode: PHImageContentMode = .aspectFill, options: PHImageRequestOptions? = nil, completionHandler: ((Bool) -> Void)?) {
        guard let asset = asset else {
            completionHandler?(false)
            return
        }
        let resultHandler: (UIImage?, [AnyHashable: Any]?) -> Void = { image, info in
            self.contentMode = .scaleAspectFill

            guard let img = image else{
                self.image = image
                completionHandler?(true)
                return
            }
            
            let viewportAspectRatio = self.bounds.size.width / self.bounds.size.height
            let imageAspectRatio = img.size.width / img.size.height
            
            var coeff = CGFloat(1.0)
            if viewportAspectRatio > imageAspectRatio { // viewport is wider
                coeff = self.bounds.size.height / img.size.height
            } else { // viewport is taller
                coeff = self.bounds.size.width / img.size.width
            }
            let resultSize = CGSize(width: img.size.width * coeff, height: img.size.height * coeff)
            self.imageSize = resultSize
            
            UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, 0.0)
            let origin = CGPoint(x: (self.bounds.size.width - resultSize.width) / 2,
                                y: (self.bounds.size.height - resultSize.height) / 2)
            self.imageOrigin = origin
            img.draw(in: CGRect(origin: origin, size: resultSize))
            let incImage = UIGraphicsGetImageFromCurrentImageContext()
            self.image = incImage
            completionHandler?(true)
        }
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: contentMode,
            options: options,
            resultHandler: resultHandler)
    }
}

struct LineSegment{
    var firstPoint: CGPoint
    var secondPoint: CGPoint
}

