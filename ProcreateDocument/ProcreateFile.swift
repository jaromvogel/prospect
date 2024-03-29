import Foundation
import Cocoa
import CoreGraphics
import AVFoundation

// Silica Document
@objc(SilicaDocument)
public class SilicaDocument: NSObject, NSCoding, ObservableObject {
    @Published public var composite_image:NSImage?
    @Published public var videoPlayer:AVPlayer?
    public var comp_load:CGFloat = 0.0
    
    public var animation:ValkyrieDocumentAnimation?
    public var authorName:String?
    public var backgroundColor:Data?
    public var backgroundHidden:Bool?
    public var backgroundColorHSBA:Data?
    public var closedCleanlyKey:Bool?
    public var colorProfile:ValkyrieColorProfile?
    public var composite:SilicaLayer?
//  public var drawingguide
    public var faceBackgroundHidden:Bool?
    public var featureSet:Int? = 1
    public var flippedHorizontally:Bool?
    public var flippedVertically:Bool?
    public var isFirstItemAnimationForeground:Bool?
    public var isLastItemAnimationBackground:Bool?
//  public var lastTextStyling
    public var layers:[SilicaLayer]?
    public var mask:SilicaLayer?
    public var name:String?
    public var orientation:Int?
    public var primaryItem:Any?
//  skipping a bunch of reference window related stuff here
    public var selectedLayer:Any?
    public var selectedSamplerLayer:SilicaLayer?
    public var SilicaDocumentArchiveDPIKey:Float?
    public var SilicaDocumentArchiveUnitKey:Int?
    public var SilicaDocumentTrackedTimeKey:Float?
    public var SilicaDocumentVideoPurgedKey:Bool?
    public var SilicaDocumentVideoSegmentInfoKey:VideoSegmentInfo? // not finished
    public var size: CGSize?
    public var solo: SilicaLayer?
    public var strokeCount: Int?
    public var tileSize: Int?
    public var videoEnabled: Bool? = true
    public var videoQualityKey: String?
    public var videoResolutionKey: String?
    public var videoDuration: String? = "Calculating..."
    
    
    public func encode(with coder: NSCoder) {
        
    }
    
    public required init?(coder: NSCoder) {
        animation = coder.decodeObject(forKey: "animation") as! ValkyrieDocumentAnimation?
        authorName = coder.decodeObject(forKey: "authorName") as! String?
        backgroundColor = coder.decodeObject(forKey: "backgroundColor") as! Data?
        backgroundHidden = coder.decodeBool(forKey: "backgroundHidden")
        backgroundColorHSBA = coder.decodeObject(forKey: "backgroundColorHSBA") as! Data?
        closedCleanlyKey = coder.decodeBool(forKey: "closedCleanlyKey")
        colorProfile = coder.decodeObject(forKey: "colorProfile") as! ValkyrieColorProfile?
        composite = coder.decodeObject(forKey: "composite") as! SilicaLayer?
        faceBackgroundHidden = coder.decodeBool(forKey: "faceBackgroundHidden")
        featureSet = coder.decodeInteger(forKey: "featureSet")
        flippedHorizontally = coder.decodeBool(forKey: "flippedHorizontally")
        flippedVertically = coder.decodeBool(forKey: "flippedVertically")
        isFirstItemAnimationForeground = coder.decodeBool(forKey: "isFirstItemAnimationForeground")
        isLastItemAnimationBackground = coder.decodeBool(forKey: "isLastItemAnimationBackground")
        layers = coder.decodeObject(forKey: "layers") as! [SilicaLayer]?
        mask = coder.decodeObject(forKey: "mask") as! SilicaLayer?
        name = coder.decodeObject(forKey: "name") as! String?
        orientation = coder.decodeInteger(forKey: "orientation")
        primaryItem = coder.decodeObject(forKey: "primaryItem")
        selectedLayer = coder.decodeObject(forKey: "selectedLayer")
        selectedSamplerLayer = coder.decodeObject(forKey: "selectedSamplerLayer") as! SilicaLayer?
        SilicaDocumentArchiveDPIKey = coder.decodeFloat(forKey: "SilicaDocumentArchiveDPIKey")
        SilicaDocumentArchiveUnitKey = coder.decodeInteger(forKey: "SilicaDocumentArchiveUnitKey")
        SilicaDocumentTrackedTimeKey = coder.decodeFloat(forKey: "SilicaDocumentTrackedTimeKey")
        SilicaDocumentVideoPurgedKey = coder.decodeBool(forKey: "SilicaDocumentVideoPurgedKey")
        SilicaDocumentVideoSegmentInfoKey = coder.decodeObject(forKey: "SilicaDocumentVideoSegmentInfoKey") as! VideoSegmentInfo?
        size = coder.decodeSize(forKey: "size")
        solo = coder.decodeObject(forKey: "solo") as! SilicaLayer?
        strokeCount = coder.decodeObject(forKey: "strokeCount") as! Int?
        tileSize = coder.decodeInteger(forKey: "tileSize")
        if (coder.containsValue(forKey: "videoEnabled") == true) {
            videoEnabled = coder.decodeBool(forKey: "videoEnabled")
        }
        videoQualityKey = coder.decodeObject(forKey: "videoQualityKey") as! String?
        videoResolutionKey = coder.decodeObject(forKey: "videoResolutionKey") as! String?
    }
    
    deinit {
        self.cleanUp()
    }
    
    public func cleanUp() {
        self.composite_image = nil
        self.videoPlayer = nil
        self.animation = nil
        self.authorName = nil
        self.backgroundColor = nil
        self.backgroundHidden = nil
        self.backgroundColorHSBA = nil
        self.closedCleanlyKey = nil
        self.colorProfile = nil
        self.composite = nil
        self.faceBackgroundHidden = nil
        self.featureSet = nil
        self.flippedHorizontally = nil
        self.flippedVertically = nil
        self.isFirstItemAnimationForeground = nil
        self.isLastItemAnimationBackground = nil
        self.layers = nil
        self.mask = nil
        self.name = nil
        self.orientation = nil
        self.primaryItem = nil
        self.selectedLayer = nil
        self.selectedSamplerLayer = nil
        self.SilicaDocumentArchiveDPIKey = nil
        self.SilicaDocumentArchiveUnitKey = nil
        self.SilicaDocumentTrackedTimeKey = nil
        self.SilicaDocumentVideoPurgedKey = nil
        self.SilicaDocumentVideoSegmentInfoKey = nil
        self.size = nil
        self.solo = nil
        self.strokeCount = nil
        self.tileSize = nil
        self.videoEnabled = nil
        self.videoQualityKey = nil
        self.videoResolutionKey = nil
        self.videoDuration = nil
    }
}


// Silica Layer
@objc(SilicaLayer)
public class SilicaLayer: NSObject, NSCoding {
    public var animationHeldLength:Int?
    public var blend:Int?
    public var bundledImagePath:String?
    public var bundledMaskPath:String?
    public var bundledVideoPath:String?
    public var clipped:Bool?
    public var contentsRect:NSRect?
    public var contentsRectValid:Bool?
    public var document:SilicaDocument?
    public var extendedBlend:Int?
    public var hidden:Bool?
    public var locked:Bool?
    public var mask:SilicaLayer?
    public var name:String?
    public var opacity:Float?
    public var perspectiveAssisted:Bool?
    public var preserve:Bool?
    public var `private`:Bool?
    public var text:ValkyrieText?
    public var textPDF:Data?
    public var transform:Data?
    public var type:Int?
    public var UUID:String?
    public var version:Int?
    public var videoTime:NSDictionary?
    
    public func encode(with coder: NSCoder) {}

    public required init?(coder: NSCoder) {
        animationHeldLength = coder.decodeInteger(forKey: "animationHeldLength")
        blend = coder.decodeInteger(forKey: "blend")
        bundledImagePath = coder.decodeObject(forKey: "bundledImagePath") as! String?
        bundledMaskPath = coder.decodeObject(forKey: "bundledMaskPath") as! String?
        bundledVideoPath = coder.decodeObject(forKey: "bundledVideoPath") as! String?
        clipped = coder.decodeBool(forKey: "clipped")
        let contentsRectData = coder.decodeObject(forKey: "contentsRect") as AnyObject
        contentsRect = contentsRectData.bytes!.load(as: NSRect.self) // Messy, but it seems to work!
        contentsRectValid = coder.decodeBool(forKey: "contentsRectValid")
        document = coder.decodeObject(forKey: "document") as! SilicaDocument?
        extendedBlend = coder.decodeInteger(forKey: "extendedBlend")
        hidden = coder.decodeBool(forKey: "hidden")
        locked = coder.decodeBool(forKey: "locked")
        mask = coder.decodeObject(forKey: "mask") as! SilicaLayer?
        name = coder.decodeObject(forKey: "name") as! String?
        opacity = coder.decodeFloat(forKey: "opacity")
        perspectiveAssisted = coder.decodeBool(forKey: "perspectiveAssisted")
        preserve = coder.decodeBool(forKey: "preserve")
        `private` = coder.decodeBool(forKey: "private")
        text = coder.decodeObject(forKey: "text") as! ValkyrieText?
        textPDF = coder.decodeObject(forKey: "textPDF") as! Data?
        transform = coder.decodeObject(forKey: "transform") as! Data?
        type = coder.decodeInteger(forKey: "type")
        UUID = coder.decodeObject(forKey: "UUID") as! String?
        version = coder.decodeInteger(forKey: "version")
        videoTime = coder.decodeObject(forKey: "videoTime") as! NSDictionary?
    }
}


// Silica Group
@objc(SilicaGroup)
public class SilicaGroup: NSObject, NSCoding {
    public var children:[SilicaLayer]?
    public var document:SilicaDocument?
    public var isCollapsed:Bool?
    public var isHidden:Bool?
    public var name:String?
    public var opacity:Float?
    
    public func encode(with coder: NSCoder) {}
    
    public required init?(coder: NSCoder) {
        children = coder.decodeObject(forKey: "children") as! [SilicaLayer]?
        document = coder.decodeObject(forKey: "document") as! SilicaDocument?
        isCollapsed = coder.decodeBool(forKey: "isCollapsed")
        isHidden = coder.decodeBool(forKey: "isHidden")
        name = coder.decodeObject(forKey: "name") as! String?
        opacity = coder.decodeFloat(forKey: "opacity")
    }
    
    
}


// Valkyrie Document Animation
@objc(ValkyrieDocumentAnimation)
public class ValkyrieDocumentAnimation: NSObject, NSCoding {
    public var coloredSkins:Bool?
    public var enabled:Bool?
    public var frameRate:Int?
    public var onionSkinCount:Int?
    public var onionSkinOpacity:Float?
    public var playbackDirection:Int?
    public var playbackMode:Int?
    public var primaryMixed:Bool?
    
    public func encode(with coder: NSCoder) {}
    
    public required init?(coder: NSCoder) {
        coloredSkins = coder.decodeBool(forKey: "coloredSkins")
        enabled = coder.decodeBool(forKey: "enabled")
        frameRate = coder.decodeInteger(forKey: "frameRate")
        onionSkinCount = coder.decodeInteger(forKey: "onionSkinCount")
        onionSkinOpacity = coder.decodeFloat(forKey: "onionSkinOpacity")
        playbackDirection = coder.decodeInteger(forKey: "playbackDirection")
        playbackMode = coder.decodeInteger(forKey: "playbackMode")
        primaryMixed = coder.decodeBool(forKey: "primaryMixed")
    }
}


// Valkyrie Color Profile
@objc(ValkyrieColorProfile)
public class ValkyrieColorProfile: NSObject, NSCoding {
    public var SiColorProfileArchiveICCDataKey:Data?
    public var SiColorProfileArchiveICCNameKey:String?
    
    public func encode(with coder: NSCoder) {}
    
    public required init?(coder: NSCoder) {
//        SiColorProfileArchiveICCDataKey = coder.decodeObject(forKey: "SiColorProfileArchiveICCDataKey") as! Data? //Not working because I'm trying to decode data as an object? Or something like that.
        SiColorProfileArchiveICCNameKey = coder.decodeObject(forKey: "SiColorProfileArchiveICCNameKey") as! String?
    }
    
}


// Valkyrie Text
@objc(ValkyrieText)
public class ValkyrieText: NSObject, NSCoding {
    // Come back to this...
    
    public func encode(with coder: NSCoder) {}

    public required init?(coder: NSCoder) {
        
    }
}


// Video Segment Info
@objc(VideoSegmentInfo)
public class VideoSegmentInfo: NSObject, NSCoding {
    public var bitrate: NSNumber?
    public var codec: Int?
    public var codec2020: Int?
    public var colorSpace: Int?
    public var frameSize: CGSize?
    public var framesPerSecond: Int?
    public var qualityPreferenceKey: String?
    public var resolutionPreferenceKey: String?
    public var sourceOrientation: Int?
    
    public func encode(with coder: NSCoder) {}

    public required init?(coder: NSCoder) {
        bitrate = coder.decodeObject(forKey: "bitrate") as! NSNumber?
        frameSize = coder.decodeSize(forKey: "frameSize")
        sourceOrientation = coder.decodeInteger(forKey: "sourceOrientation")
    }

    
}

// get rgba as float array from data
public extension Data {
    var float_array:[Float] {
        var float_array = Array<Float>(repeating: 0, count: self.count/MemoryLayout<Float>.stride)
        _ = float_array.withUnsafeMutableBytes { self.copyBytes(to: $0) }
        return float_array
    }
}
