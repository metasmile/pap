//
// Created by BLACKGENE on 22.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation

extension Array where Element==VisionTextBlock {
    func parse<ParserType: VisionTextParser>(parser: ParserType, _ async: AsyncWaitSignalable) -> [ParserType.OutputType]? {
        return self.compactMap { visionTextBlock -> ParserType.OutputType? in
            return parser.process(input: visionTextBlock)
        }.nilEmpty
    }

    func parse<ParserType:VisionTextParser>(type: ParserType.Type, _ async: AsyncWaitSignalable) -> [ParserType.OutputType]? {
        return self.parse(parser: type.init(), async)
    }
}
extension VisionTextBlock {
    func parse<ParserType:VisionTextParser>(parser:ParserType) -> ParserType.OutputType?{
        return parser.process(input: self)
    }
}
