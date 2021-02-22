//
//  ThumbnailProvider.swift
//  ProspectThumb
//
//  Created by Jarom Vogel on 11/8/20.
//

import QuickLookThumbnailing
import Cocoa
import Quartz
import ZIPFoundation

class ThumbnailProvider: QLThumbnailProvider {
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        
        // Get file extension
        let ext = request.fileURL.pathExtension
        
        // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
   
        guard let archive = Archive(url: request.fileURL, accessMode: .read) else {
            return
        }
        guard let entry = archive["QuickLook/Thumbnail.png"] else {
            return
        }

        var thumb_data:Data = Data()
        do {
            try _ = archive.extract(entry, bufferSize: UInt32(100000000), consumer: { (data) in
                thumb_data.append(data)
            })
        } catch {
            NSLog("\(error)")
        }

        let thumb_image:NSImage = NSImage.init(data: thumb_data)!

        // Figure out if thumb should be portrait or landscape
        var orientation:String = "landscape"
        if (thumb_image.size.width < thumb_image.size.height) {
            orientation = "portrait"
        }
        
        // Calculate size of thumb
        var short_ratio:CGFloat = 1
        var thumb_size:CGSize
        if (orientation == "landscape") {
            short_ratio = thumb_image.size.height / thumb_image.size.width
            thumb_size = CGSize(width: request.maximumSize.width, height: request.maximumSize.width * short_ratio)
        } else {
            short_ratio = thumb_image.size.width / thumb_image.size.height
            thumb_size = CGSize(width: request.maximumSize.height * short_ratio, height: request.maximumSize.height)
        }
        
        
        // First way: Draw the thumbnail into the current context, set up with UIKit's coordinate system.
        handler(QLThumbnailReply(contextSize: thumb_size, currentContextDrawing: { () -> Bool in
            
            let current_ctx = NSGraphicsContext.current?.cgContext
            
            if (ext == "brush") {
                // Fill the background black for brushes
                let color = NSColor.black.cgColor
                current_ctx!.setFillColor(color)
                current_ctx!.fill(CGRect(origin: .zero, size: thumb_size))
            }
            
            // Draw the thumbnail here.
            thumb_image.draw(in: CGRect(origin: .zero, size: thumb_size))
            
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)
        
        /*
        // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, drawing: { (context) -> Bool in
            // Draw the thumbnail here.
         
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)

         
        // Third way: Set an image file URL.
        handler(QLThumbnailReply(imageFileURL: Bundle.main.url(forResource: "ARBook_icon", withExtension: "png")!), nil)
         */

    }
}
