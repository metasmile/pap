//
//  CodeKit.Data.swift
//  pap
//
//  Created by HYOJIN MO on 02/11/2018.
//  Copyright © 2018 Stells. All rights reserved.
//

import UIKit
import ImageIO
import UniformTypeIdentifiers

extension Data {

    /// Detects the receiver's uniform type identifier using Apple's native frameworks.
    ///
    /// Images are identified by ImageIO's content sniffing. For any other content the
    /// optional source URL's path extension is consulted, as there is no native content
    /// sniffing API for arbitrary data.
    func detectedUTI(sourceURL: URL? = nil) -> UTI? {

        if let source = CGImageSourceCreateWithData(self as CFData, nil),
           let identifier = CGImageSourceGetType(source) {
            return UTI(rawValue: identifier as String)
        }

        if let sourceURL = sourceURL,
           !sourceURL.pathExtension.isEmpty,
           let type = UTType(filenameExtension: sourceURL.pathExtension) {
            return UTI(rawValue: type.identifier)
        }

        return nil
    }
}

extension Data {
    func writeToLocalFile(uti: UTI? = nil) -> URL? {
        let url = FileURL.temp(UUID().uuidString, uti ?? detectedUTI(), group: FileURL.fileAndQueuePrivateGroup())
        if (try? write(to: url)) != nil {
            return url
        }
        else {
            return nil
        }
    }
}
