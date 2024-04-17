//
//  VideoPlayerView.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/24.
//

import SwiftUI
import AVKit



struct VideoPlayerView: NSViewRepresentable {
    
    var url: URL?
    @Binding var currentTime: Double
    @Binding var state: VideoProcessState
    @State var playerView = AVPlayerView()
    
    func makeNSView(context: NSViewRepresentableContext<VideoPlayerView>) -> AVPlayerView {
        // Hide controls
        playerView.controlsStyle = .none
        if url != nil {
            loadPlayer(with: url!, context: context)
        }
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: NSViewRepresentableContext<VideoPlayerView>) {
        
        if url != nil && state == .initial {
            loadPlayer(with: url!, context: context)
        }
        guard let play = nsView.player  else {
            return
        }
        play.seek(to: CMTimeMake(value: Int64(currentTime + 0.5), timescale: 1))
    }
    
    
    func makeCoordinator() -> VideoPlayerCoodinator {
        VideoPlayerCoodinator(parent: self)
    }
    
    func loadPlayer(with url: URL, context: NSViewRepresentableContext<VideoPlayerView>) {
        
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        player.addObserver(context.coordinator, forKeyPath: #keyPath(AVPlayer.status), context: nil)
//        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: nil) { time in
////            currentTime = CMTimeGetSeconds(time)
//            print("Current time: \(currentTime) seconds")
//        }
        playerView.player = player
    }

}


extension VideoPlayerView {
    
    class VideoPlayerCoodinator: NSObject {
        
        let parent: VideoPlayerView
        
        init(parent: VideoPlayerView) {
            self.parent = parent
            super.init()
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
               if keyPath == #keyPath(AVPlayer.status), let player = object as? AVPlayer {
                   switch player.status {
                   case .unknown:
                       print("Player status: Unknown")
                   case .readyToPlay:
                       print("Player status: Ready to play")
                       parent.state = .readyToStart
                   case .failed:
                       print("Player status: Failed")
                   @unknown default:
                       break
                   }
               }
           }
        
    }

}
