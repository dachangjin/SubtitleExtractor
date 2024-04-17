//
//  VideoInfo.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/24.
//

import Foundation
import AVFoundation

struct VideoInfo {
    
    var fps: Double = 0
        
    var totalFrameCount: Double = 0
                                 
    var duration: CMTime = CMTime(value: 0, timescale: 1)
                            
    var videoFrameSize: CGSize = CGSize()
}
