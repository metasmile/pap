//
// Created by BLACKGENE on 22.06.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import Contacts

extension String{

    public func detectAll(types: NSTextCheckingResult.CheckingType, options:NSRegularExpression.MatchingOptions=[], range:NSRange?=nil) -> [NSTextCheckingResult] {
        guard types.isEmpty == false, let detector = try? NSDataDetector(types: types.rawValue) else {
            return [NSTextCheckingResult]()
        }
        return detector.matches(in: self, options: options, range: range ?? NSMakeRange(0, self.count))
    }

    public func urls() -> [URL] {
        return self.detectAll(types: [NSTextCheckingResult.CheckingType.link]).compactMap { result -> URL? in
            return result.url
        }
    }

    public func phoneNumbers() -> [String] {
        return self.detectAll(types: [NSTextCheckingResult.CheckingType.phoneNumber]).compactMap { result -> String? in
            return result.phoneNumber
        }
    }

    public func emailAddresses() -> [String] {
        var emailAddresses = [String]()
        for url in self.urls() {
            if let component = URLComponents(url: url, resolvingAgainstBaseURL: false){
                if component.scheme == "mailto"{
                    emailAddresses.append(component.path)
                }
            }
        }
        return emailAddresses
    }
}


public protocol NSTextCheckingPersonComponent {
    var name: String? {get set}
    var jobTitle: String? {get set}
    var organization: String? {get set}
}

public protocol NSTextCheckingTelephoneNumberComponent {
    var phone: String? {get set}
}

public protocol NSTextCheckingAddressComponent {
    var street: String? {get set}
    var city: String? {get set}
    var zip: String? {get set}
    var state: String? {get set}
    var country: String? {get set}
}

extension NSTextCheckingAddressComponent{
    
    public var postalAddress:CNMutablePostalAddress{
        let address = CNMutablePostalAddress()
        address.state = state ?? ""
        address.city = city ?? ""
        address.country = country ?? ""
        address.street = street ?? ""
        address.postalCode = zip ?? ""
        if let isoCode = Locale.current.regionCode ?? Locale.current.languageCode{
            address.isoCountryCode =  isoCode
        }
        return address
    }

    public var formattedString:String{
        return CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
    }

}


public protocol NSTextCheckingFlightComponent {
    var airline: String? {get set}
    var flight: String? {get set}
}

extension NSTextCheckingFlightComponent{
    var formattedString:String?{
        let string = ((airline ?? "") + (flight ?? "")).trimmed
        return string.count > 0 ? string : nil
    }
}

public typealias NSTextCheckingComponent = NSTextCheckingPersonComponent & NSTextCheckingTelephoneNumberComponent & NSTextCheckingAddressComponent & NSTextCheckingFlightComponent
public typealias NSTextCheckingContactComponent = NSTextCheckingPersonComponent & NSTextCheckingTelephoneNumberComponent & NSTextCheckingAddressComponent

private struct _NSTextCheckingComponent: NSTextCheckingComponent {
    public var name: String?
    public var jobTitle: String?
    public var organization: String?
    public var street: String?
    public var city: String?
    public var state: String?
    public var zip: String?
    public var country: String?
    public var phone: String?
    public var airline: String?
    public var flight: String?
}

extension NSTextCheckingResult{
    public var componentObject: NSTextCheckingComponent? {

        if let c = self.components, c.count > 0{
            return _NSTextCheckingComponent(
                    name: c[NSTextCheckingKey.name],
                    jobTitle: c[NSTextCheckingKey.jobTitle],
                    organization: c[NSTextCheckingKey.organization],
                    street: c[NSTextCheckingKey.street],
                    city: c[NSTextCheckingKey.city],
                    state: c[NSTextCheckingKey.state],
                    zip: c[NSTextCheckingKey.zip],
                    country: c[NSTextCheckingKey.country],
                    phone: c[NSTextCheckingKey.phone],
                    airline: c[NSTextCheckingKey.airline],
                    flight: c[NSTextCheckingKey.flight]
            )
        }
        return nil
    }

    public var flight: NSTextCheckingFlightComponent? {
        return componentObject
    }

    public var address: NSTextCheckingAddressComponent? {
        return componentObject
    }

    public var telephoneNumber: NSTextCheckingTelephoneNumberComponent? {
        return componentObject
    }

    public var contact: NSTextCheckingContactComponent? {
        return componentObject
    }

    public var person: NSTextCheckingPersonComponent? {
        return componentObject
    }
}
