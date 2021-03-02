//
//  ProcreateImage.swift
//  Prospect
//
//  Created by Vogel Family on 11/9/20.
//

import Foundation
import AppKit
import ZIPFoundation

public extension SilicaDocument {
    
    func getComposite(_ file: FileWrapper, _ callback: @escaping () -> Void = {}) {
        
        let size:CGSize = (self.size)!
        let tileSize:Int = (self.tileSize)!
        
        // How many columns / rows of image chunks are in the file
        let columns:Int = Int(ceil(size.width / CGFloat(tileSize)))
        let rows:Int = Int(ceil(size.height / CGFloat(tileSize)))
        
        // For columns and rows that aren't multiples of tilesize, calculate how different they are
        var differenceX:Int = 0
        var differenceY:Int = 0
        if Int(size.width) % tileSize != 0 {
            differenceX = (columns * tileSize) - Int(size.width)
        }
        if Int(size.height) % tileSize != 0 {
            differenceY = (rows * tileSize) - Int(size.height)
        }
        
        let image_chunks:Array<chunkImage> = getLayerData((self.composite)!, columns, rows, differenceX, differenceY, file)

        var buffer_img:NSImage?
        DispatchQueue.global(qos: .userInitiated).async {
            buffer_img = decompressAndCompositeImages(file, self, image_chunks)
            DispatchQueue.main.async {
                self.composite_image = buffer_img
                callback()
            }
        }
    }
    
    func getRotation() -> Double {
        // rotate the image based on orientation
        var rotation = 0.0
        
        switch self.orientation {
            case 1:
                rotation = 0.0
            case 2:
                rotation = 180.0
            case 3:
                rotation = -90.0
            case 4:
                rotation = 90.0
            default:
                break
        }
        return rotation
    }
}


// NSImage extension to init a context easily
extension NSImage: ObservableObject {
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
        let flipedImage = NSImage(size: newSize!)
        flipedImage.lockFocus()
        
        let t = NSAffineTransform.init()
        t.translateX(by: 0.0, yBy: (existingSize?.height)!)
        t.scaleX(by: 1.0, yBy: -1.0)
        t.concat()
        
        let rect:NSRect = NSMakeRect(0, 0, (newSize?.width)!, (newSize?.height)!)
        existingImage?.draw(at: NSZeroPoint, from: rect, operation: .sourceOver, fraction: 1.0)
        flipedImage.unlockFocus()
        return flipedImage
    }
}


// Read the raw data from a chunk file
// (This isn't done—currently hardcoded to read a single chunk of layer)
func getLayerData(_ layer: SilicaLayer, _ columns: Int, _ rows: Int, _ differenceX: Int, _ differenceY: Int, _ file: FileWrapper) -> [chunkImage] {
    var layer_chunks:Array<chunkImage> = []
    
    for column in 0..<columns {
        for row in 0..<rows {
            var chunk_tilesize:CGSize = CGSize(width: (layer.document?.tileSize)!, height: (layer.document?.tileSize)!)
            
            let filename = String(column) + "~" + String(row) + ".chunk"
            
            // Account for columns or rows that are too short
            if (column + 1 == columns) {
                chunk_tilesize.width = chunk_tilesize.width - CGFloat(differenceX)
            }
            if (row + 1 == rows) {
                chunk_tilesize.height = chunk_tilesize.height - CGFloat(differenceY)
            }
            
            let filepath = layer.UUID!.appending("/" + filename)
            
            let chunk:chunkImage = chunkImage(row, column, chunk_tilesize, filename, filepath)
            
            layer_chunks.append(chunk)
        }
    }
    
    return layer_chunks
}

func decompressChunk(_ file: FileWrapper, chunk: chunkImage) {
    
    guard let archive = Archive(data: file.regularFileContents!, accessMode: .read) else {
        return
    }
    guard let entry = archive[chunk.filepath!] else {
        return
    }

    do {
        chunk.data = Data()
        try _ = archive.extract(entry, bufferSize: UInt32(100000), consumer: { (data) in
            chunk.data?.append(data)
        })
        readChunkData(chunk)
    } catch {
        NSLog("\(error)")
    }
}



// Use miniLZO to decompress the pixel data from a chunk
func readChunkData(_ chunk: chunkImage) {
    let src_mutable:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk.data!.count)
    src_mutable.initialize(repeating: 0, count: chunk.data!.count)
    defer {
        src_mutable.deinitialize(count: chunk.data!.count)
//        src_mutable.deallocate()
    }
    chunk.data!.copyBytes(to: src_mutable, count: chunk.data!.count)
    let src:UnsafePointer<UInt8> = UnsafePointer(src_mutable)
    defer {
        src.deallocate()
    }
    let src_len:lzo_uint = lzo_uint(chunk.data!.count)
    
    // Calculate the final bite size of the decompressed image chunk
    let finalsize:Int = Int(chunk.tileSize!.width * chunk.tileSize!.height * 4)
    
    let dst:UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: finalsize)
    dst.initialize(repeating: 0, count: finalsize)
    defer {
        dst.deinitialize(count: finalsize)
        dst.deallocate()
    }
    var dst_len_2 = lzo_uint(finalsize)

    let r = lzo1x_decompress(src, src_len, dst, &dst_len_2, nil)
    // 0 = LZO_E_OK
    // -4 = LZO_E_INPUT_OVERRUN
    // -6 = LZO_E_LOOKBEHIND_OVERRUN
    if (r == LZO_E_OK) {
        let dst_pointer = UnsafePointer(dst)
        
        let chunk_image:NSImage = imageFromPixels(size: chunk.tileSize!, pixels: dst_pointer, width: Int(chunk.tileSize!.width), height: Int(chunk.tileSize!.height))
        
//        chunk.image = chunk_image.addTextToImage(drawText: "col: \(chunk.column!)\nrow: \(chunk.row!)")
        chunk.image = chunk_image
    } else {
        debugPrint("error during LZO decompress! :(")
        return
    }
}


// Create the image chunk from its pixel data
func imageFromPixels(size: NSSize, pixels: UnsafePointer<UInt8>, width: Int, height: Int) -> NSImage {
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo:CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let bitsPerComponent = 8 //number of bits in UInt8
    let bitsPerPixel = 4 * bitsPerComponent //ARGB uses 4 components
    let bytesPerRow = bitsPerPixel * width / 8 // bitsPerRow / 8 (in some cases, you need some paddings)
    let providerRef = CGDataProvider(
        data: NSData(bytes: pixels, length: height * bytesPerRow)
    )

    let cgim = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: bytesPerRow,
        space: rgbColorSpace,
        bitmapInfo: bitmapInfo,
        provider: providerRef!,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
    return NSImage(cgImage: cgim!, size: size)
}


// Composite image chunks into full layer image
func decompressAndCompositeImages(_ file: FileWrapper, _ metadata: SilicaDocument, _ chunks: Array<chunkImage>) -> NSImage? {
 
    var counter:CGFloat = 0
    
    var comp_image = NSImage(size: (metadata.size)!, actions: { ctx in
 
        DispatchQueue.global(qos: .userInitiated).sync {
            DispatchQueue.concurrentPerform(iterations: chunks.count, execute: { index in
                decompressChunk(file, chunk: chunks[index])
                
                let y_pos = CGFloat(metadata.tileSize! * (chunks[index].row!))

                let rect = CGRect(x: CGFloat(chunks[index].column!) * CGFloat(metadata.tileSize!), y: y_pos, width: chunks[index].image!.size.width, height: chunks[index].image!.size.height)
                let image = chunks[index].image!
                let flipped = image.flipVertically()
                
                ctx.draw(flipped.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: rect)
                
                DispatchQueue.main.sync {
                    // keep track of how many chunks have been read and update the progress bar
                    counter += 1
                    metadata.comp_load = counter / CGFloat(chunks.count)
                    metadata.objectWillChange.send()
                }
            })
        }
    
    })
    
    comp_image = comp_image.rotated(by: CGFloat(metadata.getRotation()) * -1)

    return comp_image
}


class chunkImage {
    var image:NSImage?
    var data:Data?
    var row:Int?
    var column:Int?
    var tileSize:CGSize?
    var filename: String?
    var filepath: String?
    
    init(_ row: Int, _ column: Int, _ tileSize: CGSize, _ filename: String, _ filepath: String) {
        self.row = row
        self.column = column
        self.tileSize = tileSize
        self.filename = filename
        self.filepath = filepath
    }
}


// Get the raw Document.archive data from a Procreate Document
public func getArchive(_ file: FileWrapper) -> SilicaDocument? {
    weak var archive_data:SilicaDocument?
    let pro_data:Data = file.regularFileContents!
    guard let archive = Archive(data: pro_data, accessMode: .read, preferredEncoding: nil) else {
        return nil
    }
    guard let entry = archive["Document.archive"] else {
        return nil
    }
    
    do {
        try _ = archive.extract(entry, bufferSize: UInt32(100000), skipCRC32: true, progress: nil, consumer: { (data) in
            archive_data = readProcreateData(data: data)!
        })
    } catch {
        NSLog("\(error)")
    }
    return archive_data
}

// Get the metadata from a Procreate Document
public func readProcreateData(data: Data) -> SilicaDocument? {
    do {
        if let decoded_data = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? SilicaDocument {
            return decoded_data
        }
    } catch {
        NSLog("Error reading data: \(error)")
    }
    return nil
}

extension NSImage {
    func rotated(by degrees: CGFloat) -> NSImage {
        let sinDegrees = abs(sin(degrees * CGFloat.pi / 180.0))
        let cosDegrees = abs(cos(degrees * CGFloat.pi / 180.0))
        let newSize = CGSize(width: size.height * sinDegrees + size.width * cosDegrees,
                             height: size.width * sinDegrees + size.height * cosDegrees)

        let imageBounds = NSRect(x: (newSize.width - size.width) / 2,
                                 y: (newSize.height - size.height) / 2,
                                 width: size.width, height: size.height)

        let otherTransform = NSAffineTransform()
        otherTransform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        otherTransform.rotate(byDegrees: degrees)
        otherTransform.translateX(by: -newSize.width / 2, yBy: -newSize.height / 2)

        let rotatedImage = NSImage(size: newSize)
        rotatedImage.lockFocus()
        otherTransform.concat()
        draw(in: imageBounds, from: CGRect.zero, operation: NSCompositingOperation.copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }

    public func save(as fileName: String, fileType: NSBitmapImageRep.FileType = .jpeg, at directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> Bool {
        let savelocation = directory.appendingPathComponent(fileName).appendingPathExtension(fileType.pathExtension)
        guard let tiffRepresentation = tiffRepresentation, directory.isDirectory, !fileName.isEmpty else { return false }
        do {
            try NSBitmapImageRep(data: tiffRepresentation)?
                .representation(using: fileType, properties: [:])?
                .write(to: savelocation)
            return true
        } catch {
            print(error)
            return false
        }
    }
    
    /// DEBUG -> Draw text over image
    public func addTextToImage(drawText text: String) -> NSImage {

        let targetImage = NSImage(size: self.size, flipped: false) { (dstRect: CGRect) -> Bool in

            self.draw(in: dstRect)
            let textColor = NSColor.red
            let textFont = NSFont.boldSystemFont(ofSize: 30)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = NSTextAlignment.left

            let textFontAttributes = [
                NSAttributedString.Key.font: textFont,
                NSAttributedString.Key.foregroundColor: textColor,
                ] as [NSAttributedString.Key : Any]

            let textOrigin = CGPoint(x: 0, y: 0)
            let rect = CGRect(origin: textOrigin, size: self.size)
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.scaleBy(x: -1.0, y: 1.0)
            ctx.translateBy(x: -self.size.width, y: 0.0)
            
            text.draw(in: rect, withAttributes: textFontAttributes)
            return true
        }
        return targetImage
    }
    // End Debug
}

extension URL {
    public var isDirectory: Bool {
       return (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

extension NSBitmapImageRep.FileType {
    public var pathExtension: String {
        switch self {
        case .bmp:
            return "bmp"
        case .gif:
            return "gif"
        case .jpeg:
            return "jpg"
        case .jpeg2000:
            return "jp2"
        case .png:
            return "png"
        case .tiff:
            return "tif"
        @unknown default:
            return "unknown"
        }
    }
}
