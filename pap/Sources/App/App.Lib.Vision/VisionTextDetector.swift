//
// Created by BLACKGENE on 2?0.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit

extension VisionTextRecognizer {

    func detect(with image: UIImage, _ async: AsyncWaitSignalable) -> VisionText? {
        let visionImage = VisionImage(image: image)
        var result:VisionText?

        async.begin()
        self.process(visionImage) { features, error in
            if let error = error {
                print("Received error: \(error)")
            }
            result = features
            async.end()
        }
        async.waitUntilEnd()
        
        return result
    }
}
