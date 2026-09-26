//
// Created by BLACKGENE on 20.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

/*
INFO:

Must be maintained atomic process. Do not use class, and additional parsing logic.
*/

import Foundation
import Contacts

public struct VisionTextResultGroup {
    init(){}

    var emails:[VisionTextEmailAddressParser.OutputType]?
    var addresses:[VisionTextAddressParser.OutputType]?

    var dates:[VisionTextDateParser.OutputType]?
    var urls:[VisionTextURLParser.OutputType]?
    var flights:[VisionTextFlightNumberParser.OutputType]?
    
    var currencies:[VisionTextCurrencyParser.OutputType]?
    
    var barcodes:[VisionBarcode]?

    var isFilled:Bool{
        return self.emails?.count ?? 0 > 0
                || self.addresses?.count ?? 0 > 0

                || self.dates?.count ?? 0 > 0
                || self.urls?.count ?? 0 > 0
                || self.flights?.count ?? 0 > 0
                || self.currencies?.count ?? 0 > 0
        
                || self.barcodes?.count ?? 0 > 0
    }
}

private struct VisionTextNSTextCheckingResult {
    static func detect(_ visionText: VisionTextBlock, _ types:NSTextCheckingResult.CheckingType) -> [NSTextCheckingResult]? {
        let stringParser = VisionTextStringParser()
        guard let rawText = stringParser.process(input: visionText) else{
            return nil
        }
        return rawText.detectAll(types: types).nilEmpty
    }
}

public struct VisionTextEmailAddressParser: VisionTextParser{
    typealias OutputType = [String]

    private let stringParser = VisionTextStringParser()

    func process(input: VisionTextBlock) -> OutputType? {
        guard let rawText = stringParser.process(input: input) else{
            return nil
        }
        return type(of: self).parse(string:rawText)
    }

    static func parse(string:String) -> OutputType?{
        return string.emailAddresses().nilEmpty
    }
}

public struct VisionTextDateParser: VisionTextParser{
    typealias OutputType = [Date]

    func process(input: VisionTextBlock) -> OutputType? {
        return VisionTextNSTextCheckingResult.detect(input, NSTextCheckingResult.CheckingType.date)?.compactMap { result -> Date? in
            return result.date
        }.nilEmpty
    }
}

public struct VisionTextURLParser: VisionTextParser{
    typealias OutputType = [URL]

    func process(input: VisionTextBlock) -> OutputType? {
        return VisionTextNSTextCheckingResult.detect(input, NSTextCheckingResult.CheckingType.link)?.compactMap { result -> URL? in
            return result.url
        }.nilEmpty
    }
}

public struct VisionTextAddressParser: VisionTextParser{
    typealias OutputType = [NSTextCheckingAddressComponent]

    func process(input: VisionTextBlock) -> OutputType? {
        return VisionTextNSTextCheckingResult.detect(input, NSTextCheckingResult.CheckingType.address)?.compactMap { result -> NSTextCheckingAddressComponent? in
            return result.address
        }.nilEmpty
    }
}

//https://flightaware.com/live/findflight?origin=EDDF&destination=KLAX
public struct VisionTextFlightNumberParser: VisionTextParser{
    typealias OutputType = [String]

    private let blockParser = VisionTextTextBlockParser()

    //https://en.wikipedia.org/wiki/Flight_number
    // Flight number - IATA (marketing) flight number - /^[A-Z0-9]{3,}$/ BA026
    //Callsign - ICAO (operational) flight number - /^[A-Z]{3}[A-Z0-9]{1,}$/ BAW319K

    private static let regexPatternType1 = "[A-Z]{3}\\s*[0-9]{1,4}"
    private static let regexPatternType2 = "[0-9]{1}[A-Z]{2}\\s*[0-9]{1,4}"
    private static let regexPatternType3 = "[A-Z]{2}\\s*[0-9]{1,4}"

    private static let regexPattern = "(^|\\s)(\(regexPatternType1))|(\(regexPatternType2))|(\(regexPatternType3))"

    public static func matchesInText(text:String) -> [String]?{
        if text.count==0{
            return nil
        }

        return Array(Set(
                text.trimmed
                .matchedStrings(regexPattern)
                .compactMap { $0.trimmed.nilEmpty }
        )).nilEmpty
    }

    func process(input: VisionTextBlock) -> OutputType? {
        guard let lines = blockParser.process(input: input) else {
            return nil
        }

        var flightNumbers = [String]()
        for word in lines.reduce([],+){
            if let matches = type(of: self).matchesInText(text:word){
                flightNumbers.append(contentsOf: matches)
            }
        }

        return !flightNumbers.isEmpty ? flightNumbers : nil
    }

}

public struct VisionTextContactParser: VisionTextParser, MergingParser{
    typealias OutputType = CNMutableContact

    public static let defaultTypes:NSTextCheckingResult.CheckingType = [.link, .address, .phoneNumber, .date, .quote, .transitInformation]

    public var types:NSTextCheckingResult.CheckingType?

    public var parseLinkAsEmailAddress = true

    func process(input: VisionTextBlock, mergingOutput: CNMutableContact) -> CNMutableContact? {
        let stringParser = VisionTextStringParser()
        guard let rawText = stringParser.process(input: input) else{
            return nil
        }

        let contact = mergingOutput

        if let emails = VisionTextEmailAddressParser.parse(string: rawText){
            let label:String = "E-mail Address".localized
            for email in emails{
                let value = CNLabeledValue(label: contact.emailAddresses.count==0 ? label : "\(label) (\(contact.emailAddresses.count))", value: email as NSString)
                contact.emailAddresses.append(value)
            }
        }

        let detectedResults = rawText.detectAll(types: types ?? type(of: self).defaultTypes).nilEmpty ?? []

        for result in detectedResults{

            if let date = result.date{
                var calendar = NSCalendar.current
                if let timezone = result.timeZone{
                    calendar.timeZone = timezone
                }
                let unitFlags = Set<Calendar.Component>([.year, .month, .day])
                let components = calendar.dateComponents(unitFlags, from: date as Date)

                let label = "Date".localized
                let value = CNLabeledValue(label: contact.dates.count==0 ? label : "\(label) (\(contact.dates.count))", value: components as NSDateComponents)
                contact.dates.append(value)
            }

            if let url = result.url{
                let addingValue = url.absoluteString as NSString
                if contact.urlAddresses.contains(where:{ $0.value != addingValue}) == false{
                    let label:String = "URL"
                    let value = CNLabeledValue(label: contact.urlAddresses.count == 0 ? label : "\(label) (\(contact.urlAddresses.count))", value: addingValue)
                    contact.urlAddresses.append(value)
                }
            }

            if let comp = result.componentObject{
                contact.jobTitle = comp.jobTitle ?? mergingOutput.jobTitle
                contact.givenName = comp.name ?? mergingOutput.givenName
                contact.organizationName = comp.organization ?? mergingOutput.organizationName

                let address = CNMutablePostalAddress()
                address.state = result.address?.state ?? ""
                address.city = result.address?.city ?? ""
                address.country = result.address?.country ?? ""
                address.street = result.address?.street ?? ""
                address.postalCode = result.address?.zip ?? ""

                let label = "Address".localized
                let value = CNLabeledValue(label: contact.postalAddresses.count == 0 ? label : "\(label) (\(contact.postalAddresses.count))", value: address as CNPostalAddress)
                contact.postalAddresses.append(value)
            }

            if contact.note.count > 0{
                contact.note += "\n"
            }

            if let flightText = result.flight?.formattedString{
                contact.note += "Flight Number".localized + " : " + flightText
                contact.note += "\n\n"
            }

            if !contact.note.contains(rawText), let content = rawText.trimmed.nilEmpty{
                contact.note += content
            }
        }

        if contact.note.count>0{
            contact.fillNameIfBlanked()
            return contact
        }
        return nil
    }

    func process(input: VisionTextBlock) -> CNMutableContact? {
        let contact = CNMutableContact()
        contact.contactType = .person

        return self.process(input: input, mergingOutput: contact)
    }
}

// Currency
//https://github.com/danthorpe/Money

public struct VisionTextCurrencyParser: VisionTextParser{
    typealias OutputType = [String]
    
    private static let currencySymbolRegexPattern = "\\p{Currency_Symbol}"
    private static let currencyCodeRegexPattern = "\\b[A-Z]+\\b"
    
    private static let commaGroupSeparatorRegexPattern = "[+-]?[0-9]+(?:,?[0-9]{3})*(?:.?[0-9]{2})?"
    private static let dotGroupSeparatorRegexPattern = "[+-]?[0-9]+(?:.?[0-9]{3})*(?:,?[0-9]{2})?"
    private static let spaceGroupSeparatorRegexPattern = "[+-]?[0-9]+(?:\\s?[0-9]{3})*(?:.?[0-9]{2}|,?[0-9]{2})?"
    private static let priceRegexPattern = "[+-]?[0-9]+(?:,?[0-9]{3}|.?[0-9]{3})*(?:.?[0-9]{2}|,?[0-9]{2})?"
    private static let numberRegexPattern = "[1-9]{1}[0-9]*"
    
    private static let currencyRegexPatternType1 = "\(currencySymbolRegexPattern)\\s*\(priceRegexPattern)"
    private static let currencyRegexPatternType2 = "\(priceRegexPattern)\\s*\(currencySymbolRegexPattern)"
    private static let currencyRegexPatternType3 = "\(currencyCodeRegexPattern)\\s*\(priceRegexPattern)"
    private static let currencyRegexPatternType4 = "\(priceRegexPattern)\\s*\(currencyCodeRegexPattern)"
    
    private static let currencyRegexPatternType5 = "\(currencySymbolRegexPattern)\\s*\(numberRegexPattern)"
    private static let currencyRegexPatternType6 = "\(numberRegexPattern)\\s*\(currencySymbolRegexPattern)"
    private static let currencyRegexPatternType7 = "\(currencyCodeRegexPattern)\\s*\(numberRegexPattern)"
    private static let currencyRegexPatternType8 = "\(numberRegexPattern)\\s*\(currencyCodeRegexPattern)"
    
    //for USD60.40
    private static let currencyRegexPatternType9 = "[A-Z]+\\s*\(priceRegexPattern)"
    private static let currencyRegexPatternType10 = "[A-Z]+\\s*\(numberRegexPattern)"
    
    private static let regexPattern = "(\(currencyRegexPatternType1)|\(currencyRegexPatternType2)|\(currencyRegexPatternType3)|\(currencyRegexPatternType4)|\(currencyRegexPatternType5)|\(currencyRegexPatternType6)|\(currencyRegexPatternType7)|\(currencyRegexPatternType8)|\(currencyRegexPatternType9)|\(currencyRegexPatternType10))"
    
    public static func matchesInText(text:String) -> [String]?{
        if text.count==0{
            return nil
        }
        
        return Array(Set(
            text.trimmed
                .matchedStrings(regexPattern)
                .compactMap { $0.trimmed.nilEmpty }
        )).nilEmpty
    }
    
    func process(input: VisionTextBlock) -> OutputType? {
        var currencies = [String]()
        if let matches = type(of: self).matchesInText(text: input.text) {
            for match in matches {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.usesGroupingSeparator = true
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                formatter.roundingMode = .down
                
                if let currencySymbol = match.matchedStrings(VisionTextCurrencyParser.currencySymbolRegexPattern).first {
                    formatter.currencySymbol = currencySymbol
                }
                else if let currencyCode = match.matchedStrings(VisionTextCurrencyParser.currencyCodeRegexPattern).first ?? match.matchedStrings("[A-Z]+").first {
                    
                    let estimatedLocale = Locale.availableIdentifiers.map { Locale(identifier: $0) }.first { $0.currencyCode == currencyCode }
                    if let currencySymbol = estimatedLocale?.currencySymbol {
                        formatter.currencySymbol = currencySymbol
                    }
                    else {
                        //INFO: https://coinmarketcap.com/all/views/all/
                        // sort by market cap
                        switch currencyCode {
                            case "S", "s": formatter.currencySymbol = "$"
                            case "E": formatter.currencySymbol = "€"
                            case "W", "w": formatter.currencySymbol = "￦"
                            case "Y": formatter.currencySymbol = "¥"
                            case "BTC", "ETH", "XRP", "BCH", "EOS", "XLM", "LTC", "ADA", "USDT", "XMR", "TRX", "MIOTA", "DASH", "BNB", "NEO", "ETC", "XEM", "XTZ", "ZEC": formatter.currencyCode = currencyCode
                            default: continue
                        }
                    }
                }
                
                if match.matched(",[0-9]{2}$") {
                    formatter.currencyGroupingSeparator = "."
                    formatter.currencyDecimalSeparator = ","
                }
                else if match.matched(".[0-9]{2}$") {
                    formatter.currencyGroupingSeparator = ","
                    formatter.currencyDecimalSeparator = "."
                }
                
                guard var priceString = match.matchedStrings(VisionTextCurrencyParser.priceRegexPattern).first else { continue }
                
                priceString = priceString.replaceIfMatched(withPattern: "\\s", replace: "")
                
                if let fractionString = priceString.matchedStrings(",[0-9]{2}$").first {
                    priceString = priceString.replaceIfMatched(withPattern: ",[0-9]{2}$", replace: fractionString.replace(",", "."))
                }
                
                let decimalFormatter = NumberFormatter()
                decimalFormatter.numberStyle = .decimal
                
                guard let price = decimalFormatter.number(from: priceString), let currencyString = formatter.string(from: price) else { continue }
                
                currencies.append(currencyString)
                
            }
        }
        return !currencies.isEmpty ? currencies : nil
    }

    
    //    $  1,234.57;          USD 99.99           100 BTC
    
    
    //                          ABC 7000
    
//    $8,987.65;        € 900               30000
    

    //              £ 100000
    
    //    4 555,66 S.        Y 300               W 29,900
    
    
//    7 888,99 €.
    
    
    //          this is $ 7.99
    
//    http://trigeminal.fmsinc.com/samples/setlocalesample2.asp
}

// Bank Account
//IBAN - EU: http://ht5ifv.serprest.pt/extensions/tools/IBAN/
//US Bank accout - https://amcbanking.com/kb/12113/

//GPS Coordination
/*
40° 26' 46" N 79° 58' 56" W
48°51'12.28" 2°20'55.68"
40° 26.767' N 79° 58.933' W
40.446° N 79.982° W
48.85341, 2.3488
*/
