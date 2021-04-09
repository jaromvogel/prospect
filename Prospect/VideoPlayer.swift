//
//  VideoPlayer.swift
//  Prospect
//
//  Created by Vogel Family on 4/1/21.
//

import SwiftUI
import Combine
import Foundation
import ProcreateDocument
import UniformTypeIdentifiers
import AVFoundation
import AVKit


// Custom video player for timelapse
public struct PlayerContainerView: View {
    let player:AVQueuePlayer
    let videoMeta:VideoSegmentInfo
    
    public var body: some View {
        VStack {
            PlayerView(queuePlayer: player, videoMeta: videoMeta)
            PlayerControlsView(player: player)
        }
    }
}

public struct PlayerView: NSViewRepresentable {
    var queuePlayer:AVQueuePlayer
    var videoMeta:VideoSegmentInfo
    
    public func makeNSView(context: Context) -> some NSView {
        return PlayerNSView(queuePlayer: queuePlayer, videoMeta: videoMeta)
    }
    
    public func updateNSView(_ nsView: NSViewType, context: Context) {
        
    }
    
}

public class PlayerNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    var queuePlayer: AVQueuePlayer
    var videoMeta: VideoSegmentInfo
    
    init(queuePlayer: AVQueuePlayer, videoMeta: VideoSegmentInfo) {
        self.queuePlayer = queuePlayer
        self.videoMeta = videoMeta
        super.init(frame: .zero)
        
        let player = queuePlayer
        playerLayer.player = player
        
        // The idea here is to get the video metadata that should tell us what orientation it's supposed to be, but it doesn't seem like the metadata is very consistent?
        // I might be able to try something where I check if the video aspect matches the image aspect...? Or just not worry about it too much.
        print("video orientation =  \(videoMeta.sourceOrientation!)")
        let affineTransform = CGAffineTransform(rotationAngle: 0)
        playerLayer.setAffineTransform(affineTransform)
        
        wantsLayer = true
        layer?.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

public struct PlayerControlsView: View {
    @State var playerPaused = true
    @State var seekPos = 0.0
    
    let player: AVQueuePlayer
    
    init(player: AVQueuePlayer) {
        self.player = player
    }
    
    public var body: some View {
        HStack {
            Button(action: {
                self.playerPaused.toggle()
                if self.playerPaused {
                    self.player.pause()
                } else {
                    self.player.play()
                }
            }) {
                Image(systemName: playerPaused ? "play" : "pause")
            }
            Button(action: {
                self.player.seek(to: .zero)
                
            }) {
                Image(systemName: "arrow.counterclockwise")
            }
            Slider(value: $seekPos, in: 0...1, onEditingChanged: { _ in
              guard let item = self.player.currentItem else {
                return
              }
              let targetTime = self.seekPos * item.duration.seconds
              self.player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
            })
            .padding(.trailing, 20)
        }
    }
}

