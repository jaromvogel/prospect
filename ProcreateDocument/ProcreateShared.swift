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

public func readProcreateDocument(file: FileWrapper) -> SilicaDocument {
    let silica_doc = getArchive(file)

    silica_doc?.getComposite(file)
    return silica_doc!
}


public func getThumbImage(file: FileWrapper) -> NSImage {
    let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
        
    let entry = archive!["QuickLook/Thumbnail.png"]

    var thumb_data:Data = Data()
    do {
        try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), consumer: { (data) in
            thumb_data.append(data)
        })
    } catch {
        NSLog("\(error)")
    }

    let thumb_image:NSImage = NSImage.init(data: thumb_data)!
    return thumb_image
}

public func getThumbOrientation(thumb_image: NSImage) -> String {
    // Figure out if thumb should be portrait or landscape
    var orientation:String = "landscape"
    if (thumb_image.size.width < thumb_image.size.height) {
        orientation = "portrait"
    }
    return orientation
}

public func getBrushPreviewSize(thumb_image: NSImage, orientation: String) -> CGSize {
    // Calculate size of thumb
    var short_ratio:CGFloat = 1
    var brush_size:CGSize
    let max_size:CGSize = CGSize(width: 500, height: 500)
    if (orientation == "landscape") {
        short_ratio = thumb_image.size.height / thumb_image.size.width
        brush_size = CGSize(width: max_size.width, height: max_size.width * short_ratio)
    } else {
        short_ratio = thumb_image.size.width / thumb_image.size.height
        brush_size = CGSize(width: max_size.height * short_ratio, height: max_size.height)
    }
    return brush_size
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

public func getSwatchesThumb(_ swatches_meta: SwatchesData, _ thumb_size: CGSize) -> NSImage {
    // use all that complicated swatch info to make a thumbnail image here
    let test = NSImage(systemSymbolName: "book.circle", accessibilityDescription: nil)
    return test!
}


public struct SwatchesData: Codable {
    let name: String
    let swatches: [SwatchObj]
    let colorProfiles: [ColorProfiles]
}

public struct SwatchObj: Codable {
    let alpha: Int
    let origin: Int
    let colorSpace: Int
    let brightness: CGFloat
    let components: [CGFloat]
    let version: String
    let colorProfile: String
    let saturation: CGFloat
    let hue: CGFloat
}

public struct ColorProfiles: Codable {
    let colorSpace: Int
    let hash: String
    let iccData: String
    let iccName: String
}
