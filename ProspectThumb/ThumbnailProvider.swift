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
        
        var thumb_size:CGSize?
        var thumb_image:NSImage?
        
        // Get file extension
        let ext = request.fileURL.pathExtension
        let filewrapper = try! FileWrapper(url: request.fileURL, options: .immediate)
        
        if (ext == "procreate" || ext == "brush") {
            
            // Get thumb image
            thumb_image = getThumbImage(file: filewrapper)

            // Figure out if thumb should be portrait or landscape
            var orientation:String = "landscape"
            if (thumb_image!.size.width < thumb_image!.size.height) {
                orientation = "portrait"
            }
            
            // Calculate size of thumb
            thumb_size = calcThumbSize(orientation: orientation, image_size: thumb_image!.size, maxSize: request.maximumSize)
            
        } else if (ext == "swatches") {
            
            // Get thumb image
            let swatches_image = getSwatchesImage(filewrapper)
            
            // Calculate size of thumb
            thumb_size = calcThumbSize(orientation: "landscape", image_size: swatches_image.size, maxSize: request.maximumSize)
            
            // Draw swatches thumb image at the correct thumbnail size
            thumb_image = NSImage(size: thumb_size!, actions: { ctx in
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fill(CGRect(origin: .zero, size: thumb_size!))
                ctx.draw(swatches_image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: CGRect(origin: .zero, size: thumb_size!))
            })
            
        } else if (ext == "brushset") {
            
            thumb_size = CGSize(width: 300, height: 300)
            thumb_image = NSImage(size: thumb_size!)
            
        }
        
        // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
        
        
        // First way: Draw the thumbnail into the current context, set up with UIKit's coordinate system.
        handler(QLThumbnailReply(contextSize: thumb_size!, currentContextDrawing: { () -> Bool in
            
            let current_ctx = NSGraphicsContext.current?.cgContext
            
            if (ext == "brush") {
                // Fill the background black for brushes
                let color = NSColor.black.cgColor
                current_ctx!.setFillColor(color)
                current_ctx!.fill(CGRect(origin: .zero, size: thumb_size!))
            }
            
            // Draw the thumbnail here.
            thumb_image!.draw(in: CGRect(origin: .zero, size: thumb_size!))
            
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

// Calculate size of thumb
func calcThumbSize(orientation: String, image_size: CGSize, maxSize: CGSize) -> CGSize {
    var short_ratio:CGFloat = 1
    var thumb_size:CGSize
    if (orientation == "landscape") {
        short_ratio = image_size.height / image_size.width
        thumb_size = CGSize(width: maxSize.width, height: maxSize.width * short_ratio)
    } else {
        short_ratio = image_size.width / image_size.height
        thumb_size = CGSize(width: maxSize.height * short_ratio, height: maxSize.height)
    }
    return thumb_size
}

//struct SwatchesData: Codable {
//    let name: String
//    let swatches: [SwatchObj]
//    let colorProfiles: [ColorProfiles]
//}
//
//struct SwatchObj: Codable {
//    let alpha: Int
//    let origin: Int
//    let colorSpace: Int
//    let brightness: CGFloat
//    let components: [CGFloat]
//    let version: String
//    let colorProfile: String
//    let saturation: CGFloat
//    let hue: CGFloat
//}
//
//struct ColorProfiles: Codable {
//    let colorSpace: Int
//    let hash: String
//    let iccData: String
//    let iccName: String
//}

//extension NSImage {
//    convenience init(size: CGSize, actions: (CGContext) -> Void) {
//        self.init(size: size)
//        lockFocusFlipped(false)
//        actions(NSGraphicsContext.current!.cgContext)
//        unlockFocus()
//    }
//}
