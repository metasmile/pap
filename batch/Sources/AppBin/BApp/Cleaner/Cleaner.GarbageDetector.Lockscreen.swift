//
// Created by BLACKGENE on 13.07.18.
// Copyright (c) 2018 Stells. All rights reserved.
//

import Foundation
import Photos
import MetalPerformanceShaders
import MetalKit
import Vision

class PHAssetGarbageDetector_Lockscreens : PHAssetGarbageDetector{

    override class var priority: PHAssetGarbageDetectingPriority {
        return .lowest
    }

    private static var dataSet:LockscreenData?
    private var dataSet:LockscreenData{
        if let v = type(of: self).dataSet {
            return v
        }
        let dataSet = LockscreenData()
        type(of: self).dataSet = dataSet
        return dataSet
    }

//    private lazy var dataSet = LockscreenData()

    public var restrictMode:Bool = false

    required public init() {
        super.init()
    }

    private lazy var visionTextDetector = Vision.vision().onDeviceTextRecognizer()

    override class var label:String{
        return "Lockscreens".localized
    }

    let parser = VisionTextElementParser()

    let trimmedTimePattern = "^[0-9]{1,2}:?[0-9]{1,2}$"
    let dateDayPattern = "^([1-9])$|^([1-2][0-9])$|^(3[01])$"
    let chargedPattern = "^1?[0-9][0-9]%$"

    let sampleDataViaLog = true

    override func process(input: GarbageDetectorInput,_ asyncSignal: AsyncWaitSignalable) -> Bool? {
        guard input.asset.mediaType == .image else{
            return false
        }

        guard input.asset.pixelSize.width*input.asset.pixelSize.height<=UIScreen.main.nativeBounds.width*UIScreen.main.nativeBounds.height else{
            return nil
        }

        guard let image = input.asset.asUIImage else {
            return nil
        }

        guard let visionText = visionTextDetector.detect(with: image, asyncSignal) else {
            return nil
        }


        let imageSize = image.size

        if sampleDataViaLog { print("imageSize:",image.size) }

        var foundNormalizedTimeRect:CGRect = CGRect.null
        var shouldFindSinceFoundRect = 4

        for visionTextBlock in visionText.blocks{
            for elems in parser.process(input: visionTextBlock) ?? []{
                for elem in elems{

                    if sampleDataViaLog { print(elem.frame, elem.text) }
                    let normalizedFrame = elem.frame.normalized(by:imageSize)

                    //found time -> match day 1 ~ 31 -> if found return / else skip
                    if foundNormalizedTimeRect.isNull == false && shouldFindSinceFoundRect > 0{
                        shouldFindSinceFoundRect -= 1

                        let srcText = elem.text.remove(" ")

                        //day string
                       let srcDayString = srcText.replaceIfMatched(withPattern: "[^0-9]", replace: "")
                        if srcDayString.matched(dateDayPattern){
                            print("FOUND FOUND FOUND FOUND FOUND FOUND FOUND FOUND ")
                            return true
                        }

                        //charge Percent
                        if srcText.matched(chargedPattern) {
                            print("FOUND FOUND FOUND FOUND FOUND FOUND FOUND FOUND ")
                            return true
                        }

                        // cant find
                        if shouldFindSinceFoundRect==0{
                            //unable to find within 3 cycles
                            return false
                        }else{
                            continue
                        }
                    }

                    let r = dataSet.TimeRectDictionaryiPhone_Normalized_Min_Max_Rect
                    if r.1.contains(normalizedFrame) && normalizedFrame.contains(r.0){

                        //find time
                        let targetText = elem.text.remove(" ").replaceIfMatched(withPattern: "[^0-9]", replace: "")
                        if targetText.matched(trimmedTimePattern){

                            if restrictMode {
                                foundNormalizedTimeRect = normalizedFrame
                                continue

                            }else{
                                return true
                            }
                        }
                    }


                }
            }
        }
        print("NOT FOUND")
        return false
    }
}

private struct LockscreenData{

    // imageSize:\s\((.*),(.*)\)$
    //-> CGSize(width: $1, height: $2)

    // \((.*),(.*),(.*),(.*)\)\s[0-9]?[0-9]:[0-9][0-9]?$
    // -> CGRect(x: $1, y:$2, width:$3, height:$4)

    let TimeRectDictionaryiPhone:[CGSize:Set<CGRect>] /*textFrame : imageSize*/ = [
        /* from Real Device */

        // 6plus + ios11
        CGSize(width: 576.0, height: 1024.0): Set([
            CGRect(x: 118.0, y:108.0, width:337.0, height:118.0)
        ])

        // x + ios 11
        , CGSize(width: 1125.0, height: 2436.0): Set([
            CGRect(x:267.0, y:325.0, width:563.0, height:256.0) // locale - en
            ,CGRect(x:246.0, y:348.0, width:627.0, height:188.0) // locale - en
            ,CGRect(x:245.0, y:356.0, width:621.0, height:198.0) // locale - en
            ,CGRect(x: 304.0, y: 332.0, width: 505.0, height: 241.0)
            ,CGRect(x:221.0, y:316.0, width:649.0, height:251.0)
        ])

        ,CGSize(width: 1200.0, height:  2134.0) : Set([
            CGRect(x: 390.0, y: 247.0, width: 301.0, height: 222.0)
        ])

        ,CGSize(width: 1242.0, height:  2208.0)  : Set([
            CGRect(x: 278.0, y: 232.0, width: 647.0, height: 305.0)
        ])

        , CGSize(width: 750.0, height:  1334.0) : Set([
            CGRect(x: 221.0, y: 161.0, width: 298.0, height: 131.0)
            ,CGRect(x: 172.0, y: 141.0, width: 388.0, height: 166.0)
        ])

        /* from Alias/Images */
        , CGSize(width: 640.0, height:  1136.0) : Set([
            CGRect(x: 136.0, y: 90.0, width: 346.0, height: 168.0)
        ])
    ]
    let TimeRectDictionaryiPhone_Normalized:[CGSize:Set<CGRect>]
    let TimeRectDictionaryiPhone_Normalized_Min_Max_Rect:(CGRect, CGRect)

    let TimeRectDictionaryiPadAlias:[CGSize:CGRect] /*imageSize: textFrame*/ = [
        CGSize(width: 576.0, height: 1024.0) : CGRect(x: 118.0, y:108.0, width:337.0, height:118.0) // 6plus + ios11
        , CGSize(width: 1125.0, height: 2436.0) : CGRect(x: 353.0, y:581.0, width:150.0, height:61.0) // x + ios 11
    ]

    init(){
        var dict = [CGSize:Set<CGRect>]()
        let values = Array(TimeRectDictionaryiPhone.values)
        var minRect = CGRect(x:0.0,y:0.0,width:CGFloat.greatestFiniteMagnitude,height:CGFloat.greatestFiniteMagnitude)
        var maxRect = CGRect()

        for (i, size) in TimeRectDictionaryiPhone.keys.enumerated(){
            let rectSet = values[i]
            var set = Set<CGRect>()
            for rect in rectSet{
                let nRect = rect.normalized(by:size)

                maxRect = maxRect.union(nRect)
                minRect = minRect.intersection(nRect)
                set.insert(nRect)
            }
            dict[size] = set
        }
        TimeRectDictionaryiPhone_Normalized = dict
        TimeRectDictionaryiPhone_Normalized_Min_Max_Rect = (minRect, maxRect)
        print("TimeRectDictionaryiPhone_Normalized_Min_Max_Rect",TimeRectDictionaryiPhone_Normalized_Min_Max_Rect)
    }
}

/*
X

imageSize: (1125.0, 2436.0)
(73.0, 52.0, 142.0, 40.0) Drillisch
(267.0, 325.0, 563.0, 256.0) 1206
(353.0, 581.0, 150.0, 61.0) 89%         -> [0-9][0-9]% + Charged
(521.0, 586.0, 235.0, 63.0) Charged     -> Charged
(873.0, 2194.0, 63.0, 31.0) O
*/

/*

6 plus
imageSize: (576.0, 1024.0)
(29.0, 6.0, 10.0, 19.0) l
(43.0, 6.0, 66.0, 19.0) Drillisch
(432.0, 7.0, 56.0, 16.0) 4O
(490.0, 7.0, 35.0, 16.0) 91%

(118.0, 108.0, 337.0, 118.0) 10:43      -> Datetime
(192.0, 239.0, 94.0, 31.0) Friday,      -> and next, 2~3 same y
(285.0, 240.0, 37.0, 31.0) 13
(332.0, 241.0, 47.0, 31.0) July         -> 2~3 blocks

(141.0, 345.0, 10.0, 12.0) i
(73.0, 472.0, 15.0, 13.0) 3
(83.0, 473.0, 14.0, 12.0) 6
(492.0, 473.0, 11.0, 10.0) 2:
(513.0, 607.0, 20.0, 18.0) ))
(63.0, 691.0, 90.0, 20.0) SETTINGGS
(20.0, 729.0, 77.0, 20.0) iPhone
(103.0, 729.0, 74.0, 20.0) Backup
(183.0, 730.0, 57.0, 20.0) Failed
(25.0, 756.0, 41.0, 19.0) You
(70.0, 756.0, 26.0, 19.0) do
(100.0, 756.0, 33.0, 19.0) not
(136.0, 756.0, 47.0, 19.0) have
(186.0, 756.0, 73.0, 19.0) enough
(263.0, 756.0, 60.0, 19.0) space
(326.0, 756.0, 17.0, 19.0) in
(346.0, 756.0, 63.0, 19.0) iCloud
(413.0, 756.0, 23.0, 19.0) to
(440.0, 756.0, 46.0, 19.0) back
(493.0, 756.0, 23.0, 19.0) up
(22.0, 782.0, 44.0, 19.0) this
(66.0, 782.0, 67.0, 19.0) iPhone
(380.0, 693.0, 91.0, 18.0) Yesterday,
(474.0, 694.0, 39.0, 18.0) 2:39
(519.0, 694.0, 24.0, 18.0) PM
(235.0, 956.0, 66.0, 23.0) nome
(304.0, 958.0, 26.0, 22.0) to
(171.0, 344.0, 13.0, 13.0) or
(181.0, 345.0, 12.0, 12.0) ne
(153.0, 344.0, 15.0, 13.0) Ph
(140.0, 367.0, 266.0, 25.0) Scene19:33|Ed3+
(410.0, 367.0, 22.0, 25.0) TH
(458.0, 367.0, 34.0, 25.0) (I'r
(151.0, 392.0, 23.0, 23.0) H
(185.0, 393.0, 119.0, 24.0) HAĘ271
(304.0, 395.0, 42.0, 23.0) QE
(350.0, 396.0, 138.0, 25.0) g01Ë-24
*/

/*

imageSize: (750.0, 1334.0)
(604.0, 10.0, 71.0, 26.0) 75%%
(39.0, 12.0, 20.0, 25.0) l
(59.0, 12.0, 104.0, 25.0) docomo

(221.0, 161.0, 298.0, 131.0) 5:15           <
(160.0, 318.0, 154.0, 41.0) Sunday,         -> Max within max-min == 4px -> 0.0029985007496251873%
(320.0, 315.0, 214.0, 42.0) September       <
(546.0, 314.0, 48.0, 40.0) 24               <

(208.0, 464.0, 162.0, 26.0) HEADPHONES
(208.0, 501.0, 126.0, 36.0) Dreams
(347.0, 501.0, 92.0, 36.0) Tonite
(214.0, 542.0, 367.0, 33.0) Alvvays--Antisocialites
(602.0, 648.0, 83.0, 26.0) -1:55
(76.0, 648.0, 45.0, 24.0) :21
(202.0, 1235.0, 97.0, 32.0) Press
(305.0, 1235.0, 93.0, 32.0) home
(399.0, 1235.0, 43.0, 32.0) to
(443.0, 1235.0, 104.0, 32.0) unlock




imageSize: (1200.0, 2134.0)
(74.0, 17.0, 164.0, 50.0) Project
(253.0, 16.0, 41.0, 48.0) Fi
(823.0, 19.0, 114.0, 40.0) 13
(937.0, 18.0, 116.0, 40.0) 100%
(1059.0, 17.0, 14.0, 39.0) 0

(390.0, 247.0, 301.0, 222.0) 9:4            <
(271.0, 507.0, 250.0, 71.0) Monday,         <
(532.0, 507.0, 328.0, 71.0) September       <
(884.0, 507.0, 73.0, 71.0) 18               <

(65.0, 717.0, 254.0, 100.0) Earlier
(332.0, 723.0, 229.0, 99.0) Today
(1062.0, 748.0, 78.0, 52.0) x
(282.0, 894.0, 79.0, 41.0) 9m
(372.0, 899.0, 72.0, 41.0) ago
(627.0, 1026.0, 96.0, 44.0) View
(959.0, 1027.0, 93.0, 41.0) Clea
(0.0, 1038.0, 101.0, 46.0) -this
(109.0, 1037.0, 40.0, 46.0) is
(155.0, 1037.0, 101.0, 46.0) real:
(270.0, 1037.0, 87.0, 46.0) The
(363.0, 1036.0, 61.0, 46.0) US
(0.0, 1098.0, 50.0, 48.0) ba
(67.0, 1098.0, 108.0, 48.0) after
(184.0, 1098.0, 214.0, 48.0) diplomats
(0.0, 1156.0, 111.0, 44.0) there
(138.0, 1309.0, 255.0, 50.0) MESSENGER
(62.0, 1404.0, 96.0, 44.0) Lisa
(165.0, 1404.0, 94.0, 44.0) sent
(275.0, 1404.0, 31.0, 44.0) a
(313.0, 1404.0, 142.0, 44.0) photo.
(987.0, 1318.0, 59.0, 42.0) 1h
(1056.0, 1323.0, 73.0, 43.0) ago
(987.0, 1562.0, 59.0, 41.0) 1h
(1058.0, 1565.0, 74.0, 41.0) ago
(976.0, 1802.0, 72.0, 44.0) 3h
(1059.0, 1807.0, 72.0, 44.0) ago
(135.0, 1804.0, 132.0, 42.0) NEWWS
(55.0, 1886.0, 99.0, 49.0) The
(169.0, 1889.0, 129.0, 49.0) Verge
(67.0, 1951.0, 181.0, 50.0) Hackers
(257.0, 1951.0, 213.0, 50.0) breached
(486.0, 1951.0, 239.0, 50.0) CCleaner's
(733.0, 1951.0, 170.0, 50.0) security
(921.0, 1951.0, 42.0, 50.0) to
(972.0, 1951.0, 127.0, 50.0) inject
(76.0, 2009.0, 175.0, 44.0) malware
(266.0, 2009.0, 79.0, 44.0) and
(360.0, 2009.0, 204.0, 44.0) distribute
(571.0, 2009.0, 40.0, 44.0) it
(618.0, 2009.0, 47.0, 44.0) to
(673.0, 2009.0, 172.0, 44.0) millions
(138.0, 1560.0, 252.0, 41.0) STARBUCKS
(63.0, 1649.0, 105.0, 41.0) Your
(175.0, 1649.0, 178.0, 41.0) balance
(360.0, 1649.0, 43.0, 41.0) is
(410.0, 1649.0, 92.0, 41.0) now
(517.0, 1649.0, 163.0, 41.0) $16.05.




imageSize: (1242.0, 2208.0)
(278.0, 232.0, 647.0, 305.0) 12:15
(419.0, 519.0, 238.0, 63.0) Tuesday,
(668.0, 519.0, 109.0, 63.0) July
(787.0, 519.0, 33.0, 63.0) 4



imageSize: (750.0, 1334.0)
(42.0, 12.0, 74.0, 25.0) Free
(172.0, 141.0, 388.0, 166.0) 10:15
(173.0, 320.0, 197.0, 40.0) Thursday,
(377.0, 320.0, 147.0, 40.0) January
(538.0, 320.0, 35.0, 40.0) 11
(230.0, 468.0, 16.0, 16.0) h
(247.0, 469.0, 19.0, 15.0) br
(262.0, 471.0, 16.0, 14.0) n6
(213.0, 468.0, 19.0, 16.0) P
(207.0, 500.0, 67.0, 37.0) Trip
(286.0, 498.0, 106.0, 38.0) Switch
(189.0, 542.0, 120.0, 32.0) lothing
(315.0, 542.0, 55.0, 32.0) But
(376.0, 542.0, 120.0, 32.0) Thieves
(508.0, 542.0, 76.0, 32.0) (Delu
(124.0, 497.0, 38.0, 11.0) uTHIEVE
(84.0, 498.0, 33.0, 11.0) NOTHING
(59.0, 646.0, 70.0, 31.0) 1:19
(602.0, 650.0, 81.0, 26.0) -1:43
(640.0, 849.0, 45.0, 26.0) )
(204.0, 1235.0, 93.0, 30.0) Press
(307.0, 1235.0, 88.0, 30.0) home
(400.0, 1235.0, 42.0, 30.0) to
(447.0, 1235.0, 103.0, 30.0) unlock



imageSize: (640.0, 1136.0)
(136.0, 90.0, 346.0, 168.0) 7:06                <
(112.0, 259.0, 196.0, 37.0) Wednesday,          <
(315.0, 259.0, 181.0, 37.0) September           <
(503.0, 259.0, 32.0, 37.0) 18                   <

(174.0, 956.0, 106.0, 41.0) slide
(286.0, 956.0, 44.0, 40.0) to
(336.0, 954.0, 134.0, 41.0) unlock
(428.0, 1054.0, 93.0, 37.0) phone
(526.0, 1053.0, 81.0, 37.0) Arenal




imageSize: (1125.0, 2436.0)
(923.0, 51.0, 22.0, 37.0) l
(950.0, 51.0, 50.0, 37.0) LTE
(65.0, 52.0, 161.0, 36.0) T-Mobile

(304.0, 332.0, 505.0, 241.0) 3:02           <
(293.0, 580.0, 240.0, 62.0) Monday,         <
(542.0, 582.0, 219.0, 62.0) January         <
(780.0, 583.0, 74.0, 61.0) 15               <

(123.0, 759.0, 224.0, 43.0) SNAPCHAT
(72.0, 838.0, 224.0, 50.0) Notification
(979.0, 769.0, 78.0, 28.0) now
(978.0, 996.0, 47.0, 28.0) no
(1003.0, 1281.0, 56.0, 28.0) ow
(973.0, 1284.0, 30.0, 20.0) n
(69.0, 1501.0, 279.0, 43.0) ASNAPCHAT
(72.0, 1581.0, 227.0, 49.0) Notification
(910.0, 1505.0, 70.0, 34.0) 1m
(989.0, 1509.0, 71.0, 34.0) ago
(861.0, 2187.0, 77.0, 45.0) O
(136.0, 988.0, 212.0, 39.0) MESSAGES
(61.0, 1074.0, 201.0, 42.0) Cameron
(45.0, 1128.0, 214.0, 49.0) iMessage
(64.0, 1271.0, 284.0, 45.0) ASNAPCHAT
(72.0, 1352.0, 227.0, 49.0) Notification
*/
