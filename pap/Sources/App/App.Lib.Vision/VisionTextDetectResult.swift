//
// Created by BLACKGENE on 2018-09-28.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation


protocol VisionTextDetectResult {
    var sourceVisionText: Any {set get}

    var plainText:String? {set get}

    var contacts:[VisionTextContactParser.OutputType]? {set get}

    var resultGroup: VisionTextResultGroup? {set get}
}
