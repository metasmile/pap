//
// Created by BLACKGENE on 2018-10-18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit

//TODO: StaticVar-Generic Action Type like Payable
struct VisionTextDetectResultAction_Search {
    static var iconImage:UIImage?{
        return R.image.appActionIconSearch()
    }

    static var title:String{
        return "Search On Google".localized.localizedCapitalized
    }

    static func makeUrl(text:String) -> URL?{
        return URL(string: "https://www.google.com/search?\(["q":text].urlQueryString)")
    }
}

struct VisionTextDetectResultAction_Translation {
    static var iconImage:UIImage?{
        return R.image.appActionIconTranslation()
    }

    static var title:String{
        return "Translate Now".localized.localizedCapitalized
    }

    static func makeUrl(text:String) -> URL?{
        let encodedUrlForTranslation = "https://translate.google.com/m/translate?\(["sl":"auto", "tl":Locale.current.languageCode ?? "en","text":text].urlQueryString)"
        return URL(string:encodedUrlForTranslation)
    }
}