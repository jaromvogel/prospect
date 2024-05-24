//
//  ProcreateImage.swift
//  Prospect
//
//  Created by Vogel Family on 11/9/20.
//

import Foundation
import AppKit
import Cocoa
import ZIPFoundation

public extension SilicaDocument {
    
    func getLayer(_ layer: SilicaLayer?, _ file: FileWrapper, _ callback: @escaping () -> Void = {}) -> NSImage? {
        if (layer == nil) {
            if ((self.featureSet != nil) && self.featureSet == 2) {
                // ‼️‼️‼️ Generate thumb image rather than loading composite if this is a 3D file
                // This is unused now aside from exporting, which I'd like to replace
                self.composite_image = getThumbImage(file: file, altpath: nil)
            }
        } else {
            var size:CGSize = (layer?.contentsRect!.size)!
            if (self.composite != nil) {
                if (layer!.UUID == self.composite!.UUID) { // resolves issue where a procreate file may not have generated its composite layer size yet
                    size = self.size!
                }
            }

            let tileSize:Int = (self.tileSize)!
            
            // How many columns / rows of image chunks are in the file
            let columns:Int = Int(ceil(self.size!.width / CGFloat(tileSize)))
            let rows:Int = Int(ceil(self.size!.height / CGFloat(tileSize)))
            
            // For columns and rows that aren't multiples of tilesize, calculate how different they are
            var differenceX:Int = 0
            var differenceY:Int = 0
            if Int(size.width) % tileSize != 0 {
                differenceX = (columns * tileSize) - Int(layer!.document!.size!.width)
            }
            if Int(size.height) % tileSize != 0 {
                differenceY = (rows * tileSize) - Int(layer!.document!.size!.height) //something is messing up here in certain circumstances
            }
            
            let image_chunks:Array<chunkImage> = getLayerData(layer!, columns, rows, differenceX, differenceY, file)
            var buffer_img:NSImage?
            
            // If this is the composite layer:
            if (layer!.UUID == self.composite?.UUID) {

                DispatchQueue.global(qos: .userInitiated).async {
                    buffer_img = decompressAndCompositeImages(file, layer!, self, image_chunks)
                    DispatchQueue.main.async {
                        self.composite_image = buffer_img
                        callback()
                    }
                }
            } else {
                // Do something here to load non-composite layers
                buffer_img = decompressAndCompositeImages(file, layer!, self, image_chunks)
                return buffer_img
            }
        }
        return nil
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


/// BEGIN actually create the image

// Define an object we'll use to track data for each chunk
private class chunkImage {
    var image:NSImage?
    var colorSpace: String?
    var data:Data?
    var row:Int?
    var column:Int?
    var tileSize:CGSize?
    var filename: String?
    var filepath: String?
    var x_pos: CGFloat?
    var y_pos: CGFloat?
    var rect: CGRect?
    var type:Int?
    var lz4_compression: Bool?
    
    init(_ row: Int, _ column: Int, _ tileSize: CGSize, _ filename: String, _ filepath: String, _ colorSpace: String?, _ lz4_compression: Bool?, _ type: Int = 7) {
        self.row = row
        self.column = column
        self.tileSize = tileSize
        self.filename = filename
        self.filepath = filepath
        self.colorSpace = colorSpace
        self.type = type
        self.lz4_compression = lz4_compression
        self.x_pos = CGFloat(256 * CGFloat(self.column!))
        self.y_pos = CGFloat(256 * CGFloat(self.row!))
        self.rect = CGRect(x: self.x_pos!, y: self.y_pos!, width: self.tileSize!.width, height: self.tileSize!.height)
    }
}

// Read the raw data from a chunk file
private func getLayerData(_ layer: SilicaLayer, _ columns: Int, _ rows: Int, _ differenceX: Int, _ differenceY: Int, _ file: FileWrapper) -> [chunkImage] {
    var layer_chunks:Array<chunkImage> = []
    
    guard let archive = Archive(data: file.regularFileContents!, accessMode: .read) else {
        print("couldn't read procreate archive")
        return []
    }
    
    // Try hard coding something around here to check what's going on in each of the folders?
    let layer_dir = layer.UUID!.appending("/")
    let entries = archive.filter { $0.path.starts(with: layer_dir) }
    
    entries.forEach({ entry in
        autoreleasepool {
            var lz4_compression:Bool = false
            let filepath = entry.path(using: .utf8)
            if (filepath.contains(".lz4")) {
                lz4_compression = true
            }
            let filename = filepath.replacingOccurrences(of: layer_dir, with: "").replacingOccurrences(of: ".chunk", with: "").replacingOccurrences(of: ".lz4", with: "")
            let column = Int(filename.split(separator: "~")[0])!
            let row = Int(filename.split(separator: "~")[1])!
            
            var chunk_tilesize:CGSize = CGSize(width: (layer.document?.tileSize)!, height: (layer.document?.tileSize)!)
            
            if (column + 1 == columns) {
                chunk_tilesize.width = chunk_tilesize.width - CGFloat(differenceX)
            }
            if (row + 1 == rows) {
                chunk_tilesize.height = chunk_tilesize.height - CGFloat(differenceY)
            }
            let chunk:chunkImage = chunkImage(row, column, chunk_tilesize, filename, filepath, layer.document?.colorProfile?.SiColorProfileArchiveICCNameKey ?? nil, lz4_compression)

            layer_chunks.append(chunk)
        }
    })
    
    return layer_chunks
}

/// Composite image chunks into full layer image
private func decompressAndCompositeImages(_ file: FileWrapper, _ layer: SilicaLayer, _ metadata: SilicaDocument, _ chunks: Array<chunkImage>) -> NSImage? {

    var counter:CGFloat = 0
    
    var size:NSSize = metadata.size ?? NSSize(width: 2048, height: 2048)
    if (layer.sizeWidth != nil && layer.sizeWidth != 0) {
        size.width = CGFloat(layer.sizeWidth ?? 0)
    }
    if (layer.sizeHeight != nil && layer.sizeHeight != 0) {
        size.height = CGFloat(layer.sizeHeight ?? 0)
    }

    var layer_image = NSImage(size: size, actions: { ctx in
        
        ctx.interpolationQuality = .none // avoid weird resampling stuff that makes the image look blurry
        DispatchQueue.global(qos: .userInteractive).sync {
            DispatchQueue.concurrentPerform(iterations: chunks.count, execute: { index in
                autoreleasepool {
                    var grayscale: Bool = false
                    var grayscale_with_alpha: Bool = false
                    if (layer.type == 9) {
                        // This applies to composite (flattened) versions of roughness and metallic layers in a 3D file
                        grayscale = true
                    }
                    if (layer.type == 8) {
                        // This applies to individual roughness and metallic layers in a 3D file
                        grayscale_with_alpha = true
                    }
                    decompressChunk(file, chunk: chunks[index], grayscale: grayscale, grayscale_with_alpha: grayscale_with_alpha)
                    
                    let image = chunks[index].image!
                    let flipped = image.flipVertically()
                    chunks[index].image = flipped
                    
                    // keep track of how many chunks have been read
                    counter += 1
                    if (layer.UUID == metadata.composite?.UUID) {
                        DispatchQueue.main.sync {
                            // update the progress bar
                            metadata.comp_load = counter / CGFloat(chunks.count)
                            metadata.objectWillChange.send()
                        }
                    }
                }
            })
            assert(Int(counter) == chunks.count, "not all chunks are loaded!")
            for chunk in chunks {
                autoreleasepool {
                    // Draw all chunk images into the context
                    // I think this is the part that was causing the weird misplaced image chunks before when context drawing was happening in a multithreaded environment, but we'll see I guess
                    ctx.draw(chunk.image!.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: chunk.rect!)
                }
            }
        }
    
    })
    
    if (metadata.featureSet != 2) {
        layer_image = layer_image.rotated(by: CGFloat(metadata.getRotation()) * -1)
    }
    if (metadata.flippedVertically == true) {
        layer_image = layer_image.flipVertically()
    }
    if (metadata.flippedHorizontally == true) {
        layer_image = layer_image.flipHorizontally()
    }

//        assert(Int(counter) == chunks.count, "chunks not finished loading!")
    
    /// Correct image color and size here before returning
    let colorProfile:String? = metadata.colorProfile?.SiColorProfileArchiveICCNameKey
    var rep = unscaledBitmapImageRep(forImage: layer_image, colorProfile: colorProfile ?? "sRGB IEC61966-2.1") // default to sRGB if the file doesn't have a specific color profile

    if (colorProfile == "sRGB IEC61966-2.1") {
        rep = rep.retagging(with: NSColorSpace.extendedSRGB)!
    } else if (colorProfile == "Display P3") {
        rep = rep.retagging(with: NSColorSpace.displayP3)!
    } else if (colorProfile == "Generic CMYK Profile") {
        rep = rep.retagging(with: NSColorSpace.deviceCMYK)!
    }

    guard let data = rep.representation(using: .tiff, properties:[.compressionFactor: 1.0]) else {
        preconditionFailure()
    }
    let layer_image_color_corrected = NSImage(data: data)
    
    return layer_image_color_corrected
}

// unarchive the data from the chunk file, but don't do anything else yet
private func decompressChunk(_ file: FileWrapper, chunk: chunkImage, grayscale: Bool = false, grayscale_with_alpha: Bool = false) {
    
    guard let archive = Archive(data: file.regularFileContents!, accessMode: .read) else {
        print("couldn't read procreate archive")
        return
    }
    guard let entry = archive[chunk.filepath!] else {
        print("chunk archive entry at \(chunk.filepath!) doesn't exist")
        return
    }

    do {
        chunk.data = Data()
// DEBUG MODE
//        try _ = archive.extract(entry, bufferSize: UInt32(100000), skipCRC32: true, consumer: { (data) in
        try _ = archive.extract(entry, bufferSize: UInt32(100000), skipCRC32: false, consumer: { (data) in
            chunk.data?.append(data)
        })
        if (chunk.lz4_compression == false) {
            readChunkData(chunk, grayscale: grayscale, grayscale_with_alpha: grayscale_with_alpha)
        } else {
            readChunkLZ4Data(chunk, grayscale: grayscale, grayscale_with_alpha: grayscale_with_alpha)
        }
    } catch {
        NSLog("\(error)")
    }
}

// Use miniLZO to decompress the pixel data from a chunk
private func readChunkData(_ chunk: chunkImage, grayscale: Bool = false, grayscale_with_alpha: Bool = false) {
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
    let finalsize:Int = abs(Int(chunk.tileSize!.width * chunk.tileSize!.height * 4))
    
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
        
        let chunk_image:NSImage = imageFromPixels(size: chunk.tileSize!, pixels: dst_pointer, width: Int(chunk.tileSize!.width), height: Int(chunk.tileSize!.height), colorSpace: chunk.colorSpace, grayscale: grayscale, grayscale_with_alpha: grayscale_with_alpha, data_length: chunk.data!.count)
        
//        chunk.image = chunk_image.addTextToImage(drawText: "col: \(chunk.column!)\nrow: \(chunk.row!)")
        chunk.image = chunk_image
        
    } else {
        debugPrint("error during LZO decompress! :(")
        return
    }
}

private func readChunkLZ4Data(_ chunk: chunkImage, grayscale: Bool = false, grayscale_with_alpha: Bool = false) {
    do {
        let decompData = try (chunk.data! as NSData).decompressed(using: .lz4)

        let pixels = decompData.bytes.assumingMemoryBound(to: UInt8.self)
        
        let chunk_image:NSImage = imageFromPixels(size: chunk.tileSize!, pixels: pixels, width: Int(chunk.tileSize!.width), height: Int(chunk.tileSize!.height), colorSpace: chunk.colorSpace, grayscale: grayscale, grayscale_with_alpha: grayscale_with_alpha, data_length: chunk.data!.count)
        
        chunk.image = chunk_image
    } catch {
        debugPrint(error.localizedDescription)
    }
}


// Create the an actual image from the chunk's pixel data
private func imageFromPixels(size: NSSize, pixels: UnsafePointer<UInt8>, width: Int, height: Int, colorSpace: String?, grayscale: Bool = false, grayscale_with_alpha: Bool = false, data_length: Int) -> NSImage {
    
    var imageRef: CGImage?
    var bitmapInfo:CGBitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue)]
    var colorspace = CGColorSpaceCreateDeviceRGB()
    
    let bitsPerComponent = 8 //number of bits in UInt8
    var bytesPerPixel = 4 //ARGB uses 4 components
    if (grayscale == true) {
        bytesPerPixel = 1 //Grayscale uses 1 component
        bitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue)]
        colorspace = CGColorSpaceCreateDeviceGray()
    }
    if (grayscale_with_alpha == true) {
        bytesPerPixel = 2 // Grayscale uses 1 component, alpha uses 1 component
        bitmapInfo = [CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue)]
        colorspace = CGColorSpaceCreateDeviceGray()
    }
    let bitsPerPixel = bytesPerPixel * bitsPerComponent
    let bytesPerRow = bytesPerPixel * width
    let providerRef = CGDataProvider(
        data: NSData(bytes: pixels, length: height * bytesPerRow)
    )

    imageRef = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: bytesPerRow,
        space: colorspace,
        bitmapInfo: bitmapInfo,
        provider: providerRef!,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
    
    return NSImage(cgImage: imageRef!, size: size)
}



/// Code to deal with scaling the export image and retina resolution
/// Also handles part of colorspace logic
private func unscaledBitmapImageRep(forImage image: NSImage, colorProfile: String) -> NSBitmapImageRep {
    var hasAlpha = true
    var colorSpaceName:NSColorSpaceName = .deviceRGB
    if (colorProfile == "Generic CMYK Profile") {
        hasAlpha = false
        colorSpaceName = .deviceCMYK
    }
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(image.size.width),
        pixelsHigh: Int(image.size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: hasAlpha, // Needs to be false for CMYK
        isPlanar: false,
        colorSpaceName: colorSpaceName,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        preconditionFailure()
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.cgContext.interpolationQuality = .none
    image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    return rep
}
/// END: getting the actual image data


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
//DEBUG MODE
//        try _ = archive.extract(entry, bufferSize: UInt32(100000), skipCRC32: true, progress: nil, consumer: { (data) in
        var data_buffer:Data = Data()
        try _ = archive.extract(entry, bufferSize: UInt32(10000000), skipCRC32: false, progress: nil, consumer: { (data) in
            data_buffer.append(data)
        })
        archive_data = readProcreateData(data: data_buffer)!
    } catch {
        NSLog("\(error)")
    }
    return archive_data
}

// Get the metadata from a Procreate Document
public func readProcreateData(data: Data) -> SilicaDocument? {
    do {
//        if let decoded_data = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? SilicaDocument {
        if let decoded_data = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self,
                                                                                 NSDictionary.self,
                                                                                 NSString.self,
                                                                                 NSNumber.self,
                                                                                 NSData.self,
                                                                                 SilicaDocument.self,
                                                                                 ValkyrieDocumentAnimation.self,
                                                                                 ValkyrieDocumentTextureSet.self,
                                                                                 ValkyrieMaterialLayer.self,
                                                                                 ValkyrieText.self,
                                                                                 ValkyrieColorProfile.self,
                                                                                 ValkyrieDocumentMesh.self,
                                                                                 ValkyrieCachedMeshObject.self,
                                                                                 ValkyrieCachedMesh.self,
                                                                                 ValkyrieCachedMeshBuffer.self,
                                                                                 VideoSegmentInfo.self,
                                                                                 SilicaLayer.self,
                                                                                 SilicaGroup.self
                                                                                ], from: data) {
            return decoded_data as? SilicaDocument
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
    
    /// Draw text over image
    public func addTextToImage(drawText text: String) -> NSImage {

        let targetImage = NSImage(size: self.size, flipped: false) { (dstRect: CGRect) -> Bool in

            self.draw(in: dstRect)
            let textColor = NSColor.init(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
            let textFont = NSFont.boldSystemFont(ofSize: 40)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = NSTextAlignment.left

            let textFontAttributes = [
                NSAttributedString.Key.font: textFont,
                NSAttributedString.Key.foregroundColor: textColor,
                ] as [NSAttributedString.Key : Any]

            let textOrigin = CGPoint(x: 40, y: -29)
            let rect = CGRect(origin: textOrigin, size: self.size)
//            let ctx = NSGraphicsContext.current!.cgContext
//            ctx.scaleBy(x: -1.0, y: 1.0)
//            ctx.translateBy(x: -self.size.width, y: 0.0)
            
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
