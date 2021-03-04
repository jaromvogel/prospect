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
        var swatches_meta:SwatchesData?
        
        guard let archive = Archive(url: request.fileURL, accessMode: .read) else {
            return
        }
        
        // Get file extension
        let ext = request.fileURL.pathExtension
        
        if (ext == "procreate" || ext == "brush") {
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

            thumb_image = NSImage.init(data: thumb_data)!

            // Figure out if thumb should be portrait or landscape
            var orientation:String = "landscape"
            if (thumb_image!.size.width < thumb_image!.size.height) {
                orientation = "portrait"
            }
            
            // Calculate size of thumb
            var short_ratio:CGFloat = 1
            if (orientation == "landscape") {
                short_ratio = thumb_image!.size.height / thumb_image!.size.width
                thumb_size = CGSize(width: request.maximumSize.width, height: request.maximumSize.width * short_ratio)
            } else {
                short_ratio = thumb_image!.size.width / thumb_image!.size.height
                thumb_size = CGSize(width: request.maximumSize.height * short_ratio, height: request.maximumSize.height)
            }
        } else if (ext == "swatches") {
            thumb_size = CGSize(width: 218, height: 64)
            guard let entry = archive["Swatches.json"] else {
                return
            }
            var swatches_data:Data = Data()
            do {
                try _ = archive.extract(entry, bufferSize: UInt32(100000000), consumer: { (data) in
                    swatches_data.append(data)
                })
            } catch {
                assertionFailure("couldn't get swatches data!")
                NSLog("\(error)")
            }
            swatches_meta = try! JSONDecoder().decode(SwatchesData.self, from: swatches_data)
            thumb_image = getSwatchesThumb(swatches_meta!, thumb_size!)
            
//            thumb_image = NSImage(size: thumb_size!)
            
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
            
            if (ext == "swatches") {
                let color = NSColor.red.cgColor
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

func getSwatchesThumb(_ swatches_meta: SwatchesData, _ thumb_size: CGSize) -> NSImage {
    // use all that complicated swatch info to make a thumbnail image here
    if #available(OSXApplicationExtension 11.0, *) {
        let test = NSImage(systemSymbolName: "book.circle", accessibilityDescription: nil)
        return test!
    } else {
        // Fallback on earlier versions
    }
    return NSImage(size: thumb_size)
}


struct SwatchesData: Codable {
    let name: String
    let swatches: [SwatchObj]
    let colorProfiles: [ColorProfiles]
}

struct SwatchObj: Codable {
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

struct ColorProfiles: Codable {
    let colorSpace: Int
    let hash: String
    let iccData: String
    let iccName: String
}
