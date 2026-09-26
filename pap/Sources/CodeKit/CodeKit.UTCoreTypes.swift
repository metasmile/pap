//
// Created by BLACKGENE on 03/05/2018.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation

public struct UTCoreTypes {

/*
     File:       UTCoreTypes.h

     Contains:   String constants for core uniform type identifiers

     Copyright:  (c) 2004-2012 by Apple Inc. All rights reserved.

     Bugs?:      For bug reports, consult the following page on
                 the World Wide Web:

                     http://developer.apple.com/bugreporter/

*/

/*
 *  kUTTypeItem
 *
 *    generic base type for most things
 *    (files, directories)
 *
 *    UTI: public.item
 *
 *
 *  kUTTypeContent
 *
 *    base type for anything containing user-viewable document content
 *    (documents, pasteboard data, and document packages.) Types describing
 *    files or packages must also conform to kUTTypeData or kUTTypePackage
 *    in order for the system to bind documents to them.
 *
 *    UTI: public.content
 *
 *
 *  kUTTypeCompositeContent
 *
 *    base type for content formats supporting mixed embedded content
 *    (i.e., compound documents)
 *
 *    UTI: public.composite-content
 *    conforms to: public.content
 *
 *
 *  kUTTypeMessage
 *
 *    base type for messages (email, IM, etc.)
 *
 *    UTI: public.message
 *
 *
 *  kUTTypeContact
 *
 *    contact information, e.g. for a person, group, organization
 *
 *    UTI: public.contact
 *
 *
 *  kUTTypeArchive
 *
 *    an archive of files and directories
 *
 *    UTI: public.archive
 *
 *
 *  kUTTypeDiskImage
 *
 *    a data item mountable as a volume
 *
 *    UTI: public.disk-image
 *
 */
    @available(iOS 3.0, *)
    static var Item:String { return "public.item" }
    @available(iOS 3.0, *)
    static var Content:String { return "public.content" }
    @available(iOS 3.0, *)
    static var CompositeContent:String { return "public.composite-content" }
    @available(iOS 3.0, *)
    static var Message:String { return "public.message" }
    @available(iOS 3.0, *)
    static var Contact:String { return "public.contact" }
    @available(iOS 3.0, *)
    static var Archive:String { return "public.archive" }
    @available(iOS 3.0, *)
    static var DiskImage:String { return "public.disk-image" }

/*
 *  kUTTypeData
 *
 *    base type for any sort of simple byte stream,
 *    including files and in-memory data
 *
 *    UTI: public.data
 *    conforms to: public.item
 *
 *
 *  kUTTypeDirectory
 *
 *    file system directory
 *    (includes packages AND folders)
 *
 *    UTI: public.directory
 *    conforms to: public.item
 *
 *
 *  kUTTypeResolvable
 *
 *    symlink and alias file types conform to this UTI
 *
 *    UTI: com.apple.resolvable
 *
 *
 *  kUTTypeSymLink
 *
 *    a symbolic link
 *
 *    UTI: public.symlink
 *    conforms to: public.item, com.apple.resolvable
 *
 *
 *  kUTTypeExecutable
 *
 *    an executable item
 *    UTI: public.executable
 *    conforms to: public.item
 *
 *
 *  kUTTypeMountPoint
 *
 *    a volume mount point (resolvable, resolves to the root dir of a volume)
 *
 *    UTI: com.apple.mount-point
 *    conforms to: public.item, com.apple.resolvable
 *
 *
 *  kUTTypeAliasFile
 *
 *    a fully-formed alias file
 *
 *    UTI: com.apple.alias-file
 *    conforms to: public.data, com.apple.resolvable
 *
 *
 *  kUTTypeAliasRecord
 *
 *    raw alias data
 *
 *    UTI: com.apple.alias-record
 *    conforms to: public.data, com.apple.resolvable
 *
 *
 *  kUTTypeURLBookmarkData
 *
 *    URL bookmark
 *
 *    UTI: com.apple.bookmark
 *    conforms to: public.data, com.apple.resolvable
 *
 */
    @available(iOS 3.0, *)
    static var Data:String { return "public.data" }
    @available(iOS 3.0, *)
    static var Directory:String { return "public.directory" }
    @available(iOS 3.0, *)
    static var Resolvable:String { return "com.apple.resolvable" }
    @available(iOS 3.0, *)
    static var SymLink:String { return "public.symlink" }
    @available(iOS 8.0, *)
    static var Executable:String { return "public.executable" }
    @available(iOS 3.0, *)
    static var MountPoint:String { return "com.apple.mount-point" }
    @available(iOS 3.0, *)
    static var AliasFile:String { return "com.apple.alias-file" }
    @available(iOS 3.0, *)
    static var AliasRecord:String { return "com.apple.alias-record" }
    @available(iOS 8.0, *)
    static var URLBookmarkData:String { return "com.apple.bookmark" }

/*
 *  kUTTypeURL
 *
 *    The bytes of a URL
 *    (OSType 'url ')
 *
 *    UTI: public.url
 *    conforms to: public.data
 *
 *
 *  kUTTypeFileURL
 *
 *    The text of a "file:" URL
 *    (OSType 'furl')
 *
 *    UTI: public.file-url
 *    conforms to: public.url
 *
 */
    @available(iOS 3.0, *)
    static var URL:String { return "public.url" }
    @available(iOS 3.0, *)
    static var FileURL:String { return "public.file-url" }

/*
 *  kUTTypeText
 *
 *    base type for all text-encoded data,
 *    including text with markup (HTML, RTF, etc.)
 *
 *    UTI: public.text
 *    conforms to: public.data, public.content
 *
 *
 *  kUTTypePlainText
 *
 *    text with no markup, unspecified encoding
 *
 *    UTI: public.plain-text
 *    conforms to: public.text
 *
 *
 *  kUTTypeUTF8PlainText
 *
 *    plain text, UTF-8 encoding
 *    (OSType 'utf8', NSPasteboardType "NSStringPBoardType")
 *
 *    UTI: public.utf8-plain-text
 *    conforms to: public.plain-text
 *
 *
 *  kUTTypeUTF16ExternalPlainText
 *
 *    plain text, UTF-16 encoding, with BOM, or if BOM
 *    is not present, has "external representation"
 *    byte order (big-endian).
 *    (OSType 'ut16')
 *
 *    UTI: public.utf16-external-plain-text
 *    conforms to: public.plain-text
 *
 *
 *  kUTTypeUTF16PlainText
 *
 *    plain text, UTF-16 encoding, native byte order, optional BOM
 *    (OSType 'utxt')
 *
 *    UTI: public.utf16-plain-text
 *    conforms to: public.plain-text
 *
 *
 *  kUTTypeDelimitedText
 *
 *    text containing delimited values
 *
 *    UTI: public.delimited-values-text
 *    conforms to: public.text
 *
 *
 *  kUTTypeCommaSeparatedText
 *
 *    text containing comma-separated values (.csv)
 *
 *    UTI: public.comma-separated-values-text
 *    conforms to: public.delimited-values-text
 *
 *
 *  kUTTypeTabSeparatedText
 *
 *    text containing tab-separated values
 *
 *    UTI: public.tab-separated-values-text
 *    conforms to: public.delimited-values-text
 *
 *
 *  kUTTypeUTF8TabSeparatedText
 *
 *    UTF-8 encoded text containing tab-separated values
 *
 *    UTI: public.utf8-tab-separated-values-text
 *    conforms to: public.tab-separated-values-text, public.utf8-plain-text
 *
 *
 *  kUTTypeRTF
 *
 *    Rich Text Format
 *
 *    UTI: public.rtf
 *    conforms to: public.text
 *
 */
    @available(iOS 3.0, *)
    static var Text:String { return "public.text" }
    @available(iOS 3.0, *)
    static var PlainText:String { return "public.plain-text" }
    @available(iOS 3.0, *)
    static var UTF8PlainText:String { return "public.utf8-plain-text" }
    @available(iOS 3.0, *)
    static var UTF16ExternalPlainText:String { return "public.utf16-external-plain-text" }
    @available(iOS 3.0, *)
    static var UTF16PlainText:String { return "public.utf16-plain-text" }
    @available(iOS 8.0, *)
    static var DelimitedText:String { return "public.delimited-values-text" }
    @available(iOS 8.0, *)
    static var CommaSeparatedText:String { return "public.comma-separated-values-text" }
    @available(iOS 8.0, *)
    static var TabSeparatedText:String { return "public.tab-separated-values-text" }
    @available(iOS 8.0, *)
    static var UTF8TabSeparatedText:String { return "public.utf8-tab-separated-values-text" }
    @available(iOS 3.0, *)
    static var RTF:String { return "public.rtf" }

/*
 *  kUTTypeHTML
 *
 *    HTML, any version
 *
 *    UTI: public.html
 *    conforms to: public.text
 *
 *
 *  kUTTypeXML
 *
 *    generic XML
 *
 *    UTI: public.xml
 *    conforms to: public.text
 *
 */
    @available(iOS 3.0, *)
    static var HTML:String { return "public.html" }
    @available(iOS 3.0, *)
    static var XML:String { return "public.xml" }

/*
 *  kUTTypeSourceCode
 *
 *    abstract type for source code (any language)
 *
 *    UTI: public.source-code
 *    conforms to: public.plain-text
 *
 *
 *  kUTTypeAssemblyLanguageSource
 *
 *    assembly language source (.s)
 *
 *    UTI: public.assembly-source
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeCSource
 *
 *    C source code (.c)
 *
 *    UTI: public.c-source
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeObjectiveCSource
 *
 *    Objective-C source code (.m)
 *
 *    UTI: public.objective-c-source
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeSwiftSource
 *
 *    Swift source code (.swift)
 *
 *    UTI: public.swift-source
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeCPlusPlusSource
 *
 *    C++ source code (.cp, etc.)
 *
 *    UTI: public.c-plus-plus-source
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeObjectiveCPlusPlusSource
 *
 *    Objective-C++ source code
 *
 *    UTI: public.objective-c-plus-plus-source
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeCHeader
 *
 *    C header
 *
 *    UTI: public.c-header
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeCPlusPlusHeader
 *
 *    C++ header
 *
 *    UTI: public.c-plus-plus-header
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeJavaSource
 *
 *    Java source code
 *
 *    UTI: com.sun.java-source
 *    conforms to: public.source-code
 *
 */
    @available(iOS 3.0, *)
    static var SourceCode:String { return "public.source-code" }
    @available(iOS 8.0, *)
    static var AssemblyLanguageSource:String { return "public.assembly-source" }
    @available(iOS 3.0, *)
    static var CSource:String { return "public.c-source" }
    @available(iOS 3.0, *)
    static var ObjectiveCSource:String { return "public.objective-c-source" }
    @available(iOS 9.0, *)
    static var SwiftSource:String { return "public.swift-source" }
    @available(iOS 3.0, *)
    static var CPlusPlusSource:String { return "public.c-plus-plus-source" }
    @available(iOS 3.0, *)
    static var ObjectiveCPlusPlusSource:String { return "public.objective-c-plus-plus-source" }
    @available(iOS 3.0, *)
    static var CHeader:String { return "public.c-header" }
    @available(iOS 3.0, *)
    static var CPlusPlusHeader:String { return "public.c-plus-plus-header" }
    @available(iOS 3.0, *)
    static var JavaSource:String { return "com.sun.java-source" }

/*
 *  kUTTypeScript
 *
 *    scripting language source
 *
 *    UTI: public.script
 *    conforms to: public.source-code
 *
 *
 *  kUTTypeAppleScript
 *
 *    AppleScript text format (.applescript)
 *
 *    UTI: com.apple.applescript.text
 *    conforms to: public.script
 *
 *
 *  kUTTypeOSAScript
 *
 *    Open Scripting Architecture script binary format (.scpt)
 *
 *    UTI: com.apple.applescript.script
 *    conforms to: public.data, public.script
 *
 *
 *  kUTTypeOSAScriptBundle
 *
 *    Open Scripting Architecture script bundle format (.scptd)
 *
 *    UTI: com.apple.applescript.script-bundle
 *    conforms to: com.apple.bundle, com.apple.package, public.script
 *
 *
 *  kUTTypeJavaScript
 *
 *    JavaScript source code
 *
 *    UTI: com.netscape.javascript-source
 *    conforms to: public.source-code, public.executable
 *
 *
 *  kUTTypeShellScript
 *
 *    base type for shell scripts
 *
 *    UTI: public.shell-script
 *    conforms to: public.script
 *
 *
 *  kUTTypePerlScript
 *
 *    Perl script
 *
 *    UTI: public.perl-script
 *    conforms to: public.shell-script
 *
 *
 *  kUTTypePythonScript
 *
 *    Python script
 *
 *    UTI: public.python-script
 *    conforms to: public.shell-script
 *
 *
 *  kUTTypeRubyScript
 *
 *    Ruby script
 *
 *    UTI: public.ruby-script
 *    conforms to: public.shell-script
 *
 *
 *  kUTTypePHPScript
 *
 *    PHP script
 *
 *    UTI: public.php-script
 *    conforms to: public.shell-script
 *
 */
    @available(iOS 8.0, *)
    static var Script:String { return "public.script" }
    @available(iOS 8.0, *)
    static var AppleScript:String { return "com.apple.applescript.text" }
    @available(iOS 8.0, *)
    static var OSAScript:String { return "com.apple.applescript.script" }
    @available(iOS 8.0, *)
    static var OSAScriptBundle:String { return "com.apple.applescript.script-bundle" }
    @available(iOS 8.0, *)
    static var JavaScript:String { return "com.netscape.javascript-source" }
    @available(iOS 8.0, *)
    static var ShellScript:String { return "public.shell-script" }
    @available(iOS 8.0, *)
    static var PerlScript:String { return "public.perl-script" }
    @available(iOS 8.0, *)
    static var PythonScript:String { return "public.python-script" }
    @available(iOS 8.0, *)
    static var RubyScript:String { return "public.ruby-script" }
    @available(iOS 8.0, *)
    static var PHPScript:String { return "public.php-script" }

/*
 *  kUTTypeJSON
 *
 *    JavaScript object notation (JSON) data
 *    NOTE: JSON almost but doesn't quite conform to
 *    com.netscape.javascript-source
 *
 *    UTI: public.json
 *    conforms to: public.text
 *
 *
 *  kUTTypePropertyList
 *
 *    base type for property lists
 *
 *    UTI: com.apple.property-list
 *    conforms to: public.data
 *
 *
 *  kUTTypeXMLPropertyList
 *
 *    XML property list
 *
 *    UTI: com.apple.xml-property-list
 *    conforms to: public.xml, com.apple.property-list
 *
 *
 *  kUTTypeBinaryPropertyList
 *
 *    XML property list
 *
 *    UTI: com.apple.binary-property-list
 *    conforms to: com.apple.property-list
 *
 */
    @available(iOS 8.0, *)
    static var JSON:String { return "public.json" }
    @available(iOS 8.0, *)
    static var PropertyList:String { return "com.apple.property-list" }
    @available(iOS 8.0, *)
    static var XMLPropertyList:String { return "com.apple.xml-property-list" }
    @available(iOS 8.0, *)
    static var BinaryPropertyList:String { return "com.apple.binary-property-list" }

/*
 *  kUTTypePDF
 *
 *    Adobe PDF
 *
 *    UTI: com.adobe.pdf
 *    conforms to: public.data, public.composite-content
 *
 *
 *  kUTTypeRTFD
 *
 *    Rich Text Format Directory
 *    (RTF with content embedding, on-disk format)
 *
 *    UTI: com.apple.rtfd
 *    conforms to: com.apple.package, public.composite-content
 *
 *
 *  kUTTypeFlatRTFD
 *
 *    Flattened RTFD (pasteboard format)
 *
 *    UTI: com.apple.flat-rtfd
 *    conforms to: public.data, public.composite-content
 *
 *
 *  kUTTypeTXNTextAndMultimediaData
 *
 *    MLTE (Textension) format for mixed text & multimedia data
 *    (OSType 'txtn')
 *
 *    UTI: com.apple.txn.text-multimedia-data
 *    conforms to: public.data, public.composite-content
 *
 *
 *  kUTTypeWebArchive
 *
 *    The WebKit webarchive format
 *
 *    UTI: com.apple.webarchive
 *    conforms to: public.data, public.composite-content
 */
    @available(iOS 3.0, *)
    static var PDF:String { return "com.adobe.pdf" }
    @available(iOS 3.0, *)
    static var RTFD:String { return "com.apple.rtfd" }
    @available(iOS 3.0, *)
    static var FlatRTFD:String { return "com.apple.flat-rtfd" }
    @available(iOS 3.0, *)
    static var TXNTextAndMultimediaData:String { return "com.apple.txn.text-multimedia-data" }
    @available(iOS 3.0, *)
    static var WebArchive:String { return "com.apple.webarchive" }

/*
 *  kUTTypeImage
 *
 *    abstract image data
 *
 *    UTI: public.image
 *    conforms to: public.data, public.content
 *
 *
 *  kUTTypeJPEG
 *
 *    JPEG image
 *
 *    UTI: public.jpeg
 *    conforms to: public.image
 *
 *
 *  kUTTypeJPEG2000
 *
 *    JPEG-2000 image
 *
 *    UTI: public.jpeg-2000
 *    conforms to: public.image
 *
 *
 *  kUTTypeTIFF
 *
 *    TIFF image
 *
 *    UTI: public.tiff
 *    conforms to: public.image
 *
 *
 *  kUTTypePICT
 *
 *    Quickdraw PICT format
 *
 *    UTI: com.apple.pict
 *    conforms to: public.image
 *
 *
 *  kUTTypeGIF
 *
 *    GIF image
 *
 *    UTI: com.compuserve.gif
 *    conforms to: public.image
 *
 *
 *  kUTTypePNG
 *
 *    PNG image
 *
 *    UTI: public.png
 *    conforms to: public.image
 *
 *
 *  kUTTypeQuickTimeImage
 *
 *    QuickTime image format (OSType 'qtif')
 *
 *    UTI: com.apple.quicktime-image
 *    conforms to: public.image
 *
 *
 *  kUTTypeAppleICNS
 *
 *    Apple icon data
 *
 *    UTI: com.apple.icns
 *    conforms to: public.image
 *
 *
 *  kUTTypeBMP
 *
 *    Windows bitmap
 *
 *    UTI: com.microsoft.bmp
 *    conforms to: public.image
 *
 *
 *  kUTTypeICO
 *
 *    Windows icon data
 *
 *    UTI: com.microsoft.ico
 *    conforms to: public.image
 *
 *
 *  kUTTypeRawImage
 *
 *    base type for raw image data (.raw)
 *
 *    UTI: public.camera-raw-image
 *    conforms to: public.image
 *
 *
 *  kUTTypeScalableVectorGraphics
 *
 *    SVG image
 *
 *    UTI: public.svg-image
 *    conforms to: public.image
 *
 *  kUTTypeLivePhoto
 *
 *    Live Photo
 *
 *    UTI: com.apple.live-photo
 *
 *
 */
    @available(iOS 3.0, *)
    static var Image:String { return "public.image" }
    @available(iOS 3.0, *)
    static var JPEG:String { return "public.jpeg" }
    @available(iOS 3.0, *)
    static var JPEG2000:String { return "public.jpeg-2000" }
    @available(iOS 3.0, *)
    static var TIFF:String { return "public.tiff" }
    @available(iOS 3.0, *)
    static var PICT:String { return "com.apple.pict" }
    @available(iOS 3.0, *)
    static var GIF:String { return "com.compuserve.gif" }
    @available(iOS 3.0, *)
    static var PNG:String { return "public.png" }
    @available(iOS 3.0, *)
    static var QuickTimeImage:String { return "com.apple.quicktime-image" }
    @available(iOS 3.0, *)
    static var AppleICNS:String { return "com.apple.icns" }
    @available(iOS 3.0, *)
    static var BMP:String { return "com.microsoft.bmp" }
    @available(iOS 3.0, *)
    static var ICO:String { return "com.microsoft.ico" }
    @available(iOS 8.0, *)
    static var RawImage:String { return "public.camera-raw-image" }
    @available(iOS 8.0, *)
    static var ScalableVectorGraphics:String { return "public.svg-image" }
    @available(iOS 9.1, *)
    static var LivePhoto:String { return "com.apple.live-photo" }

/*
 *  kUTTypeAudiovisualContent
 *
 *    audio and/or video content
 *
 *    UTI: public.audiovisual-content
 *    conforms to: public.data, public.content
 *
 *
 *  kUTTypeMovie
 *
 *    A media format which may contain both video and audio
 *    Corresponds to what users would label a "movie"
 *
 *    UTI: public.movie
 *    conforms to: public.audiovisual-content
 *
 *
 *  kUTTypeVideo
 *
 *    pure video (no audio)
 *
 *    UTI: public.video
 *    conforms to: public.movie
 *
 *
 *  kUTTypeAudio
 *
 *    pure audio (no video)
 *
 *    UTI: public.audio
 *    conforms to: public.audiovisual-content
 *
 *
 *  kUTTypeQuickTimeMovie
 *
 *    QuickTime movie
 *
 *    UTI: com.apple.quicktime-movie
 *    conforms to: public.movie
 *
 *
 *  kUTTypeMPEG
 *
 *    MPEG-1 or MPEG-2 movie
 *
 *    UTI: public.mpeg
 *    conforms to: public.movie
 *
 *
 *  kUTTypeMPEG2Video
 *
 *    MPEG-2 video
 *
 *    UTI: public.mpeg-2-video
 *    conforms to: public.video
 *
 *
 *  kUTTypeMPEG2TransportStream
 *
 *    MPEG-2 Transport Stream movie format
 *
 *    UTI: public.mpeg-2-transport-stream
 *    conforms to: public.movie
 *
 *
 *  kUTTypeMP3
 *
 *    MP3 audio
 *
 *    UTI: public.mp3
 *    conforms to: public.audio
 *
 *
 *  kUTTypeMPEG4
 *
 *    MPEG-4 movie
 *
 *    UTI: public.mpeg-4
 *    conforms to: public.movie
 *
 *
 *  kUTTypeMPEG4Audio
 *
 *    MPEG-4 audio layer
 *
 *    UTI: public.mpeg-4-audio
 *    conforms to: public.mpeg-4, public.audio
 *
 *
 *  kUTTypeAppleProtectedMPEG4Audio
 *
 *    Apple protected MPEG4 format
 *    (.m4p, iTunes music store format)
 *
 *    UTI: com.apple.protected-mpeg-4-audio
 *    conforms to: public.audio
 *
 *
 *  kUTTypeAppleProtectedMPEG4Video
 *
 *    Apple protected MPEG-4 movie
 *
 *    UTI: com.apple.protected-mpeg-4-video
 *    conforms to: com.apple.m4v-video
 *
 *
 *  kUTTypeAVIMovie
 *
 *    Audio Video Interleaved (AVI) movie format
 *
 *    UTI: public.avi
 *    conforms to: public.movie
 *
 *
 *  kUTTypeAudioInterchangeFileFormat
 *
 *    AIFF audio format
 *
 *    UTI: public.aiff-audio
 *    conforms to: public.aifc-audio
 *
 *
 *  kUTTypeWaveformAudio
 *
 *    Waveform audio format (.wav)
 *
 *    UTI: com.microsoft.waveform-audio
 *    conforms to: public.audio
 *
 *
 *  kUTTypeMIDIAudio
 *
 *    MIDI audio format
 *
 *    UTI: public.midi-audio
 *    conforms to: public.audio
 *
 *
 */
    @available(iOS 3.0, *)
    static var AudiovisualContent:String { return "public.audiovisual-content" }
    @available(iOS 3.0, *)
    static var Movie:String { return "public.movie" }
    @available(iOS 3.0, *)
    static var Video:String { return "public.video" }
    @available(iOS 3.0, *)
    static var Audio:String { return "public.audio" }
    @available(iOS 3.0, *)
    static var QuickTimeMovie:String { return "com.apple.quicktime-movie" }
    @available(iOS 3.0, *)
    static var MPEG:String { return "public.mpeg" }
    @available(iOS 8.0, *)
    static var MPEG2Video:String { return "public.mpeg-2-video" }
    @available(iOS 8.0, *)
    static var MPEG2TransportStream:String { return "public.mpeg-2-transport-stream" }
    @available(iOS 3.0, *)
    static var MP3:String { return "public.mp3" }
    @available(iOS 3.0, *)
    static var MPEG4:String { return "public.mpeg-4" }
    @available(iOS 3.0, *)
    static var MPEG4Audio:String { return "public.mpeg-4-audio" }
    @available(iOS 3.0, *)
    static var AppleProtectedMPEG4Audio:String { return "com.apple.protected-mpeg-4-audio" }
    @available(iOS 8.0, *)
    static var AppleProtectedMPEG4Video:String { return "com.apple.protected-mpeg-4-video" }
    @available(iOS 8.0, *)
    static var AVIMovie:String { return "public.avi" }
    @available(iOS 8.0, *)
    static var AudioInterchangeFileFormat:String { return "public.aiff-audio" }
    @available(iOS 8.0, *)
    static var WaveformAudio:String { return "com.microsoft.waveform-audio" }
    @available(iOS 8.0, *)
    static var MIDIAudio:String { return "public.midi-audio" }

/*
 *  kUTTypePlaylist
 *
 *    base type for playlists
 *
 *    UTI: public.playlist
 *
 *
 *  kUTTypeM3UPlaylist
 *
 *    M3U or M3U8 playlist
 *
 *    UTI: public.m3u-playlist
 *    conforms to: public.text, public.playlist
 *
 */
    @available(iOS 8.0, *)
    static var Playlist:String { return "public.playlist" }
    @available(iOS 8.0, *)
    static var M3UPlaylist:String { return "public.m3u-playlist" }

/*
 *  kUTTypeFolder
 *
 *    a user-browsable directory (i.e., not a package)
 *
 *    UTI: public.folder
 *    conforms to: public.directory
 *
 *
 *  kUTTypeVolume
 *
 *    the root folder of a volume/mount point
 *
 *    UTI: public.volume
 *    conforms to: public.folder
 *
 *
 *  kUTTypePackage
 *
 *    a packaged directory
 *
 *    UTI: com.apple.package
 *    conforms to: public.directory
 *
 *
 *  kUTTypeBundle
 *
 *    a directory conforming to one of the CFBundle layouts
 *
 *    UTI: com.apple.bundle
 *    conforms to: public.directory
 *
 *
 *  kUTTypePluginBundle
 *
 *    base type for bundle-based plugins
 *
 *    UTI: com.apple.plugin
 *    conforms to: com.apple.bundle, com.apple.package
 *
 *
 *  kUTTypeSpotlightImporter
 *
 *    a Spotlight metadata importer
 *
 *    UTI: com.apple.metadata-importer
 *    conforms to: com.apple.plugin
 *
 *
 *  kUTTypeQuickLookGenerator
 *
 *    a QuickLook preview generator
 *
 *    UTI: com.apple.quicklook-generator
 *    conforms to: com.apple.plugin
 *
 *
 *  kUTTypeXPCService
 *
 *    an XPC service
 *
 *    UTI: com.apple.xpc-service
 *    conforms to: com.apple.bundle, com.apple.package
 *
 *
 *  kUTTypeFramework
 *
 *    a Mac OS X framework
 *
 *    UTI: com.apple.framework
 *    conforms to: com.apple.bundle
 *
 */
    @available(iOS 3.0, *)
    static var Folder:String { return "public.folder" }
    @available(iOS 3.0, *)
    static var Volume:String { return "public.volume" }
    @available(iOS 3.0, *)
    static var Package:String { return "com.apple.package" }
    @available(iOS 3.0, *)
    static var Bundle:String { return "com.apple.bundle" }
    @available(iOS 8.0, *)
    static var PluginBundle:String { return "com.apple.plugin" }
    @available(iOS 8.0, *)
    static var SpotlightImporter:String { return "com.apple.metadata-importer" }
    @available(iOS 8.0, *)
    static var QuickLookGenerator:String { return "com.apple.quicklook-generator" }
    @available(iOS 8.0, *)
    static var XPCService:String { return "com.apple.xpc-service" }
    @available(iOS 3.0, *)
    static var Framework:String { return "com.apple.framework" }

/*
 *  kUTTypeApplication
 *
 *    base type for OS X applications, launchable items
 *
 *    UTI: com.apple.application
 *    conforms to: public.executable
 *
 *
 *  kUTTypeApplicationBundle
 *
 *    a bundled application
 *
 *    UTI: com.apple.application-bundle
 *    conforms to: com.apple.application, com.apple.bundle, com.apple.package
 *
 *
 *  kUTTypeApplicationFile
 *
 *    a single-file Carbon/Classic application
 *
 *    UTI: com.apple.application-file
 *    conforms to: com.apple.application, public.data
 *
 *
 *  kUTTypeUnixExecutable
 *
 *    a UNIX executable (flat file)
 *
 *    UTI: public.unix-executable
 *    conforms to: public.data, public.executable
 *
 *
 *  kUTTypeWindowsExecutable
 *
 *    a Windows executable (.exe files)
 *
 *    UTI: com.microsoft.windows-executable
 *    conforms to: public.data, public.executable
 *
 *
 *  kUTTypeJavaClass
 *
 *    a Java class
 *
 *    UTI: com.sun.java-class
 *    conforms to: public.data, public.executable
 *
 *
 *  kUTTypeJavaArchive
 *
 *    a Java archive (.jar)
 *
 *    UTI: com.sun.java-archive
 *    conforms to: public.zip-archive, public.executable
 *
 *
 *  kUTTypeSystemPreferencesPane
 *
 *    a System Preferences pane
 *
 *    UTI: com.apple.systempreference.prefpane
 *    conforms to: com.apple.package, com.apple.bundle
 *
 */
// Abstract executable types
    @available(iOS 3.0, *)
    static var Application:String { return "com.apple.application" }
    @available(iOS 3.0, *)
    static var ApplicationBundle:String { return "com.apple.application-bundle" }
    @available(iOS 3.0, *)
    static var ApplicationFile:String { return "com.apple.application-file" }
    @available(iOS 8.0, *)
    static var UnixExecutable:String { return "public.unix-executable" }

// Other platform binaries
    @available(iOS 8.0, *)
    static var WindowsExecutable:String { return "com.microsoft.windows-executable" }
    @available(iOS 8.0, *)
    static var JavaClass:String { return "com.sun.java-class" }
    @available(iOS 8.0, *)
    static var JavaArchive:String { return "com.sun.java-archive" }

// Misc. binaries
    @available(iOS 8.0, *)
    static var SystemPreferencesPane:String { return "com.apple.systempreference.prefpane" }

/*
 *  kUTTypeGNUZipArchive
 *
 *    a GNU zip archive (gzip)
 *
 *    UTI: org.gnu.gnu-zip-archive
 *    conforms to: public.data, public.archive
 *
 *
 *  kUTTypeBzip2Archive
 *
 *    a bzip2 archive (.bz2)
 *
 *    UTI: public.bzip2-archive
 *    conforms to: public.data, public.archive
 *
 *
 *  kUTTypeZipArchive
 *
 *    a zip archive
 *
 *    UTI: public.zip-archive
 *    conforms to: com.pkware.zip-archive
 *
 */
    @available(iOS 8.0, *)
    static var GNUZipArchive:String { return "org.gnu.gnu-zip-archive" }
    @available(iOS 8.0, *)
    static var Bzip2Archive:String { return "public.bzip2-archive" }
    @available(iOS 8.0, *)
    static var ZipArchive:String { return "public.zip-archive" }

/*
 *  kUTTypeSpreadsheet
 *
 *    base spreadsheet document type
 *
 *    UTI: public.spreadsheet
 *    conforms to: public.content
 *
 *
 *  kUTTypePresentation
 *
 *    base presentation document type
 *
 *    UTI: public.presentation
 *    conforms to: public.composite-content
 *
 *
 *  kUTTypeDatabase
 *
 *    a database store
 *
 *    UTI: public.database
 *
 */
    @available(iOS 8.0, *)
    static var Spreadsheet:String { return "public.spreadsheet" }
    @available(iOS 8.0, *)
    static var Presentation:String { return "public.presentation" }
    @available(iOS 8.0, *)
    static var Database:String { return "public.database" }

/*
 *  kUTTypeVCard
 *
 *    VCard format
 *
 *    UTI: public.vcard
 *    conforms to: public.text, public.contact
 *
 *
 *  kUTTypeToDoItem
 *
 *    to-do item
 *
 *    UTI: public.to-do-item
 *
 *
 *  kUTTypeCalendarEvent
 *
 *    calendar event
 *
 *    UTI: public.calendar-event
 *
 *
 *  kUTTypeEmailMessage
 *
 *    e-mail message
 *
 *    UTI: public.email-message
 *    conforms to: public.message
 *
 */
    @available(iOS 3.0, *)
    static var VCard:String { return "public.vcard" }
    @available(iOS 8.0, *)
    static var ToDoItem:String { return "public.to-do-item" }
    @available(iOS 8.0, *)
    static var CalendarEvent:String { return "public.calendar-event" }
    @available(iOS 8.0, *)
    static var EmailMessage:String { return "public.email-message" }

/*
 *  kUTTypeInternetLocation
 *
 *    base type for Apple Internet locations
 *
 *    UTI: com.apple.internet-location
 *    conforms to: public.data
 *
 */
    @available(iOS 8.0, *)
    static var InternetLocation:String { return "com.apple.internet-location" }

/*
 *  kUTTypeInkText
 *
 *    Opaque InkText data
 *
 *    UTI: com.apple.ink.inktext
 *    conforms to: public.data
 *
 *
 *  kUTTypeFont
 *
 *    base type for fonts
 *
 *    UTI: public.font
 *
 *
 *  kUTTypeBookmark
 *
 *    bookmark
 *
 *    UTI: public.bookmark
 *
 *
 *  kUTType3DContent
 *
 *    base type for 3D content
 *
 *    UTI: public.3d-content
 *    conforms to: public.content
 *
 *
 *  kUTTypePKCS12
 *
 *    PKCS#12 format
 *
 *    UTI: com.rsa.pkcs-12
 *    conforms to: public.data
 *
 *
 *  kUTTypeX509Certificate
 *
 *    X.509 certificate format
 *
 *    UTI: public.x509-certificate
 *    conforms to: public.data
 *
 *
 *  kUTTypeElectronicPublication
 *
 *    ePub format
 *
 *    UTI: org.idpf.epub-container
 *    conforms to: public.data, public.composite-content
 *
 *
 *  kUTTypeLog
 *
 *    console log
 *
 *    UTI: public.log
 *
 */
    @available(iOS 3.0, *)
    static var InkText:String { return "com.apple.ink.inktext" }
    @available(iOS 8.0, *)
    static var Font:String { return "public.font" }
    @available(iOS 8.0, *)
    static var Bookmark:String { return "public.bookmark" }
    @available(iOS 8.0, *)
    static var _3DContent:String { return "public.3d-content" }
    @available(iOS 8.0, *)
    static var PKCS12:String { return "com.rsa.pkcs-12" }
    @available(iOS 8.0, *)
    static var X509Certificate:String { return "public.x509-certificate" }
    @available(iOS 8.0, *)
    static var ElectronicPublication:String { return "org.idpf.epub-container" }
    @available(iOS 8.0, *)
    static var Log:String { return "public.log" }

}
