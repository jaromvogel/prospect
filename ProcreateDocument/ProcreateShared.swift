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


public func getThumbImage(url: URL) -> NSImage {
    let archive = Archive(url: url, accessMode: .read)
        
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

