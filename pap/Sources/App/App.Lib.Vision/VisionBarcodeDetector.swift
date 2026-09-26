//
//  VisionBarcodeDetector.swift
//  pap
//
//  Created by HYOJIN MO on 2018. 10. 1..
//  Copyright © 2018년 Stells. All rights reserved.
//

import Foundation
import UIKit

protocol VisionItem {
    var cornerPoints: [NSValue]? { get }
    var frame: CGRect { get }
    var text: String { get }
}

extension VisionTextBlock: VisionItem {}

class VisionBarcodeText: VisionItem {
    var visionBarcode: VisionBarcode

    init(visionBarcode: VisionBarcode) {
        self.visionBarcode = visionBarcode
    }

    var cornerPoints: [NSValue]? {
        return visionBarcode.cornerPoints
    }

    var frame: CGRect {
        return visionBarcode.frame
    }

    var text: String {
        return visionBarcode.rawValue ?? ""
    }
}

extension VisionBarcodeDetector{

    func detect(with image: UIImage, _ async: AsyncWaitSignalable) -> [VisionBarcodeText]? {
        let visionImage = VisionImage(image: image)
        var result:[VisionBarcodeText]?

        async.begin()
        self.detect(in: visionImage) { (features, error) in
            if let error = error {
                print("Received error: \(error)")
            }
            result = features?.map { VisionBarcodeText(visionBarcode: $0) }
            async.end()
        }
        async.waitUntilEnd()
        return result
    }
}
