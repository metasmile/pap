//
// Created by BLACKGENE on 21.05.18.
// Copyright (c) 2018 Stells. All rights reserved.
//


//
//  FileIO.UTI.swift
//  fseventstool
//
//  Created by Matthias Keiser on 09.01.17.
//  Copyright © 2017 Tristan Inc. All rights reserved.

// https://github.com/mkeiser/SwiftUTI

/*
Modified history metasmile

added: public init(withURL url: URL, conformingTo conforming: UTI? = nil)
changed: class -> struct

*/

import Foundation

#if os(iOS) || os(watchOS)
import MobileCoreServices
#elseif os(macOS)
import CoreServices
#endif

/// Instances of the UTI class represent a specific Universal Type Identifier, e.g. kUTTypeMPEG4.

public struct UTI: RawRepresentable, Equatable {

    /**
    The TagClass enum represents the supported tag classes.

    - fileExtension: kUTTagClassFilenameExtension
    - mimeType: kUTTagClassMIMEType
    - pbType: kUTTagClassNSPboardType
    - osType: kUTTagClassOSType
    */
    public enum TagClass: String {

        /// Equivalent to kUTTagClassFilenameExtension
        case fileExtension = "public.filename-extension"

        /// Equivalent to kUTTagClassMIMEType
        case mimeType = "public.mime-type"

#if os (macOS)

        /// Equivalent to kUTTagClassNSPboardType
        case pbType =  "com.apple.nspboard-type"

        /// Equivalent to kUTTagClassOSType
        case osType =  "com.apple.ostype"
#endif

        /// Convenience variable for internal use.

        fileprivate var rawCFValue: CFString {
            return self.rawValue as CFString
        }
    }

    public typealias RawValue = String
    public let rawValue: String


    /// Convenience variable for internal use.

    private var rawCFValue: CFString {

        return self.rawValue as CFString
    }

    // MARK: Initialization


    /**

    This is the designated initializer of the UTI class.

     - Parameters:
            - rawValue: A string that is a Universal Type Identifier, i.e. "com.foobar.baz" or a constant like kUTTypeMP3.
     - Returns:
            An UTI instance representing the specified rawValue.
     - Note:
            You should rarely use this method. The preferred way to initialize a known UTI is to use its static variable (i.e. UTI.pdf). You should make an extension to make your own types available as static variables.

    */

    public init(rawValue: UTI.RawValue) {

        self.rawValue = rawValue
    }

    /**

    Initialize an UTI with a tag of a specified class.

    - Parameters:
        - tagClass: The class of the tag.
        - value: The value of the tag.
        - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An UTI instance representing the specified rawValue. If no known UTI with the specified tags is found, a dynamic UTI is created.
    - Note:
        You should rarely need this method. It's usually simpler to use one of the specialized initialzers like
        ```convenience init?(withExtension fileExtension: String, conformingTo conforming: UTI? = nil)```
    */

    public init(withTagClass tagClass: TagClass, value: String, conformingTo conforming: UTI? = nil) {

        let unmanagedIdentifier = UTTypeCreatePreferredIdentifierForTag(tagClass.rawCFValue, value as CFString, conforming?.rawCFValue)

        // UTTypeCreatePreferredIdentifierForTag only returns nil if the tag class is unknwown, which can't happen to us since we use an
        // enum of known values. Hence we can force-cast the result.

        let identifier = (unmanagedIdentifier?.takeRetainedValue() as String?)!

        self.init(rawValue: identifier)
    }

    /**

    Initialize an UTI with a file extension.

    - Parameters:
        - withExtension: The file extension (e.g. "txt").
        - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An UTI corresponding to the specified values.
    **/

    public init(withExtension fileExtension: String, conformingTo conforming: UTI? = nil) {

        self.init(withTagClass:.fileExtension, value: fileExtension, conformingTo: conforming)
    }

    /**

    Initialize an UTI with a file url.

    - Parameters:
        - withExtension: The file extension (e.g. "path/to/file.jpg").
        - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An UTI corresponding to the specified values.
    **/

    public init(withURL url: URL, conformingTo conforming: UTI? = nil) {

        self.init(withExtension:url.pathExtension, conformingTo: conforming)
    }

    /**

    Initialize an UTI with a MIME type.

    - Parameters:
        - mimeType: The MIME type (e.g. "text/plain").
        - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An UTI corresponding to the specified values.
    */

    public init(withMimeType mimeType: String, conformingTo conforming: UTI? = nil) {

        self.init(withTagClass:.mimeType, value: mimeType, conformingTo: conforming)
    }

#if os(macOS)

    /**

    Initialize an UTI with a pasteboard type.

    - Parameters:
        - pbType: The pasteboard type (e.g. NSPDFPboardType).
        - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An UTI corresponding to the specified values.
    */
    public init(withPBType pbType: String, conformingTo conforming: UTI? = nil) {

        self.init(withTagClass:.pbType, value: pbType, conformingTo: conforming)
    }

    /**
    Initialize an UTI with a OSType.

    - Parameters:
        - osType: The OSType type as a string (e.g. "PDF ").
        - conformingTo: If specified, the returned UTI must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An UTI corresponding to the specified values.
    - Note:
        You can use the variable ```OSType.string``` to get a string from an actual OSType.
    */

    public init(withOSType osType: String, conformingTo conforming: UTI? = nil) {

        self.init(withTagClass:.osType, value: osType, conformingTo: conforming)
    }

#endif

    // MARK: Accessing Tags

    /**

    Returns the tag with the specified class.

    - Parameters:
        - tagClass: The tag class to return.
    - Returns:
        The requested tag, or nil if there is no tag of the specified class.
    */

    public func tag(with tagClass: TagClass) -> String? {

        let unmanagedTag = UTTypeCopyPreferredTagWithClass(self.rawCFValue, tagClass.rawCFValue)

        guard let tag = unmanagedTag?.takeRetainedValue() as String? else {
            return nil
        }

        return tag
    }

    /// Return the file extension that corresponds the the UTI. Returns nil if not available.

    public var fileExtension: String? {

        return self.tag(with: .fileExtension)
    }

    /// Return the MIME type that corresponds the the UTI. Returns nil if not available.

    public var mimeType: String? {

        return self.tag(with: .mimeType)
    }

#if os(macOS)

    /// Return the pasteboard type that corresponds the the UTI. Returns nil if not available.

    public var pbType: String? {

        return self.tag(with: .pbType)
    }

    /// Return the OSType as a string that corresponds the the UTI. Returns nil if not available.
    /// - Note: you can use the ```init(with string: String)``` initializer to construct an actual OSType from the returnes string.

    public var osType: String? {

        return self.tag(with: .osType)
    }

#endif

    /**

    Returns all tags of the specified tag class.

    - Parameters:
        - tagClass: The class of the requested tags.
    - Returns:
        An array of all tags of the receiver of the specified class.
    */

    public func tags(with tagClass: TagClass) -> Array<String> {

        let unmanagedTags = UTTypeCopyAllTagsWithClass(self.rawCFValue, tagClass.rawCFValue)

        guard let tags = unmanagedTags?.takeRetainedValue() as? Array<CFString> else {
            return []
        }

        return tags as Array<String>
    }

    // MARK: List all UTIs associated with a tag


    /**
    Returns all UTIs that are associated with a specified tag.

    - Parameters:
      - tag: The class of the specified tag.
      - value: The value of the tag.
      - conforming: If specified, the returned UTIs must conform to this UTI. If nil is specified, this parameter is ignored. The default is nil.
    - Returns:
        An array of all UTIs that satisfy the specified parameters.
    */

    public static func utis(for tag: TagClass, value: String, conformingTo conforming: UTI? = nil) -> Array<UTI> {

        let unmanagedIdentifiers = UTTypeCreateAllIdentifiersForTag(tag.rawCFValue, value as CFString, conforming?.rawCFValue)


        guard let identifiers = unmanagedIdentifiers?.takeRetainedValue() as? Array<CFString> else {
            return []
        }

        return identifiers.compactMap { UTI(rawValue: $0 as String) }
    }

    // MARK: Equality and Conformance to other UTIs

    /**

    Checks if the receiver conforms to a specified UTI.

    - Parameters:
        - otherUTI: The UTI to which the receiver is compared.
    - Returns:
        ```true``` if the receiver conforms to the specified UTI, ```false```otherwise.
    */

    public func conforms(to otherUTI: UTI) -> Bool {

        return UTTypeConformsTo(self.rawCFValue, otherUTI.rawCFValue) as Bool
    }

    public static func ==(lhs: UTI, rhs: UTI) -> Bool {

        return UTTypeEqual(lhs.rawCFValue, rhs.rawCFValue) as Bool
    }

    // MARK: Accessing Information about an UTI

    /// Returns the localized, user-readable type description string associated with a uniform type identifier.

    public var description: String? {

        let unmanagedDescription = UTTypeCopyDescription(self.rawCFValue)

        guard let description = unmanagedDescription?.takeRetainedValue() as String? else {
            return nil
        }

        return description
    }

    /// Returns a uniform type’s declaration as a Dictionary, or nil if if no declaration for that type can be found.

    public var declaration: [AnyHashable:Any]? {

        let unmanagedDeclaration = UTTypeCopyDeclaration(self.rawCFValue)

        guard let declaration = unmanagedDeclaration?.takeRetainedValue() as? [AnyHashable:Any] else {
            return nil
        }

        return declaration
    }

    /// Returns the location of a bundle containing the declaration for a type, or nil if the bundle could not be located.

    public var declaringBundleURL: URL? {

        let unmanagedURL = UTTypeCopyDeclaringBundleURL(self.rawCFValue)

        guard let url = unmanagedURL?.takeRetainedValue() as URL? else {
            return nil
        }

        return url
    }

    /// Returns ```true``` if the receiver is a dynamic UTI.

    public var isDynamic: Bool {

        return UTTypeIsDynamic(self.rawCFValue)
    }
}


// MARK: System defined UTIs

public extension UTI {

    static       let  item                        =    UTI(rawValue:  "public.item")
    static       let  content                     =    UTI(rawValue:  "public.content")
    static       let  compositeContent            =    UTI(rawValue:  "public.composite-content")
    static       let  message                     =    UTI(rawValue:  "public.message")
    static       let  contact                     =    UTI(rawValue:  "public.contact")
    static       let  archive                     =    UTI(rawValue:  "public.archive")
    static       let  diskImage                   =    UTI(rawValue:  "public.disk-image")
    static       let  data                        =    UTI(rawValue:  "public.data")
    static       let  directory                   =    UTI(rawValue:  "public.directory")
    static       let  resolvable                  =    UTI(rawValue:  "com.apple.resolvable")
    static       let  symLink                     =    UTI(rawValue:  "public.symlink")
    static       let  executable                  =    UTI(rawValue:  "public.executable")
    static       let  mountPoint                  =    UTI(rawValue:  "com.apple.mount-point")
    static       let  aliasFile                   =    UTI(rawValue:  "com.apple.alias-file")
    static       let  aliasRecord                 =    UTI(rawValue:  "com.apple.alias-record")
    static       let  urlBookmarkData             =    UTI(rawValue:  "com.apple.bookmark")
    static       let  url                         =    UTI(rawValue:  "public.url")
    static       let  fileURL                     =    UTI(rawValue:  "public.file-url")
    static       let  text                        =    UTI(rawValue:  "public.text")
    static       let  plainText                   =    UTI(rawValue:  "public.plain-text")
    static       let  utf8PlainText               =    UTI(rawValue:  "public.utf8-plain-text")
    static       let  utf16ExternalPlainText      =    UTI(rawValue:  "public.utf16-external-plain-text")
    static       let  utf16PlainText              =    UTI(rawValue:  "public.utf16-plain-text")
    static       let  delimitedText               =    UTI(rawValue:  "public.delimited-values-text")
    static       let  commaSeparatedText          =    UTI(rawValue:  "public.comma-separated-values-text")
    static       let  tabSeparatedText            =    UTI(rawValue:  "public.tab-separated-values-text")
    static       let  utf8TabSeparatedText        =    UTI(rawValue:  "public.utf8-tab-separated-values-text")
    static       let  rtf                         =    UTI(rawValue:  "public.rtf")
    static       let  html                        =    UTI(rawValue:  "public.html")
    static       let  xml                         =    UTI(rawValue:  "public.xml")
    static       let  sourceCode                  =    UTI(rawValue:  "public.source-code")
    static       let  assemblyLanguageSource      =    UTI(rawValue:  "public.assembly-source")
    static       let  cSource                     =    UTI(rawValue:  "public.c-source")
    static       let  objectiveCSource            =    UTI(rawValue:  "public.objective-c-source")
    @available( OSX 10.11, iOS 9.0, * )
    static       let  swiftSource				  =    UTI(rawValue:  "public.swift-source")
    static       let  cPlusPlusSource             =    UTI(rawValue:  "public.c-plus-plus-source")
    static       let  objectiveCPlusPlusSource    =    UTI(rawValue:  "public.objective-c-plus-plus-source")
    static       let  cHeader                     =    UTI(rawValue:  "public.c-header")
    static       let  cPlusPlusHeader             =    UTI(rawValue:  "public.c-plus-plus-header")
    static       let  javaSource                  =    UTI(rawValue:  "com.sun.java-source")
    static       let  script                      =    UTI(rawValue:  "public.script")
    static       let  appleScript                 =    UTI(rawValue:  "com.apple.applescript.text")
    static       let  osaScript                   =    UTI(rawValue:  "com.apple.applescript.script")
    static       let  osaScriptBundle             =    UTI(rawValue:  "com.apple.applescript.script-bundle")
    static       let  javaScript                  =    UTI(rawValue:  "com.netscape.javascript-source")
    static       let  shellScript                 =    UTI(rawValue:  "public.shell-script")
    static       let  perlScript                  =    UTI(rawValue:  "public.perl-script")
    static       let  pythonScript                =    UTI(rawValue:  "public.python-script")
    static       let  rubyScript                  =    UTI(rawValue:  "public.ruby-script")
    static       let  phpScript                   =    UTI(rawValue:  "public.php-script")
    static       let  json                        =    UTI(rawValue:  "public.json")
    static       let  propertyList                =    UTI(rawValue:  "com.apple.property-list")
    static       let  xmlPropertyList             =    UTI(rawValue:  "com.apple.xml-property-list")
    static       let  binaryPropertyList          =    UTI(rawValue:  "com.apple.binary-property-list")
    static       let  pdf                         =    UTI(rawValue:  "com.adobe.pdf")
    static       let  rtfd                        =    UTI(rawValue:  "com.apple.rtfd")
    static       let  flatRTFD                    =    UTI(rawValue:  "com.apple.flat-rtfd")
    static       let  txnTextAndMultimediaData    =    UTI(rawValue:  "com.apple.txn.text-multimedia-data")
    static       let  webArchive                  =    UTI(rawValue:  "com.apple.webarchive")
    static       let  image                       =    UTI(rawValue:  "public.image")
    static       let  jpeg                        =    UTI(rawValue:  "public.jpeg")
    static       let  jpeg2000                    =    UTI(rawValue:  "public.jpeg-2000")
    static       let  tiff                        =    UTI(rawValue:  "public.tiff")
    static       let  pict                        =    UTI(rawValue:  "com.apple.pict")
    static       let  gif                         =    UTI(rawValue:  "com.compuserve.gif")
    static       let  png                         =    UTI(rawValue:  "public.png")
    static       let  quickTimeImage              =    UTI(rawValue:  "com.apple.quicktime-image")
    static       let  appleICNS                   =    UTI(rawValue:  "com.apple.icns")
    static       let  bmp                         =    UTI(rawValue:  "com.microsoft.bmp")
    static       let  ico                         =    UTI(rawValue:  "com.microsoft.ico")
    static       let  rawImage                    =    UTI(rawValue:  "public.camera-raw-image")
    static       let  scalableVectorGraphics      =    UTI(rawValue:  "public.svg-image")
    @available(OSX 10.12, iOS 9.1, watchOS 2.1, *)
    static       let  livePhoto					  =    UTI(rawValue:  "com.apple.live-photo")
    @available(OSX 10.12, iOS 9.1, *)
    static       let  audiovisualContent          =    UTI(rawValue:  "public.audiovisual-content")
    static       let  movie                       =    UTI(rawValue:  "public.movie")
    static       let  video                       =    UTI(rawValue:  "public.video")
    static       let  audio                       =    UTI(rawValue:  "public.audio")
    static       let  quickTimeMovie              =    UTI(rawValue:  "com.apple.quicktime-movie")
    static       let  mpeg                        =    UTI(rawValue:  "public.mpeg")
    static       let  mpeg2Video                  =    UTI(rawValue:  "public.mpeg-2-video")
    static       let  mpeg2TransportStream        =    UTI(rawValue:  "public.mpeg-2-transport-stream")
    static       let  mp3                         =    UTI(rawValue:  "public.mp3")
    static       let  mpeg4                       =    UTI(rawValue:  "public.mpeg-4")
    static       let  mpeg4Audio                  =    UTI(rawValue:  "public.mpeg-4-audio")
    static       let  appleProtectedMPEG4Audio    =    UTI(rawValue:  "com.apple.protected-mpeg-4-audio")
    static       let  appleProtectedMPEG4Video    =    UTI(rawValue:  "com.apple.protected-mpeg-4-video")
    static       let  aviMovie                    =    UTI(rawValue:  "public.avi")
    static       let  audioInterchangeFileFormat  =    UTI(rawValue:  "public.aiff-audio")
    static       let  waveformAudio               =    UTI(rawValue:  "com.microsoft.waveform-audio")
    static       let  midiAudio                   =    UTI(rawValue:  "public.midi-audio")
    static       let  playlist                    =    UTI(rawValue:  "public.playlist")
    static       let  m3UPlaylist                 =    UTI(rawValue:  "public.m3u-playlist")
    static       let  folder                      =    UTI(rawValue:  "public.folder")
    static       let  volume                      =    UTI(rawValue:  "public.volume")
    static       let  package                     =    UTI(rawValue:  "com.apple.package")
    static       let  bundle                      =    UTI(rawValue:  "com.apple.bundle")
    static       let  pluginBundle                =    UTI(rawValue:  "com.apple.plugin")
    static       let  spotlightImporter           =    UTI(rawValue:  "com.apple.metadata-importer")
    static       let  quickLookGenerator          =    UTI(rawValue:  "com.apple.quicklook-generator")
    static       let  xpcService                  =    UTI(rawValue:  "com.apple.xpc-service")
    static       let  framework                   =    UTI(rawValue:  "com.apple.framework")
    static       let  application                 =    UTI(rawValue:  "com.apple.application")
    static       let  applicationBundle           =    UTI(rawValue:  "com.apple.application-bundle")
    static       let  applicationFile             =    UTI(rawValue:  "com.apple.application-file")
    static       let  unixExecutable              =    UTI(rawValue:  "public.unix-executable")
    static       let  windowsExecutable           =    UTI(rawValue:  "com.microsoft.windows-executable")
    static       let  javaClass                   =    UTI(rawValue:  "com.sun.java-class")
    static       let  javaArchive                 =    UTI(rawValue:  "com.sun.java-archive")
    static       let  systemPreferencesPane       =    UTI(rawValue:  "com.apple.systempreference.prefpane")
    static       let  gnuZipArchive               =    UTI(rawValue:  "org.gnu.gnu-zip-archive")
    static       let  bzip2Archive                =    UTI(rawValue:  "public.bzip2-archive")
    static       let  zipArchive                  =    UTI(rawValue:  "public.zip-archive")
    static       let  spreadsheet                 =    UTI(rawValue:  "public.spreadsheet")
    static       let  presentation                =    UTI(rawValue:  "public.presentation")
    static       let  database                    =    UTI(rawValue:  "public.database")
    static       let  vCard                       =    UTI(rawValue:  "public.vcard")
    static       let  toDoItem                    =    UTI(rawValue:  "public.to-do-item")
    static       let  calendarEvent               =    UTI(rawValue:  "public.calendar-event")
    static       let  emailMessage                =    UTI(rawValue:  "public.email-message")
    static       let  internetLocation            =    UTI(rawValue:  "com.apple.internet-location")
    static       let  inkText                     =    UTI(rawValue:  "com.apple.ink.inktext")
    static       let  font                        =    UTI(rawValue:  "public.font")
    static       let  bookmark                    =    UTI(rawValue:  "public.bookmark")
    static       let  _3DContent                  =    UTI(rawValue:  "public.3d-content")
    static       let  pkcs12                      =    UTI(rawValue:  "com.rsa.pkcs-12")
    static       let  x509Certificate             =    UTI(rawValue:  "public.x509-certificate")
    static       let  electronicPublication       =    UTI(rawValue:  "org.idpf.epub-container")
    static       let  log                         =    UTI(rawValue:  "public.log")
}

#if os(OSX)

extension OSType {


    /// Returns the OSType encoded as a String.

    var string: String {

        let unmanagedString = UTCreateStringForOSType(self)

        return unmanagedString.takeRetainedValue() as String
    }


    /// Initializes a OSType from a String.
    ///
    /// - Parameter string: A String representing an OSType.

    init(with string: String) {

        self = UTGetOSTypeFromString(string as CFString)
    }
}

#endif
