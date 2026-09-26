//
// Created by BLACKGENE on 2018-09-28.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import UIKit
import Contacts
import ContactsUI
import EventKit
import EventKitUI
import SafariServices
import MessageUI

//TODO: MUST separate each actions by type (Action, Contact saving, Text etc)

extension Array where Element:VisionTextDetectResult {
    class MailComposerDelegator: NSObject, MFMailComposeViewControllerDelegate {
        var completion: (() -> Void)?
        
        convenience init(completion: (() -> Void)?) {
            self.init()
            
            self.completion = completion
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true, completion: nil)
            
            completion?()
        }
    }
    
    class MessageComposerDelegator: NSObject, MFMessageComposeViewControllerDelegate {
        var completion: (() -> Void)?
        
        convenience init(completion: (() -> Void)?) {
            self.init()
            
            self.completion = completion
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true, completion: nil)
            
            completion?()
        }
    }

    func handleAsAction(_ isQuickActionOnly:Bool, message:String?=nil, _ asyncSignal: AsyncWaitSignalable) -> String?{

        let items: [VisionTextDetectResult] = self
        let currentQueue = DispatchQueue.current

        let alert = UIAlertController.actionSheet(title: "Choose An Action".localized, message: message)

        let defaultCancelSubAction = UIAlertAction(title: "Cancel".localized, style: .cancel, handler: { action in
            asyncSignal.end()
        })
        
        let defaultMailComposerDelegator = MailComposerDelegator {
            asyncSignal.end()
        }
        
        let defaultMessageComposerDelegator = MessageComposerDelegator {
            asyncSignal.end()
        }

        var StringSet = Set<String>()
        var DateSet = Set<Date>()
        var URLSet = Set<URL>()

        for item in items {

            guard let resultGroup = item.resultGroup else{
                continue
            }

            let actionMessage = "Choose An Sub Action.".localized

            /*
                Phone Number (removed along with VisionTextPhoneNumberParser and PhoneNumberKit dependency)
             */

            /*
                URL
            */
            for url in Array<VisionTextURLParser.OutputType.Element>(Set((resultGroup.urls ?? []).reduce([],+))){
                if URLSet.contains(url){
                    continue
                } else {
                    URLSet.insert(url)
                }

                //sub actions
                let _quickAction = { (t: String) -> UIAlertAction in
                    return UIAlertAction(title: t, style: .default, handler: { action in
                        UIApplication.openSafari(with:url) {
                            asyncSignal.end()
                        }
                    })
                }


                var action:UIAlertAction

                if isQuickActionOnly{

                    action = _quickAction(url.absoluteString)

                }else{


                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)
                    let _actions = [
                        defaultCancelSubAction,

                        _quickAction("Open Web Page".localized),

                        UIAlertAction(title: "Add New Contact".localized, style: .default, handler: { action in
                            if ContactsUtil.shared.requestAuthorizationAndWait(asyncSignal){
                                let contact = CNMutableContact()
                                contact.contactType = .person
                                contact.fillNameIfBlanked()

                                let components = NSCalendar.current.dateComponents([.year, .month, .day], from: Date())
                                contact.dates.append(CNLabeledValue(label: "Date".localized, value: components as NSDateComponents))

                                contact.urlAddresses.append(CNLabeledValue(label: "URL", value: url.absoluteString as NSString))

                                CNContactViewController.presentDialog(newContact: contact, didDismiss: {
                                    asyncSignal.end()
                                })

                            }else{
                                asyncSignal.end()
                            }
                        }),

                        UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                            UIPasteboard.general.url = url
                            asyncSignal.end()
                        }),
                        UIAlertAction(title: "Share".localized, style: .default, handler: { action in
                            UIActivityViewController.share(activityItems: [url], excludedActivityTypes: [UIActivity.ActivityType.copyToPasteboard]) { type, b, anies, error in
                                asyncSignal.end()
                            }
                        })
                    ]
                    for _action in _actions{
                        _alert.addAction(_action)
                    }

                    action = UIAlertAction(title: url.absoluteString, style: . default, handler: { action in
                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }
                    })
                }

                action.accessoryImage = R.image.appActionIconURL()

                alert.addAction(action)
            }

            /*
                Date -> Calendar, Reminder
            */
            for date in Array<VisionTextDateParser.OutputType.Element>(Set((resultGroup.dates ?? []).reduce([],+))){
                if DateSet.contains(date){
                    continue
                } else {
                    DateSet.insert(date)
                }

                let formatter = DateFormatter()
                formatter.dateStyle = .long
                formatter.timeStyle = .medium
                let dateString = formatter.string(from: date)

                //sub actions
                let _quickAction = { (t: String) -> UIAlertAction in
                    return UIAlertAction(title: t, style: .default, handler: { action in

                        EventKitUtil.shared.newEvent { event in

                            if let event = event{
                                event.title = "New Event".localized
                                event.startDate = date
                                event.endDate = date

                                //insert Note with original plain text
                                if let plainText = item.plainText {
                                    event.notes = plainText
                                }

                                EKEventEditViewController.presentDialog(newEvent: event, didDismiss: { action in
                                    asyncSignal.end()
                                })

                            }else{
                                asyncSignal.end()
                            }
                        }
                    })
                }


                var action:UIAlertAction

                if isQuickActionOnly{

                    action  = _quickAction(dateString)

                }else{
                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)
                    var _actions = [defaultCancelSubAction]

                    _actions.append(
                            _quickAction("Add an Event".localized)
                    )

                    _actions.append(
                            UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                                UIPasteboard.general.string = dateString
                                asyncSignal.end()
                            })
                    )

                    _actions.append(
                            UIAlertAction(title: "Share".localized, style: .default, handler: { action in
                                UIActivityViewController.share(activityItems: [dateString], excludedActivityTypes: [UIActivity.ActivityType.copyToPasteboard]) { type, b, anies, error in
                                    asyncSignal.end()
                                }
                            })
                    )

                    for _action in _actions{
                        _alert.addAction(_action)
                    }

                    action = UIAlertAction(title: dateString, style: .default, handler: { action in
                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }

                    })
                }

                action.accessoryImage = R.image.appActionIconDate()

                alert.addAction(action)
            }

            /*
                Email Address -> Email Map app
            */
            for email in Array<VisionTextEmailAddressParser.OutputType.Element>(Set((resultGroup.emails ?? []).reduce([],+).compactMap({ $0.trimmed.nilEmpty }))){
                if StringSet.contains(email){
                    continue
                } else {
                    StringSet.insert(email)
                }


                //sub actions

                let _quickAction = { (t: String) -> UIAlertAction? in

                    if let url = URL(string: "mailto://\(email)")
                    , UIApplication.shared.canOpenURL(url){
                        return UIAlertAction(title: t, style: .default, handler: { action in
                            asyncSignal.end()
                            UIApplication.shared.open(url)
                        })
                    }

                    return nil
                }

                var action:UIAlertAction?

                if isQuickActionOnly{
                    action = _quickAction(email)


                }else{
                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)

                    var _actions = [defaultCancelSubAction]

                    if let q = _quickAction("Send an Email".localized){
                        _actions.append(q)
                    }

                    let param = [
                        "to": email
                    ].urlQueryString

                    let url_gmail = URL(string: "googlegmail://co?\(param)")
                    if let url = url_gmail, UIApplication.shared.canOpenURL(url){
                        _actions.append(
                                UIAlertAction(title: "Send an Email".localized + " (Gmail)", style: .default, handler: { action in
                                    asyncSignal.end()
                                    UIApplication.shared.open(url)
                                })
                        )
                    }

                    let url_inbox = URL(string: "inbox-gmail://co?\(param)")
                    if let url = url_inbox, UIApplication.shared.canOpenURL(url){
                        _actions.append(
                                UIAlertAction(title: "Send an Email".localized + " (Google Inbox)", style: .default, handler: { action in
                                    asyncSignal.end()
                                    UIApplication.shared.open(url)
                                })
                        )
                    }

                    _actions.append(
                            UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                                UIPasteboard.general.string = email
                                asyncSignal.end()
                            })
                    )

                    _actions.append(
                            UIAlertAction(title: "Share".localized, style: .default, handler: { action in
                                UIActivityViewController.share(activityItems: [email], excludedActivityTypes: [UIActivity.ActivityType.copyToPasteboard]) { type, b, anies, error in
                                    asyncSignal.end()
                                }
                            })
                    )

                    _actions.append(
                            UIAlertAction(title: "Add New Contact".localized, style: .default, handler: { action in

                                if ContactsUtil.shared.requestAuthorizationAndWait(asyncSignal){
                                    let contact = CNMutableContact()
                                    contact.contactType = .person
                                    contact.fillNameIfBlanked()

                                    let components = NSCalendar.current.dateComponents([.year, .month, .day], from: Date())
                                    contact.dates.append(CNLabeledValue(label: "Date".localized, value: components as NSDateComponents))
                                    contact.emailAddresses = [CNLabeledValue(label: "E-mail Address".localized, value: email as NSString)]

                                    CNContactViewController.presentDialog(newContact: contact, didDismiss: {
                                        asyncSignal.end()
                                    })

                                }else{
                                    asyncSignal.end()
                                }
                            })
                    )

                    for _action in _actions{
                        _alert.addAction(_action)
                    }

                    action = UIAlertAction(title: email, style: .default, handler: { action in
                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }
                    })
                }

                action?.accessoryImage = R.image.appActionIconEmail()

                if let action = action{
                    alert.addAction(action)
                }
            }

            /*
                Address -> Map
            */
            //comgooglemaps://?saddr=Google+Inc,+8th+Avenue,+New+York,+NY&daddr=John+F.+Kennedy+International+Airport,+Van+Wyck+Expressway,+Jamaica,+New+York&directionsmode=transit
            // https://developers.google.com/maps/documentation/urls/ios-urlscheme
            // https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html#//apple_ref/doc/uid/TP40007899-CH5-SW1

            for addr in (resultGroup.addresses ?? []).reduce([],+){
                let addressString = addr.formattedString.trimmed

                if StringSet.contains(addressString){
                    continue
                } else {
                    StringSet.insert(addressString)
                }

                //sub actions
                let _quickAction = { (t: String) -> UIAlertAction? in
                    if let url = URL(string: "http://maps.apple.com/?\(["q":addressString].urlQueryString))")
                    , UIApplication.shared.canOpenURL(url){

                        return UIAlertAction(title: t, style: .default, handler: { action in
                            asyncSignal.end()
                            UIApplication.shared.open(url)
                        })
                    }

                    if let url = URL(string: "https://www.google.com/maps/search/?\(["q":addressString].urlQueryString))") {
                        return UIAlertAction(title: t, style: .default, handler: { action in
                            asyncSignal.end()
                            UIApplication.shared.open(url)
                        })
                    }

                    return nil
                }

                var action:UIAlertAction?

                if isQuickActionOnly{

                    action = _quickAction(addressString)

                }else{

                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)

                    var _actions = [defaultCancelSubAction]

                    if let q = _quickAction("Open Apple Maps".localized){
                        _actions.append(q)
                    }

                    let param_googlemap = [
                        "q":addressString
                        , "x-success": Bundle.main.schemes?.first ?? "undefined"
                        , "x-source": Bundle.main.displayName ?? "Unknown"
                    ].urlQueryString

                    let url_googlemap = URL(string: "comgooglemaps-x-callback://?\(param_googlemap)")

                    if let url = url_googlemap, UIApplication.shared.canOpenURL(url){
                        _actions.append(
                                UIAlertAction(title: "Open Google Maps".localized, style: .default, handler: { action in
                                    asyncSignal.end()
                                    UIApplication.shared.open(url)
                                })
                        )
                    }else{
                        if let url = URL(string: "https://www.google.com/maps/search/\(addressString.encodeAsURLQuery())") {
                            _actions.append(
                                    UIAlertAction(title: "Search On Google Maps".localized, style: .default, handler: { action in
                                        asyncSignal.end()
                                        UIApplication.shared.open(url)
                                    })
                            )
                        }
                    }

                    _actions.append(
                            UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                                UIPasteboard.general.string = addressString
                                asyncSignal.end()
                            })
                    )

                    _actions.append(
                            UIAlertAction(title: "Share".localized, style: .default, handler: { action in
                                UIActivityViewController.share(activityItems: [addressString], excludedActivityTypes: [UIActivity.ActivityType.copyToPasteboard]) { type, b, anies, error in
                                    asyncSignal.end()
                                }
                            })
                    )

                    _actions.append(
                            UIAlertAction(title: "Add New Contact".localized, style: .default, handler: { action in

                                if ContactsUtil.shared.requestAuthorizationAndWait(asyncSignal){
                                    let contact = CNMutableContact()
                                    contact.contactType = .person
                                    contact.fillNameIfBlanked()

                                    let components = NSCalendar.current.dateComponents([.year, .month, .day], from: Date())
                                    contact.dates.append(CNLabeledValue(label: "Date".localized, value: components as NSDateComponents))

                                    contact.postalAddresses = [CNLabeledValue(label: "Address", value: addr.postalAddress)]

                                    CNContactViewController.presentDialog(newContact: contact, didDismiss: {
                                        asyncSignal.end()
                                    })

                                }else{
                                    asyncSignal.end()
                                }
                            })
                    )

                    for _action in _actions{
                        _alert.addAction(_action)
                    }

                    action = UIAlertAction(title: addressString, style: . default, handler: { action in

                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }
                    })

                }

                action?.accessoryImage = R.image.appActionIconLocation()

                if let action = action{
                    alert.addAction(action)
                }

            }// END OF AN ACTION


            /*
                Flight Information
            */
            for flightString in Array<VisionTextFlightNumberParser.OutputType.Element>(Set((resultGroup.flights ?? []).reduce([],+).compactMap({ $0.nilEmpty }))){
                if StringSet.contains(flightString){
                    continue
                } else {
                    StringSet.insert(flightString)
                }

                var action:UIAlertAction?

                let url_to_flight = URL(string: "https://flightaware.com/live/flight/"+flightString.encodeAsURLQuery())

                let _quickAction = { (t: String) -> UIAlertAction? in
                    if let url = url_to_flight, UIApplication.shared.canOpenURL(url){
                        return UIAlertAction(title: t, style: .default, handler: { action in
                            UIApplication.openSafari(with:url) {
                                asyncSignal.end()
                            }
                        })
                    }
                    return nil
                }

                if isQuickActionOnly{
                    action = _quickAction(flightString)

                }else{
                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)

                    var _actions = [defaultCancelSubAction]

                    if let q = _quickAction("Search Flights".localized){
                        _actions.append(q)
                    }

                    _actions.append(
                            UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                                UIPasteboard.general.string = flightString
                                asyncSignal.end()
                            })
                    )

                    _actions.append(
                            UIAlertAction(title: "Share".localized, style: .default, handler: { action in
                                UIActivityViewController.share(activityItems: [flightString], excludedActivityTypes: [UIActivity.ActivityType.copyToPasteboard]) { type, b, anies, error in
                                    asyncSignal.end()
                                }
                            })
                    )

                    for _action in _actions{
                        _alert.addAction(_action)
                    }

                    //root action
                    action = UIAlertAction(title: flightString, style: . default, handler: { action in
                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }
                    })
                }

                action?.accessoryImage = R.image.appActionIconFlight()

                if let action = action{
                    alert.addAction(action)
                }

            }// END OF AN ACTION
            
            
            /*
             Currency
             */
            for currencyString in Array<VisionTextCurrencyParser.OutputType.Element>(Set((resultGroup.currencies ?? []).reduce([],+).compactMap({ $0.nilEmpty }))){
                if StringSet.contains(currencyString){
                    continue
                } else {
                    StringSet.insert(currencyString)
                }
                
                var action:UIAlertAction?
                
                let localeFormatter = NumberFormatter()
                localeFormatter.numberStyle = .currency
                
                var exchangeURL: URL?
                if let currencyCode = localeFormatter.currencyCode {
                    exchangeURL = URL(string: "https://google.com/search?q=" + "\(currencyString) to \(currencyCode)".encodeAsURLQuery())
                }
                else {
                    exchangeURL = URL(string: "https://google.com/search?q=" + currencyString.encodeAsURLQuery())
                }
                
                let _quickAction = { (t: String) -> UIAlertAction? in
                    if let url = exchangeURL, UIApplication.shared.canOpenURL(url){
                        return UIAlertAction(title: t, style: .default, handler: { action in
                            UIApplication.openSafari(with:url) {
                                asyncSignal.end()
                            }
                        })
                    }
                    return nil
                }
                
                if isQuickActionOnly{
                    action = _quickAction(currencyString)
                    
                }else{
                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)
                    
                    var _actions = [defaultCancelSubAction]
                    
                    if let q = _quickAction("Currency Exchange".localized){
                        _actions.append(q)
                    }
                    
                    _actions.append(
                        UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                            UIPasteboard.general.string = currencyString
                            asyncSignal.end()
                        })
                    )
                    
                    _actions.append(
                        UIAlertAction(title: "Share".localized, style: .default, handler: { action in
                            UIActivityViewController.share(activityItems: [currencyString], excludedActivityTypes: [UIActivity.ActivityType.copyToPasteboard]) { type, b, anies, error in
                                asyncSignal.end()
                            }
                        })
                    )
                    
                    for _action in _actions{
                        _alert.addAction(_action)
                    }
                    
                    //root action
                    action = UIAlertAction(title: currencyString, style: . default, handler: { action in
                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }
                    })
                }

                action?.accessoryImage = R.image.appActionIconCurrency()
                
                if let action = action{
                    alert.addAction(action)
                }
                
            }// END OF AN ACTION
            
            
            /*
             Plain Text
             */
            if let plainText = item.plainText?.trimmed {
                var action:UIAlertAction?
                
                //sub actions
                let _quickAction = { (t: String) -> UIAlertAction? in
                    return UIAlertAction(title: t, style: .default, handler: { action in
                        UIActivityViewController.share(activityItems: [plainText], excludedActivityTypes: nil) { type, b, anies, error in
                            asyncSignal.end()
                        }
                    })
                }
                
                let actionTitle = (item.plainText ?? "").components(separatedBy: "\n").count <= 1 ? "Get Text".localized :  "Get All Text".localized
                
                if isQuickActionOnly{
                    action = _quickAction(actionTitle)
                    
                }else{
                    let _alert = UIAlertController.actionSheet(title: actionMessage, message: plainText)
                    
                    var _actions = [defaultCancelSubAction]
                    
                    if let q = _quickAction("Share".localized){
                        _actions.append(q)
                    }
                    
                    _actions.append(
                        UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                            UIPasteboard.general.string = plainText
                            asyncSignal.end()
                        })
                    )
                    
                    for _action in _actions{
                        _alert.addAction(_action)
                    }
                    
                    //root action
                    action = UIAlertAction(title: actionTitle, style: . default, handler: { action in
                        DispatchQueue.main.async{
                            UIViewController.present(_alert, animated: true)
                        }
                    })
                }
                
                if let action = action{
                    action.accessoryImage = R.image.appActionIconText()
                    alert.addAction(action)
                }

                if let url = VisionTextDetectResultAction_Translation.makeUrl(text: plainText) {
                    let action = UIAlertAction(title: VisionTextDetectResultAction_Translation.title, style: .default, handler: { action in
                        UIApplication.openSafari(with: url) {
                            asyncSignal.end()
                        }
                    })
                    action.accessoryImage = VisionTextDetectResultAction_Translation.iconImage
                    alert.addAction(action)
                }

                if let url = VisionTextDetectResultAction_Search.makeUrl(text: plainText) {
                    let action = UIAlertAction(title: VisionTextDetectResultAction_Search.title, style: .default, handler: { action in
                        asyncSignal.end()
                        UIApplication.shared.open(url)
                    })
                    action.accessoryImage = VisionTextDetectResultAction_Search.iconImage
                    alert.addAction(action)
                }

            }// END OF AN ACTION


            /*
             Barcodes
             */
            for barcode in resultGroup.barcodes ?? [] {
                guard barcode.format == .qrCode else {
                    guard let code = barcode.rawValue, let url = URL(string: "https://google.com/search?q=\(code)") else { break }
                    
                    let action = UIAlertAction(title: code, style: .default, handler: { action in
                        UIApplication.openSafari(with: url) {
                            asyncSignal.end()
                        }
                    })
                    action.accessoryImage = R.image.appActionIconURL()
                    alert.addAction(action)
                    continue
                }
                
                switch barcode.valueType {
                case .contactInfo:
                    guard let contactInfo = barcode.contactInfo else { break }
                    
                    let action = UIAlertAction(title: contactInfo.name?.formattedName ?? "Add New Contact".localized, style: .default, handler: { action in
                        if let vCard = barcode.rawValue?.data(using: String.Encoding.utf8), let contacts = try? CNContactVCardSerialization.contacts(with: vCard), let contact = contacts.first {
                            
                            currentQueue.async{
                                if ContactsUtil.shared.requestAuthorizationAndWait(asyncSignal){
                                    CNContactViewController.presentDialog(newContact: contact, didDismiss: {
                                        asyncSignal.end()
                                    })
                                    
                                } else{
                                    asyncSignal.end()
                                }
                            }
                        }
                    })
                    action.accessoryImage = R.image.appActionIconContact()
                    alert.addAction(action)
                case .calendarEvent:
                    guard let calendarEvent = barcode.calendarEvent else { break }
                    
                    let action = UIAlertAction(title: calendarEvent.summary ?? "New Event".localized, style: .default, handler: { action in
                        EventKitUtil.shared.newEvent { event in
                            
                            if let event = event {
                                event.title = calendarEvent.summary
                                event.startDate = calendarEvent.start
                                if let start = calendarEvent.start, let end = calendarEvent.end, start <= end {
                                    event.endDate = end
                                }
                                else {
                                    event.endDate = calendarEvent.start
                                }
                                event.location = calendarEvent.location
                                event.notes = calendarEvent.eventDescription
                                
                                EKEventEditViewController.presentDialog(newEvent: event, didDismiss: { action in
                                    asyncSignal.end()
                                })
                                
                            }else{
                                asyncSignal.end()
                            }
                        }

                    })
                    action.accessoryImage = R.image.appActionIconDate()
                    alert.addAction(action)
                case .phone:
                    guard let phone = barcode.phone?.number else { break }
                    
                    let action = UIAlertAction(title: phone, style: .default, handler: { action in
                        if let url = URL(string: "tel://\(phone)")
                            , ContactsUtil.shared.isCapableToCall
                            , UIApplication.shared.canOpenURL(url) {
                            
                            asyncSignal.end()
                            
                            UIApplication.shared.open(url)
                            
                        }else{
                            asyncSignal.end()
                        }
                    })
                    action.accessoryImage = R.image.appActionIconPhoneCall()
                    alert.addAction(action)
                case .product:
                    guard let product = barcode.rawValue, let url = URL(string: "https://google.com/search?q=\(product)") else { break }
                    
                    let action = UIAlertAction(title: product, style: .default, handler: { action in
                        UIApplication.openSafari(with: url) {
                            asyncSignal.end()
                        }
                    })
                    action.accessoryImage = R.image.appActionIconURL()
                    alert.addAction(action)
                case .ISBN:
                    guard let isbn = barcode.rawValue, let url = URL(string: "https://isbnsearch.org/isbn/\(isbn)") else { break }
                    
                    let action = UIAlertAction(title: isbn, style: .default, handler: { action in
                        UIApplication.openSafari(with: url) {
                            asyncSignal.end()
                        }
                    })
                    action.accessoryImage = R.image.appActionIconURL()
                    alert.addAction(action)
                case .URL:
                    guard
                        let urlString = barcode.rawValue,
                        let url = URL(string: urlString)
                    else { break }
                    
                    let action = UIAlertAction(title: urlString, style: .default, handler: { action in
                        UIApplication.openSafari(with: url) {
                            asyncSignal.end()
                        }
                    })
                    action.accessoryImage = R.image.appActionIconURL()
                    alert.addAction(action)
                case .SMS:
                    guard let sms = barcode.sms, let phone = sms.phoneNumber else { break }
                    let action = UIAlertAction(title: phone, style: .default, handler: { action in
                        if MFMessageComposeViewController.canSendText() {
                            let composer = MFMessageComposeViewController()
                            composer.messageComposeDelegate = defaultMessageComposerDelegator
                            composer.recipients = [phone]
                            composer.body = sms.message
                            
                            DispatchQueue.main.async{
                                UIViewController.present(composer, animated: true)
                            }
                        }
                        else if let url = URL(string: "sms://\(phone)&body=\(sms.message?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"), UIApplication.shared.canOpenURL(url) {
                            asyncSignal.end()
                            UIApplication.shared.open(url)
                        }
                    })
                    
                    action.accessoryImage = R.image.appActionIconEmail()
                    alert.addAction(action)
                case .email:
                    guard let email = barcode.email, let address = email.address else { break }
                    let action = UIAlertAction(title: address, style: .default, handler: { action in
                        if MFMailComposeViewController.canSendMail() {
                            let composer = MFMailComposeViewController()
                            composer.mailComposeDelegate = defaultMailComposerDelegator
                            composer.setToRecipients([address])
                            composer.setSubject(email.subject ?? "")
                            composer.setMessageBody(email.body ?? "", isHTML: false)
                            
                            DispatchQueue.main.async{
                                UIViewController.present(composer, animated: true)
                            }
                        }
                        else if let url = URL(string: "mailto://\(email)"), UIApplication.shared.canOpenURL(url) {
                            asyncSignal.end()
                            UIApplication.shared.open(url)
                        }
                    })
                    
                    action.accessoryImage = R.image.appActionIconEmail()
                    alert.addAction(action)
                case .geographicCoordinates:
                    guard
                        let geographicCoordinates = barcode.geoPoint
                    else { break }
                    
                    let latitude = geographicCoordinates.latitude
                    let longitude = geographicCoordinates.longitude
                    let zoom = 10
                    
                    let action = UIAlertAction(title: "Open Apple Maps".localized, style: .default, handler: { action in
                        if let url = URL(string: "https://maps.apple.com/?sll=\(latitude),\(longitude)&z=\(zoom)&t=s"), UIApplication.shared.canOpenURL(url) {
                            asyncSignal.end()
                            UIApplication.shared.open(url)
                        }
                    })
                    action.accessoryImage = R.image.appActionIconLocation()
                    alert.addAction(action)
                case .text, .unknown:
                    guard let plainText = barcode.rawValue else { break }
                    var action:UIAlertAction?
                    
                    //sub actions
                    let _quickAction = { (t: String) -> UIAlertAction? in
                        return UIAlertAction(title: t, style: .default, handler: { action in
                            UIActivityViewController.share(activityItems: [plainText], excludedActivityTypes: nil) { type, b, anies, error in
                                asyncSignal.end()
                            }
                        })
                    }
                    
                    if isQuickActionOnly{
                        action = _quickAction(plainText.components(separatedBy: .newlines).joined())
                        
                    }else{
                        let _alert = UIAlertController.actionSheet(title: actionMessage, message: nil)
                        
                        var _actions = [defaultCancelSubAction]
                        
                        if let q = _quickAction("Share".localized){
                            _actions.append(q)
                        }
                        
                        _actions.append(
                            UIAlertAction(title: "Copy".localized, style: .default, handler: { action in
                                UIPasteboard.general.string = plainText
                                asyncSignal.end()
                            })
                        )

                        if let url = VisionTextDetectResultAction_Translation.makeUrl(text: plainText) {
                            let action = UIAlertAction(title: VisionTextDetectResultAction_Translation.title, style: .default, handler: { action in
                                UIApplication.openSafari(with: url) {
                                    asyncSignal.end()
                                }
                            })
                            action.accessoryImage = VisionTextDetectResultAction_Translation.iconImage
                            _actions.append(action)
                        }

                        if let url = VisionTextDetectResultAction_Search.makeUrl(text: plainText) {
                            let action = UIAlertAction(title: VisionTextDetectResultAction_Search.title, style: .default, handler: { action in
                                asyncSignal.end()
                                UIApplication.shared.open(url)
                            })
                            action.accessoryImage = VisionTextDetectResultAction_Search.iconImage
                            _actions.append(action)
                        }

                        for _action in _actions{
                            _alert.addAction(_action)
                        }
                        
                        //root action
                        action = UIAlertAction(title: plainText.components(separatedBy: .newlines).joined(), style: . default, handler: { action in
                            DispatchQueue.main.async{
                                UIViewController.present(_alert, animated: true)
                            }
                        })
                    }
                    
                    if let action = action{
                        action.accessoryImage = R.image.appActionIconCode()
                        alert.addAction(action)
                    }
                    default: break
                }
            }// END OF AN ACTION
        }// END OF ITEMS


        //ACTION START
        if alert.actions.count > 0{
            alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: { action in
                asyncSignal.end()
            }))

            asyncSignal.begin()

            DispatchQueue.main.async{
                UIViewController.present(alert, animated: true)
            }

            asyncSignal.waitUntilEnd()

            return nil
        }

        return "Could not detect anything.".localized
    }
}
