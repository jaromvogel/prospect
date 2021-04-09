//
//  ProcreateShared.swift
//  ProcreateDocument
//
//  Created by Jarom Vogel on 2/19/21.
//

import Foundation
import Cocoa
import QuickLookThumbnailing
import ZIPFoundation
import AVFoundation

public func readProcreateDocument(file: FileWrapper) -> SilicaDocument {
    let silica_doc = getArchive(file)

    silica_doc?.getComposite(file)
    return silica_doc!
}

public func getImageSize(si_doc: SilicaDocument, height: Int = 800, minWidth: Int, maxWidth: Int) -> CGSize {
    var width = height
    var img_height = si_doc.size?.height
    var img_width = si_doc.size?.width

    var orientation:String
    if (si_doc.orientation! == 3 || si_doc.orientation! == 4) {
        orientation = "landscape"
        img_height = si_doc.size?.width
        img_width = si_doc.size?.height
    } else {
        orientation = "portrait"
    }
    
    let ratio = img_width! / img_height!
    
    if (orientation == "landscape") {
        width = Int(CGFloat(height) * ratio)
    } else {
        width = Int(CGFloat(width) * ratio)
    }
    
    if (width > maxWidth) {
        width = maxWidth
    } else if (width < minWidth) {
        width = minWidth
    }
    
    return CGSize(width: width, height: height)
}







// Access video files
public func getVideoSegment(file: FileWrapper, segment: Int) -> Data {
    let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
        
    let entry = archive!["video/segments/segment-\(segment).mp4"]

    var segment_data:Data = Data()
    do {
        try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), consumer: { (data) in
            segment_data.append(data)
        })
    } catch {
        NSLog("\(error)")
    }
    return segment_data
}

public extension SilicaDocument {
    func getVideo(file: FileWrapper) -> AVPlayer {
        
        let fileManager = FileManager()
        
        let destinationURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("prospectvideo")
        do {
            try? fileManager.removeItem(at: destinationURL)
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("couldn't create the directory :(")
        }
        
        let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
        
        for entry in archive! {
            do {
                if (entry.path.contains("video") == true) {
                    _ = try archive!.extract(entry, to: destinationURL.appendingPathComponent(entry.path), skipCRC32: true)
                }
            } catch {
                print("didn't work")
            }
        }
        
        var assetlist:Array<AVAsset> = []
        do {
            var fileURLs = try fileManager.contentsOfDirectory(at: destinationURL.appendingPathComponent("video/segments"), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            // loop through video segments, load them, and put them together here
            fileURLs.sort(by: { urlitem1, urlitem2 in
                
                let c1 = urlitem1.pathComponents.count - 1
                let c2 = urlitem2.pathComponents.count - 1
                
                let v1 = urlitem1.pathComponents[c1].components(separatedBy: ".")
                let v2 = urlitem2.pathComponents[c2].components(separatedBy: ".")
                
                let x1 = String(v1[0]).split(separator: "-")[1]
                let x2 = String(v2[0]).split(separator: "-")[1]
                
                return Int(x1)! < Int(x2)!
            })
            for url in fileURLs {
                let asset = AVAsset(url: url)
                assetlist.append(asset)
            }
        } catch {
            print("couldn't count files for some reason")
        }
        
        // Create the composition
        let mixComposition = AVMutableComposition()
        var runningTime:CMTime = .zero
        let mainInstruction = AVMutableVideoCompositionInstruction()
        
        for i in 0..<assetlist.count {
            let asset = assetlist[i]
            let track = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            do {
                try track!.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: asset.tracks(withMediaType: .video)[0], at: runningTime)
                runningTime = CMTimeAdd(runningTime, asset.duration)
            } catch {
                print("Failed to load track \(i)")
            }
            
            let trackInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track!)
            trackInstruction.setOpacity(0.0, at: runningTime)
            mainInstruction.layerInstructions.append(trackInstruction)
        }
        
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: runningTime)

        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = mixComposition.tracks[0].naturalSize
        
        let playeritem = AVPlayerItem(asset: mixComposition)
        playeritem.videoComposition = mainComposition
        let compPlayer = AVPlayer(playerItem: playeritem)
        
        let player = compPlayer
        assetlist = []

        return player
    }
}

//
//func mergeVideo(_ mAssetsList: [AVAsset]) {
//    let mainComposition = AVMutableVideoComposition()
//    var startDuration:CMTime = CMTime.zero
//    let mainInstruction = AVMutableVideoCompositionInstruction()
//    let mixComposition = AVMutableComposition()
//    var allVideoInstruction = [AVMutableVideoCompositionLayerInstruction]()
//
//    let assets = mAssetsList
//
//    for i in 0..<assets.count {
//        let currentAsset:AVAsset = assets[i] // Current Asset
//        let currentTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
//        do {
//            try currentTrack!.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: currentAsset.duration), of: currentAsset.tracks(withMediaType: AVMediaType.video)[0], at: startDuration)
//
//            // Creates Instruction for current video asset
//            let currentInstruction:AVMutableVideoCompositionLayerInstruction = videoCompositionInstructionForTrack(currentTrack!, asset: currentAsset)
//
//            currentInstruction.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: CMTimeRangeMake(start: startDuration, duration: CMTimeMake(value: 1, timescale: 1)))
//
//            if i != assets.count - 1 {
//                // Sets Fade out effect at the end of the video
////                currentInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: CMTimeRangeMake(start: CMTimeSubtract(CMTimeAdd(currentAsset.duration, startDuration), CMTimeMake(value: 1, timescale: 1)), duration: CMTimeMake(value: 2, timescale: 1)))
//            }
//
//            allVideoInstruction.append(currentInstruction) //Add video instruction in Instructions Array.
//
//            startDuration = CMTimeAdd(startDuration, currentAsset.duration)
//        } catch _ {
//            print("error!")
//        }
//    }
//
//    mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: startDuration)
//    mainInstruction.layerInstructions = allVideoInstruction
//
//    mainComposition.instructions = [mainInstruction]
//    mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
//    mainComposition.renderSize = CGSize(width: 640, height: 480)
//
//    // Create path to store merged video.
//
//    let fileManager = FileManager()
//
//    let destinationURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("prospectTimeLapse.mp4")
//
//    try? fileManager.removeItem(at: destinationURL)
//
//    guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPreset640x480) else { return }
//    exporter.outputURL = destinationURL
//    exporter.outputFileType = AVFileType.mov
//    exporter.shouldOptimizeForNetworkUse = false
//    exporter.videoComposition = mainComposition
//
//    // Perform the Export
//    exporter.exportAsynchronously() {
//        DispatchQueue.main.async {
//            // do something when finished
//            exportDidFinish(exporter)
//        }
//    }
//}
//
//func exportDidFinish(_ session: AVAssetExportSession) {
//    if session.status == AVAssetExportSession.Status.completed {
//        print("ALL DONE EXPORTING!")
//        print(session.outputURL)
//    }
//}
//
//func videoCompositionInstructionForTrack(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
//        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
//        return instruction
//    }
//
//extension AVAsset {
//    var g_size: CGSize {
//        return tracks(withMediaType: AVMediaType.video).first?.naturalSize ?? .zero
//    }
//}
