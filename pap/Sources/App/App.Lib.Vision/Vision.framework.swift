//
//  Vision.framework.swift
//  App.Lib.Vision
//
//  On-device text / barcode / image-label detection backed by Apple's
//  Vision framework. This replaces the previous Firebase ML Kit
//  (`FirebaseMLVision`) dependency while keeping the same call surface
//  (`Vision.vision()`, `onDeviceTextRecognizer()`, `barcodeDetector()`,
//  `onDeviceImageLabeler()` and the `VisionText*` / `VisionBarcode` /
//  `VisionImageLabel` result types) so the feature code above it stays intact.
//

import Foundation
import UIKit
import Vision

// MARK: - Orientation

enum VisionDetectorImageOrientation {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
    case leftTop
    case leftBottom
    case rightTop
    case rightBottom

    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .topLeft:      return .up
        case .topRight:     return .upMirrored
        case .bottomRight:  return .down
        case .bottomLeft:   return .downMirrored
        case .leftTop:      return .leftMirrored
        case .leftBottom:   return .left
        case .rightTop:     return .right
        case .rightBottom:  return .rightMirrored
        }
    }

    static func from(_ orientation: UIImage.Orientation) -> VisionDetectorImageOrientation {
        switch orientation {
        case .up:            return .topLeft
        case .upMirrored:    return .topRight
        case .down:          return .bottomRight
        case .downMirrored:  return .bottomLeft
        case .left:          return .leftBottom
        case .leftMirrored:  return .leftTop
        case .right:         return .rightTop
        case .rightMirrored: return .rightBottom
        @unknown default:    return .topLeft
        }
    }
}

// MARK: - Errors

enum VisionDetectionError: Error {
    case unavailableImage
}

// MARK: - Input

final class VisionImage {
    let image: UIImage
    let orientation: VisionDetectorImageOrientation

    init(image: UIImage) {
        self.image = image
        self.orientation = VisionDetectorImageOrientation.from(image.imageOrientation)
    }
}

// MARK: - Result model

final class VisionTextElement {
    let text: String
    let frame: CGRect

    init(text: String, frame: CGRect) {
        self.text = text
        self.frame = frame
    }
}

final class VisionTextLine {
    let text: String
    let elements: [VisionTextElement]
    let frame: CGRect
    let cornerPoints: [NSValue]?

    init(text: String, elements: [VisionTextElement], frame: CGRect, cornerPoints: [NSValue]?) {
        self.text = text
        self.elements = elements
        self.frame = frame
        self.cornerPoints = cornerPoints
    }
}

final class VisionTextBlock {
    let text: String
    let lines: [VisionTextLine]
    let frame: CGRect
    let cornerPoints: [NSValue]?

    init(text: String, lines: [VisionTextLine], frame: CGRect, cornerPoints: [NSValue]?) {
        self.text = text
        self.lines = lines
        self.frame = frame
        self.cornerPoints = cornerPoints
    }
}

final class VisionText {
    let text: String
    let blocks: [VisionTextBlock]

    init(text: String, blocks: [VisionTextBlock]) {
        self.text = text
        self.blocks = blocks
    }
}

enum VisionBarcodeFormat {
    case unknown, qrCode, aztec, dataMatrix, pdf417, upce, ean8, ean13
    case code39, code93, code128, itf, codabar, other

    init(_ symbology: VNBarcodeSymbology) {
        switch symbology {
        case .qr:          self = .qrCode
        case .aztec:       self = .aztec
        case .dataMatrix:  self = .dataMatrix
        case .pdf417:      self = .pdf417
        case .upce:        self = .upce
        case .ean8:        self = .ean8
        case .ean13:       self = .ean13
        case .code39:      self = .code39
        case .code93:      self = .code93
        case .code128:     self = .code128
        case .itf14:       self = .itf
        case .codabar:     self = .codabar
        default:           self = .other
        }
    }
}

enum VisionBarcodeValueType {
    case unknown
    case contactInfo
    case email
    case ISBN
    case phone
    case SMS
    case URL
    case calendarEvent
    case geographicCoordinates
    case product
    case text
}

final class VisionBarcodePersonName {
    let formattedName: String?
    let firstName: String?
    let lastName: String?

    init(formattedName: String?, firstName: String? = nil, lastName: String? = nil) {
        self.formattedName = formattedName
        self.firstName = firstName
        self.lastName = lastName
    }
}

final class VisionBarcodeContactInfo {
    let name: VisionBarcodePersonName?

    init(name: VisionBarcodePersonName?) {
        self.name = name
    }
}

final class VisionBarcodeCalendarEvent {
    let summary: String?
    let location: String?
    let eventDescription: String?
    let start: Date?
    let end: Date?

    init(summary: String?, location: String?, eventDescription: String?, start: Date?, end: Date?) {
        self.summary = summary
        self.location = location
        self.eventDescription = eventDescription
        self.start = start
        self.end = end
    }
}

final class VisionBarcodePhone {
    let number: String?

    init(number: String?) {
        self.number = number
    }
}

final class VisionBarcodeSMS {
    let message: String?
    let phoneNumber: String?

    init(message: String?, phoneNumber: String?) {
        self.message = message
        self.phoneNumber = phoneNumber
    }
}

final class VisionBarcodeEmail {
    let address: String?
    let body: String?
    let subject: String?

    init(address: String?, body: String?, subject: String?) {
        self.address = address
        self.body = body
        self.subject = subject
    }
}

final class VisionBarcodeGeoPoint {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

final class VisionBarcode {
    let rawValue: String?
    let displayValue: String?
    let format: VisionBarcodeFormat
    let valueType: VisionBarcodeValueType
    let contactInfo: VisionBarcodeContactInfo?
    let calendarEvent: VisionBarcodeCalendarEvent?
    let phone: VisionBarcodePhone?
    let sms: VisionBarcodeSMS?
    let email: VisionBarcodeEmail?
    let geoPoint: VisionBarcodeGeoPoint?
    let frame: CGRect
    let cornerPoints: [NSValue]?

    init(rawValue: String?,
         displayValue: String?,
         format: VisionBarcodeFormat,
         valueType: VisionBarcodeValueType,
         contactInfo: VisionBarcodeContactInfo?,
         calendarEvent: VisionBarcodeCalendarEvent?,
         phone: VisionBarcodePhone?,
         sms: VisionBarcodeSMS?,
         email: VisionBarcodeEmail?,
         geoPoint: VisionBarcodeGeoPoint?,
         frame: CGRect,
         cornerPoints: [NSValue]?) {
        self.rawValue = rawValue
        self.displayValue = displayValue
        self.format = format
        self.valueType = valueType
        self.contactInfo = contactInfo
        self.calendarEvent = calendarEvent
        self.phone = phone
        self.sms = sms
        self.email = email
        self.geoPoint = geoPoint
        self.frame = frame
        self.cornerPoints = cornerPoints
    }
}

final class VisionImageLabel {
    let text: String
    let confidence: NSNumber?

    init(text: String, confidence: NSNumber?) {
        self.text = text
        self.confidence = confidence
    }
}

// MARK: - Detectors

/// Namespaced factory mirroring ML Kit's `Vision.vision()` entry point.
final class Vision {
    static func vision() -> Vision { return Vision() }

    func onDeviceTextRecognizer() -> VisionTextRecognizer { return VisionTextRecognizer() }

    func barcodeDetector() -> VisionBarcodeDetector { return VisionBarcodeDetector() }

    func onDeviceImageLabeler() -> VisionImageLabeler { return VisionImageLabeler() }
}

final class VisionTextRecognizer {
    private static let queue = DispatchQueue(label: "com.stells.vision.textRecognizer")

    func process(_ image: VisionImage, completion: @escaping (VisionText?, Error?) -> Void) {
        VisionTextRecognizer.queue.async {
            do {
                completion(try VisionBridge.recognizeText(in: image), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}

final class VisionBarcodeDetector {
    private static let queue = DispatchQueue(label: "com.stells.vision.barcodeDetector")

    func detect(in image: VisionImage, completion: @escaping ([VisionBarcode]?, Error?) -> Void) {
        VisionBarcodeDetector.queue.async {
            do {
                completion(try VisionBridge.detectBarcodes(in: image), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}

final class VisionImageLabeler {
    private static let queue = DispatchQueue(label: "com.stells.vision.imageLabeler")

    func process(_ image: VisionImage, completion: @escaping ([VisionImageLabel]?, Error?) -> Void) {
        VisionImageLabeler.queue.async {
            do {
                completion(try VisionBridge.classify(in: image), nil)
            } catch {
                completion(nil, error)
            }
        }
    }
}

// MARK: - Bridge

private enum VisionBridge {

    static func cgImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    /// Vision normalizes bounding boxes to the bottom-left origin unit square;
    /// convert to image coordinates (top-left origin).
    static func rect(fromNormalized box: CGRect, size: CGSize) -> CGRect {
        return CGRect(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }

    static func cornerPoints(fromNormalized box: CGRect, size: CGSize) -> [NSValue] {
        let rect = rect(fromNormalized: box, size: size)
        return [
            NSValue(cgPoint: CGPoint(x: rect.minX, y: rect.minY)),
            NSValue(cgPoint: CGPoint(x: rect.maxX, y: rect.minY)),
            NSValue(cgPoint: CGPoint(x: rect.maxX, y: rect.maxY)),
            NSValue(cgPoint: CGPoint(x: rect.minX, y: rect.maxY))
        ]
    }

    static func recognizeText(in image: VisionImage) throws -> VisionText {
        guard let cgImage = cgImage(from: image.image) else {
            throw VisionDetectionError.unavailableImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.orientation.cgOrientation, options: [:])
        try handler.perform([request])

        let size = image.image.size
        let blocks: [VisionTextBlock] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }

            let frame = rect(fromNormalized: observation.boundingBox, size: size)
            let corners = cornerPoints(fromNormalized: observation.boundingBox, size: size)

            let elements = candidate.string
                .split(separator: " ", omittingEmptySubsequences: true)
                .map { VisionTextElement(text: String($0), frame: frame) }

            let line = VisionTextLine(text: candidate.string, elements: elements, frame: frame, cornerPoints: corners)
            return VisionTextBlock(text: candidate.string, lines: [line], frame: frame, cornerPoints: corners)
        }

        let text = blocks.map { $0.text }.joined(separator: "\n")
        return VisionText(text: text, blocks: blocks)
    }

    static func detectBarcodes(in image: VisionImage) throws -> [VisionBarcode] {
        guard let cgImage = cgImage(from: image.image) else {
            throw VisionDetectionError.unavailableImage
        }

        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.orientation.cgOrientation, options: [:])
        try handler.perform([request])

        let size = image.image.size
        return (request.results ?? []).map { observation in
            VisionBarcodeContent.make(from: observation, size: size)
        }
    }

    static func classify(in image: VisionImage) throws -> [VisionImageLabel] {
        guard let cgImage = cgImage(from: image.image) else {
            throw VisionDetectionError.unavailableImage
        }

        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.orientation.cgOrientation, options: [:])
        try handler.perform([request])

        return (request.results ?? []).map { observation in
            VisionImageLabel(text: observation.identifier, confidence: NSNumber(value: observation.confidence))
        }
    }
}

// MARK: - Barcode payload parsing

private struct ParsedBarcodeContent {
    var valueType: VisionBarcodeValueType = .text
    var contactInfo: VisionBarcodeContactInfo?
    var calendarEvent: VisionBarcodeCalendarEvent?
    var phone: VisionBarcodePhone?
    var sms: VisionBarcodeSMS?
    var email: VisionBarcodeEmail?
    var geoPoint: VisionBarcodeGeoPoint?
}

private enum VisionBarcodeContent {

    static func make(from observation: VNBarcodeObservation, size: CGSize) -> VisionBarcode {
        let payload = observation.payloadStringValue
        let format = VisionBarcodeFormat(observation.symbology)
        let parsed = parse(payload: payload, format: format)

        return VisionBarcode(
            rawValue: payload,
            displayValue: payload,
            format: format,
            valueType: parsed.valueType,
            contactInfo: parsed.contactInfo,
            calendarEvent: parsed.calendarEvent,
            phone: parsed.phone,
            sms: parsed.sms,
            email: parsed.email,
            geoPoint: parsed.geoPoint,
            frame: VisionBridge.rect(fromNormalized: observation.boundingBox, size: size),
            cornerPoints: VisionBridge.cornerPoints(fromNormalized: observation.boundingBox, size: size)
        )
    }

    static func parse(payload: String?, format: VisionBarcodeFormat) -> ParsedBarcodeContent {
        var out = ParsedBarcodeContent()
        guard let payload = payload, !payload.isEmpty else {
            out.valueType = .unknown
            return out
        }

        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if lower.contains("begin:vcard") {
            out.valueType = .contactInfo
            let name = field("FN", in: text) ?? field("N", in: text)
            out.contactInfo = VisionBarcodeContactInfo(name: VisionBarcodePersonName(formattedName: name))
            return out
        }

        if lower.contains("begin:vevent") {
            out.valueType = .calendarEvent
            out.calendarEvent = VisionBarcodeCalendarEvent(
                summary: field("SUMMARY", in: text),
                location: field("LOCATION", in: text),
                eventDescription: field("DESCRIPTION", in: text),
                start: date(field("DTSTART", in: text)),
                end: date(field("DTEND", in: text))
            )
            return out
        }

        if lower.hasPrefix("mailto:") {
            out.valueType = .email
            out.email = parseMailto(text)
            return out
        }

        if lower.hasPrefix("tel:") {
            out.valueType = .phone
            let number = String(text.dropFirst("tel:".count))
            out.phone = VisionBarcodePhone(number: number.isEmpty ? nil : number)
            return out
        }

        if lower.hasPrefix("smsto:") || lower.hasPrefix("sms:") {
            out.valueType = .SMS
            out.sms = parseSMS(text)
            return out
        }

        if lower.hasPrefix("geo:") {
            out.valueType = .geographicCoordinates
            out.geoPoint = parseGeo(text)
            return out
        }

        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            out.valueType = .URL
            return out
        }

        switch format {
        case .ean13:
            out.valueType = (text.hasPrefix("978") || text.hasPrefix("979")) ? .ISBN : .product
        case .ean8, .upce:
            out.valueType = .product
        default:
            out.valueType = .text
        }
        return out
    }

    // MARK: helpers

    private static func field(_ key: String, in text: String) -> String? {
        let upperKey = key.uppercased()
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let upper = line.uppercased()
            guard upper.hasPrefix(upperKey + ":") || upper.hasPrefix(upperKey + ";") else { continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func date(_ string: String?) -> Date? {
        guard let string = string, !string.isEmpty else { return nil }
        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmssZ",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd'T'HH:mm:ssZ",
            "yyyyMMdd"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static func parseMailto(_ text: String) -> VisionBarcodeEmail {
        let body = String(text.dropFirst("mailto:".count))
        let parts = body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let rawAddress = String(parts.first ?? "")
        var subject: String?
        var message: String?

        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard kv.count == 2 else { continue }
                let key = kv[0].lowercased()
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                if key == "subject" { subject = value }
                if key == "body" { message = value }
            }
        }

        return VisionBarcodeEmail(address: rawAddress.removingPercentEncoding ?? rawAddress, body: message, subject: subject)
    }

    private static func parseSMS(_ text: String) -> VisionBarcodeSMS {
        if text.lowercased().hasPrefix("smsto:") {
            let rest = String(text.dropFirst("smsto:".count))
            let parts = rest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let number = String(parts.first ?? "")
            let message = parts.count > 1 ? String(parts[1]) : nil
            return VisionBarcodeSMS(message: message, phoneNumber: number.isEmpty ? nil : number)
        }

        let rest = String(text.dropFirst("sms:".count))
        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let number = String(parts.first ?? "")
        var message: String?

        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if kv.count == 2, kv[0].lowercased() == "body" {
                    message = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                }
            }
        }

        return VisionBarcodeSMS(message: message, phoneNumber: number.isEmpty ? nil : number)
    }

    private static func parseGeo(_ text: String) -> VisionBarcodeGeoPoint? {
        let rest = String(text.dropFirst("geo:".count))
        let coordinates = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? rest
        let components = coordinates.split(separator: ",")
        guard components.count >= 2,
              let latitude = Double(String(components[0])),
              let longitude = Double(String(components[1])) else {
            return nil
        }
        return VisionBarcodeGeoPoint(latitude: latitude, longitude: longitude)
    }
}
