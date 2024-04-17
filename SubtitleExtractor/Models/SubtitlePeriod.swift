//
//  SubtitlePeriod.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/22.
//

import AVFoundation

class SubtitlePeriod {
    
    // 该时段识别的所有字幕集合
    var periodSubtitle = [String: Int]()
    
    // 字幕时段开始时间
    var startTime: CMTime = CMTime()
    
    // 字幕时段结束时间
    var endTime: CMTime = CMTime()
    
    // 获取当前重复最多的字幕
    func getSubtitle() -> String? {
        if let (key, _) = self.periodSubtitle.max(by: { a, b in a.value < b.value }) {
            return key
        }
        return ""
    }
    
    // 添加片段首条字幕
    public func addStartPeriod(subtitle: String , with time: CMTime) {
        self.startTime = time
        self.endTime = time
        self.periodSubtitle.removeAll()
        self.periodSubtitle[subtitle] = 1
    }
    
    // 添加片段字幕
    public func addPeriod(subtitle: String , with time: CMTime) {
        
        if let count = self.periodSubtitle[subtitle] {
            self.periodSubtitle[subtitle] = count + 1
        } else {
            self.periodSubtitle[subtitle] = 1
        }
        self.endTime = time
    }
    
    // 重置
    public func reset() {
        self.startTime = CMTime()
        self.endTime = CMTime()
        self.periodSubtitle.removeAll()
    }
    
    // 获取当前区间srt格式字幕内容
    public func getSrtFormatTimeString() -> String {
        
        let startTimeString = getTimeString(by: self.startTime)
        let endTimeString = getTimeString(by: self.endTime)
        let srtString = "\(startTimeString) --> \(endTimeString)\r\n\(getSubtitle() ?? "")\r\n\r\n"
        return srtString
    }
    
    // 获取字幕格式时间字符
    private func getTimeString(by time: CMTime) -> String {
        
        let presentationTimeInSeconds = CMTimeGetSeconds(time);
        let hours = Int(presentationTimeInSeconds / 3600)
        let minutes = Int((presentationTimeInSeconds - Double(hours) * 3600) / 60)
        let seconds = Int(presentationTimeInSeconds - Double(hours) * 3600 - Double(minutes) * 60)
        let milliseconds = Int((presentationTimeInSeconds - floor(presentationTimeInSeconds)) * 1000)
        let timeCode = String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
        
        return timeCode
    }
    
    func merge(from other: SubtitlePeriod) {
        self.endTime = other.endTime
        self.periodSubtitle.merge(other.periodSubtitle) {
            $0 + $1
        }
    }
}
