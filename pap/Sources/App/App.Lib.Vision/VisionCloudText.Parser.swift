//
// Created by BLACKGENE on 20.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation


extension VisionText{
    func parseToString() -> String?{
        return VisionCloudTextParser.default.process(input: self)
    }
}

struct VisionCloudTextParser: Processor {
    typealias InputType = VisionText
    typealias OutputType = String

    static let `default` = VisionCloudTextParser()

    func process(input: VisionText) -> String? {
        var testResults:String = ""

        for block in input.blocks {
            for line in block.lines {
                for element in line.elements {
                    testResults += element.text + " "
                }
            }
        }

        return testResults
    }
}
