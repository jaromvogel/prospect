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
            
            let brushset_image = makeBrushsetThumb(file: filewrapper)
            
            var orientation:String = "portrait"
            if (brushset_image.size.width >= brushset_image.size.height) {
                orientation = "landscape"
            }
            thumb_size = calcThumbSize(orientation: orientation, image_size: brushset_image.size, maxSize: request.maximumSize)
            thumb_image = NSImage(size: thumb_size!, actions: { ctx in
                // draw the brushset thumb at the appropriate thumbnail size
                ctx.draw(brushset_image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: CGRect(origin: .zero, size: thumb_size!))
            })
            
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

/// Create Brushset thumb
public func makeBrushsetThumb(file: FileWrapper) -> NSImage {
    // Step 1: create archive and access brushset.plist file
    let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
    let entry = archive!["brushset.plist"]
    var brushsetThumbImage:NSImage?
    
    // Step 2: read brushset.plist file into a useful format
    var plist_data:Data = Data()
    do {
        try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), skipCRC32: true, consumer: { (data) in
            plist_data.append(data)
        })
    } catch {
        NSLog("\(error)")
    }
    var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml
    var plistData: [String: AnyObject] = [:]
    do {
        plistData = try PropertyListSerialization.propertyList(from: plist_data, options: .mutableContainersAndLeaves, format: &propertyListFormat) as! [String : AnyObject]
    } catch {
        NSLog("\(error)")
    }
    var brushlist:NSArray? = plistData["brushes"] as? NSArray
    
    // Step 3: loop through each brush in the brushes array, get it's thumbnail image, and draw it into the larger image
    if (brushlist!.count > 4) {
        let cut = brushlist!.count - 4
        brushlist = brushlist!.dropLast(cut) as NSArray
    }
    let gap:Int = 7
    let composite_size:CGSize = CGSize(width: 600 + (2 * gap), height: ((184 + gap) * brushlist!.count) + gap)
    brushsetThumbImage = NSImage(size: composite_size, actions: { ctx in
        ctx.setFillColor(CGColor.init(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
        ctx.fill(CGRect(origin: .zero, size: composite_size))
        for (brush_index, brush) in brushlist!.enumerated() {
            
            let thumbpath = (brush as! String).appending("/QuickLook/Thumbnail.png")
            let thumbnail = getThumbImage(file: file, altpath: thumbpath)

            let idx_normal = (brushlist!.count - brush_index - 1)
            let brush_thumb_pos = CGPoint(x: gap, y: ((184 * idx_normal) + (idx_normal * gap) + gap))
            ctx.setFillColor(CGColor.init(gray: 0.0, alpha: 0.5))
            ctx.beginPath()
            let bottom_left:CGPoint = brush_thumb_pos
            let bottom_right:CGPoint = CGPoint(x: brush_thumb_pos.x + 600, y: brush_thumb_pos.y)
            let top_right:CGPoint = CGPoint(x: brush_thumb_pos.x + 600, y: brush_thumb_pos.y + 184)
            let top_left:CGPoint = CGPoint(x: brush_thumb_pos.x, y: brush_thumb_pos.y + 184)
            ctx.move(to: bottom_left)
            ctx.addArc(tangent1End: bottom_right, tangent2End: top_right, radius: 10.0)
            ctx.addArc(tangent1End: top_right, tangent2End: top_left, radius: 10.0)
            ctx.addArc(tangent1End: top_left, tangent2End: bottom_left, radius: 10.0)
            ctx.addArc(tangent1End: bottom_left, tangent2End: bottom_right, radius: 10.0)
            ctx.closePath()
            ctx.fillPath()

            ctx.draw(thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: CGRect(origin: brush_thumb_pos, size: CGSize(width: 600, height: 184)))
        }
    })
    return brushsetThumbImage!
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
