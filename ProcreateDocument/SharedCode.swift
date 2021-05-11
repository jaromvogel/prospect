//
//  SharedCode.swift
//  Prospect
//
//  Created by Vogel Family on 3/29/21.
//

import Foundation
import Cocoa
import ZIPFoundation

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


public func getThumbImage(file: FileWrapper, altpath: String? = nil) -> NSImage {
    let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
       
    var path:String = "QuickLook/Thumbnail.png"
    if (altpath != nil) {
        path = altpath!
    }
    let entry = archive![path]

    var thumb_data:Data = Data()
    do {
        try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), skipCRC32: true, consumer: { (data) in
            thumb_data.append(data)
        })
    } catch {
        NSLog("\(error)")
    }

    let thumb_image:NSImage = NSImage.init(data: thumb_data)!
    return thumb_image
}




public func getSwatchesImage(_ file: FileWrapper) -> NSImage {
    // use all that complicated swatch info to make a thumbnail image here
  
    var swatches_image:NSImage?
    let swatches_size = CGSize(width: 600, height: 180)
    var swatches_data:Data = Data()
    
    let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)!
    let entry = archive["Swatches.json"]
    do {
        try _ = archive.extract(entry!, bufferSize: UInt32(100000000), consumer: { (data) in
            swatches_data.append(data)
        })
    } catch {
        assertionFailure("couldn't get swatches data!")
        NSLog("\(error)")
    }
    do {
        let swatches_meta = try JSONDecoder().decode(SwatchesData.self, from: swatches_data)
        
        swatches_image = NSImage(size: swatches_size, actions: { ctx in
            
            for (swatch_index, swatch) in swatches_meta.swatches.enumerated() {
                let swatch_pos = getSwatchPosition(swatch_index)
                let swatch_rect = CGRect(origin: swatch_pos, size: CGSize(width: 60, height: 60))
                if (swatch != nil) {
                    let icc = swatches_meta.colorProfiles[swatch!.colorSpace].iccData
                    let icc_data = NSData(base64Encoded: icc, options: .ignoreUnknownCharacters)
                    let colorSpace:NSColorSpace = NSColorSpace.init(iccProfileData: icc_data! as Data)!
                    let swatch_color = NSColor(colorSpace: colorSpace, hue: swatch!.hue, saturation: swatch!.saturation, brightness: swatch!.brightness, alpha: 1.0)
                    ctx.setFillColor(swatch_color.cgColor)
                    ctx.fill(swatch_rect)
                } else {
                    let swatch_color = NSColor(colorSpace: .displayP3, hue: 0.0, saturation: 0.0, brightness: 0.0, alpha: 0.0)
                    ctx.setFillColor(swatch_color.cgColor)
                    ctx.fill(swatch_rect)
                }
            }
        })
    } catch {
        // This is likely an older swatches file that's arranged a bit differently
        let swatches_meta = try! JSONDecoder().decode([SwatchesDataOld].self, from: swatches_data)
        
        swatches_image = NSImage(size: swatches_size, actions: { ctx in
            
            for (swatch_index, swatch) in swatches_meta[0].swatches.enumerated() {
                let swatch_pos = getSwatchPosition(swatch_index)
                let swatch_rect = CGRect(origin: swatch_pos, size: CGSize(width: 60, height: 60))
                var alpha = 1.0
                if (swatch == nil) {
                    alpha = 0.0
                }
                let swatch_color:NSColor = NSColor(colorSpace: .displayP3, hue: (swatch?.hue) ?? 0.0, saturation: (swatch?.saturation) ?? 0.0, brightness: (swatch?.brightness) ?? 0.0, alpha: CGFloat(alpha))
                ctx.setFillColor(swatch_color.cgColor)
                ctx.fill(swatch_rect)
            }
        })
    }
    
    return swatches_image!
}

func getSwatchPosition(_ index: Int) -> CGPoint {
    let column:Int = index % 10
    let row:Int = Int(floor((Double(index) / 10)))
    let position:CGPoint = CGPoint(x: column * 60, y: 120 - (row * 60))
    return position;
}

public struct SwatchesData: Codable {
    let name: String
    let swatches: [SwatchObj?]
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


// Handle older swatches files
public struct SwatchesDataOld: Codable {
    let name: String
    let swatches: [SwatchObjOld?]
}

public struct SwatchObjOld: Codable {
    let hue: CGFloat?
    let brightness: CGFloat?
    let saturation: CGFloat?
}


// NSImage Extensions
extension NSImage {
    convenience init(size: CGSize, actions: (CGContext) -> Void) {
        self.init(size: size)
        lockFocusFlipped(false)
        actions(NSGraphicsContext.current!.cgContext)
        unlockFocus()
    }
    
    public func flipVertically() -> NSImage {
        let existingImage: NSImage? = self
        let existingSize: NSSize? = existingImage?.size
        let newSize: NSSize? = NSMakeSize((existingSize?.width)!, (existingSize?.height)!)
        let flippedImage = NSImage(size: newSize!)
        flippedImage.lockFocus()
        
        let t = NSAffineTransform.init()
        t.translateX(by: 0.0, yBy: (existingSize?.height)!)
        t.scaleX(by: 1.0, yBy: -1.0)
        t.concat()
        
        let rect:NSRect = NSMakeRect(0, 0, (newSize?.width)!, (newSize?.height)!)
        existingImage?.draw(at: NSZeroPoint, from: rect, operation: .sourceOver, fraction: 1.0)
        flippedImage.unlockFocus()
        return flippedImage
    }
    
    public func flipHorizontally() -> NSImage {
        let existingImage: NSImage? = self
        let existingSize: NSSize? = existingImage?.size
        let newSize: NSSize? = NSMakeSize((existingSize?.width)!, (existingSize?.height)!)
        let flippedImage = NSImage(size: newSize!)
        flippedImage.lockFocus()
        
        let t = NSAffineTransform.init()
        t.translateX(by: (existingSize?.width)!, yBy: 0.0)
        t.scaleX(by: -1.0, yBy: 1.0)
        t.concat()
        
        let rect:NSRect = NSMakeRect(0, 0, (newSize?.width)!, (newSize?.height)!)
        existingImage?.draw(at: NSZeroPoint, from: rect, operation: .sourceOver, fraction: 1.0)
        flippedImage.unlockFocus()
        return flippedImage
    }
}
