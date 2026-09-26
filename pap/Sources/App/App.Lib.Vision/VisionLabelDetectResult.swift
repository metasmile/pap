//
// Created by BLACKGENE on 2018-11-30.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import Photos

protocol VisionLabelDetectResult {
    var sourceVisionLabels:[VisionImageLabel] {get}
}

struct VisionLabelPHAssetDetectResult: VisionLabelDetectResult, AppTaskResultable, Equatable, Hashable {
    let asset:PHAsset
    let sourceVisionLabels:[VisionImageLabel]
    let labelTextsConfidenceDescending:[String]

    init(asset:PHAsset, visionLabels:[VisionImageLabel]){
        self.asset = asset
        self.sourceVisionLabels = visionLabels
        self.labelTextsConfidenceDescending = visionLabels.sorted { l1, l2 in return (l1.confidence?.floatValue ?? 0) > (l2.confidence?.floatValue ?? 0) }.map { $0.text }
    }

    static func ==(lhs: VisionLabelPHAssetDetectResult, rhs: VisionLabelPHAssetDetectResult) -> Bool {
        return lhs.asset==rhs.asset
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(asset.hashValue)
    }

}

extension Array where Element==VisionLabelPHAssetDetectResult{

    var labelTextsConfidenceDescending:[String]{
        return map{ $0.sourceVisionLabels }.reduce([],+)
                .sorted { l1, l2 in return (l1.confidence?.floatValue ?? 0) > (l2.confidence?.floatValue ?? 0) }
                .map { $0.text }
                .uniq()
    }
}



