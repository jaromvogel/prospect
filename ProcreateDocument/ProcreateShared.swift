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
