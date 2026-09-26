//
// Created by BLACKGENE on 20.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation

/*
INFO:

'OutputType' must be Foundation supported type in this swift file.
For other ones, use instead ./VisionText.Parser.Types
*/

protocol VisionTextParser: Processor where Self.InputType==VisionTextBlock {
    func process(input:VisionTextBlock) -> OutputType?
}

struct VisionTextStringParser: VisionTextParser {
    typealias OutputType = String

    static let shared = VisionTextStringParser()

    private let blockParser = VisionTextTextBlockParser()

    func process(input: VisionTextBlock) -> OutputType? {
        guard let lines = blockParser.process(input: input) else {
            return nil
        }

        var results:String = ""

        for line in lines{
            var wordsInLine = ""

            for word in line {
                wordsInLine += word + " "
            }

            if wordsInLine.count > 0{
                results += "\n" + wordsInLine
            }
        }

        if results.count > 0{
            return results + "\n"
        }

        return nil
    }
}

public struct VisionTextStringElementsParser: VisionTextParser {
    typealias OutputType = [String]

    static let shared = VisionTextStringElementsParser()

    private let blockParser = VisionTextTextBlockParser()

    func process(input: VisionTextBlock) -> OutputType? {
        return blockParser.process(input: input)?.compactMap { strings -> String? in
            return strings.joined()
        }
    }
}

public struct VisionTextTextBlockParser: VisionTextParser {
    typealias OutputType = [[String]]

    static let shared = VisionTextTextBlockParser()

    let parser = VisionTextElementParser()

    func process(input: VisionTextBlock) -> OutputType? {
        if let results = parser.process(input: input){
            var linesInBlock = [[String]]()

            //block
            for line in results {
                //line
                var wordsInLine = [String]()
                for element in line where element.text.count > 0 {
                    //word
                    wordsInLine.append(element.text)
                }

                if wordsInLine.count > 0{
                    linesInBlock.append(wordsInLine)
                }
            }

            return linesInBlock
        }

        return nil
    }
}

public struct VisionTextElementParser: VisionTextParser {
    typealias OutputType = [[VisionTextElement]]

    static let shared = VisionTextTextBlockParser()

    func process(input: VisionTextBlock) -> OutputType? {
        var linesInBlock = [[VisionTextElement]]()
        
        //block
        for line in input.lines {
            //line
            var wordsInLine = [VisionTextElement]()
            for element in line.elements where element.text.count > 0 {
                //word
                wordsInLine.append(element)
            }
            
            if wordsInLine.count > 0{
                linesInBlock.append(wordsInLine)
            }
        }
        
        return linesInBlock.isEmpty ? nil : linesInBlock
    }
}
