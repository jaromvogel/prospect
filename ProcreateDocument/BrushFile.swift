//
//  BrushFile.swift
//  ProcreateDocument
//
//  Created by Vogel Family on 5/8/21.
//

import Foundation
import Cocoa
import CoreGraphics
import ZIPFoundation

@objc(ProcreateBrushset)
public class ProcreateBrushset: NSObject, ObservableObject {
    @Published public var brushes:[SilicaBrush]? = []
    public var brushsetImage:NSImage?
    public var brushset_load:CGFloat = 0.0
    
    public override init() {}
    
    public func getBrushsetImage(file: FileWrapper, brushLabels: Bool = true) {
        // Step 1: create archive and access brushset.plist file
        let archive = Archive(data: file.regularFileContents!, accessMode: .read, preferredEncoding: nil)
        let entry = archive!["brushset.plist"]
        var brushsetCompositeImage:NSImage?
        
        // Step 2: read brushset.plist file into a useful format
        var plist_data:Data = Data()
        do {
// DEBUG MODE
//            try _ = archive!.extract(entry!, bufferSize: UInt32(100000000), skipCRC32: true, consumer: { (data) in
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
        let brushsetname:String? = plistData["name"] as? String
        let brushlist:NSArray? = plistData["brushes"] as? NSArray
        
        // Step 3: loop through each brush in the brushes array, get it's thumbnail image, and draw it into the larger image
        let gap:Int = 7
        let composite_size:CGSize = CGSize(width: 600 + (2 * gap), height: ((184 + gap) * brushlist!.count) + gap)
        brushsetCompositeImage = NSImage(size: composite_size, actions: { ctx in
//            ctx.setFillColor(CGColor.init(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
//            ctx.fill(CGRect(origin: .zero, size: composite_size))
            for (brush_index, brush) in brushlist!.enumerated() {
                
                let archivepath = (brush as! String).appending("/Brush.archive")
                let brushObj = getBrushArchive(file, altpath: archivepath)
                
                let thumbpath = (brush as! String).appending("/QuickLook/Thumbnail.png")
                brushObj?.thumbnail = getThumbImage(file: file, altpath: thumbpath)
                
                self.brushes?.append(brushObj!)
                self.objectWillChange.send()
                
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
                
                if (brushLabels == true) {
                    brushObj!.thumbnail = brushObj!.thumbnail!.addTextToImage(drawText: brushObj!.name ?? "")
                }
                ctx.draw(brushObj!.thumbnail!.cgImage(forProposedRect: nil, context: nil, hints: nil)!, in: CGRect(origin: brush_thumb_pos, size: CGSize(width: 600, height: 184)))
            }
        })
        self.brushsetImage = brushsetCompositeImage!
        self.objectWillChange.send()
    }
}

@objc(SilicaBrush)
public class SilicaBrush: NSObject, NSCoding, ObservableObject {
    public var name:String?
    public var authorName:String?
    public var thumbnail:NSImage?
    
    public func encode(with coder: NSCoder) {}
    
    public required init?(coder: NSCoder) {
        name = coder.decodeObject(forKey: "name") as! String?
        authorName = coder.decodeObject(forKey: "authorName") as! String?
    }
}

// Get the raw Document.archive data from a Procreate Document
public func getBrushArchive(_ file: FileWrapper, altpath: String? = nil) -> SilicaBrush? {
    weak var archive_data:SilicaBrush?
    let brush_data:Data = file.regularFileContents!
    guard let archive = Archive(data: brush_data, accessMode: .read, preferredEncoding: nil) else {
        return nil
    }
    var path:String = "Brush.archive"
    if (altpath != nil) {
        path = altpath!
    }
    guard let entry = archive[path] else {
        return nil
    }
    
    do {
// DEBUG MODE
//        try _ = archive.extract(entry, bufferSize: UInt32(100000), skipCRC32: true, progress: nil, consumer: { (data) in
        try _ = archive.extract(entry, bufferSize: UInt32(100000), skipCRC32: true, progress: nil, consumer: { (data) in
            archive_data = readBrushData(data: data)!
        })
    } catch {
        NSLog("\(error)")
    }
    return archive_data
}

// Get the metadata from a Procreate Document
public func readBrushData(data: Data) -> SilicaBrush? {
    do {
        if let decoded_data = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? SilicaBrush {
            return decoded_data
        }
    } catch {
        NSLog("Error reading data: \(error)")
    }
    return nil
}
