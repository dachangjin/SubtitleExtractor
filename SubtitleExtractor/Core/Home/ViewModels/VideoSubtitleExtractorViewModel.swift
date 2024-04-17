//
//  VideoSubtitleExtractorViewModel.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/22.
//

import Foundation
import AVFoundation
import Vision
import VideoToolbox
import SwiftUI

typealias VideoInfoBlock = (_ fps: Double,
                            _ totalFrameCount: Double,
                            _ duration: Double,
                            _ videoFrameSize: CGSize) -> Void

typealias ProcessingBlock = (_ second: Double,
                             _ isCompleted: Bool,
                             _ processDuration: TimeInterval,
                             _ subtitlePeriods: [SubtitlePeriod]) -> Void

private let similarityFactor = 0.5

final class VideoSubtitleExtractorViewModel: NSObject,  ObservableObject {
    
    @Published var state: VideoProcessState = .initial
    @Published var videoInfo = VideoInfo()
    @Published var videoProcessInfo = VideoProcessInfo()
    @Published var srtSubtitleText = ""
    @Published var outputSubtitleFilePath: URL?
    @Published var subtitlePeriods: [SubtitlePeriod] = []
    @Published var startTime: Double = 0
    @Published var endTime: Double = 0
    
    private let extractor = VideoSubtitleExtractor()
    
    private var videoFileUrl: URL?
    
    public func loadVideo(from url: URL?) {
        
        if let url = url {
            videoFileUrl = url
            state = .initial
            resetVideoProcessInfo()
            resetroiRect()
            
            if let info = extractor.loadVideo(from: url) {
                videoInfo = info
                endTime = CMTimeGetSeconds(videoInfo.duration)
                startTime = 0
                print("fps:\(videoInfo.fps) totalFrameCount: \(videoInfo.totalFrameCount), duration: \(videoInfo.duration)")
            }
        }
        extractor.processingBlock = { [weak self] second, isCompleted, processDuration, subtitlePeriods in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async {
                strongSelf.videoProcessInfo.currentTime = second
                strongSelf.videoProcessInfo.isCompleted = isCompleted
                strongSelf.videoProcessInfo.processDuration = processDuration
                if isCompleted {
                    strongSelf.state = .done
                    strongSelf.persistSubtitleWithPeriods(periods: subtitlePeriods)
                }
            }
        }
    }
    
    public func start() {
        resetVideoProcessInfo()
        resetSubtitles()
        if extractor.start(startTime, endTime) {
            state = .processing
        }
    }
    
    public func stop() {
        state = .readyToStart
        if extractor.stop() {
            state = .readyToStart
        }
    }
    
    private func resetVideoProcessInfo() {
        self.videoProcessInfo.currentTime = 0
        self.videoProcessInfo.isCompleted = false
        self.videoProcessInfo.processDuration = 0
    }
    
    public func setRoiRect(rect: CGRect) {
        extractor.setRoiRect(rect: rect)
    }
    
    func resetroiRect() {
        extractor.setRoiRect(rect: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    
    func persistSubtitleWithPeriods(periods: [SubtitlePeriod]) {
        if periods.count < 1 {
            return
        }
        var subtitle = ""
        var validPeriods: [SubtitlePeriod] = []
        var sequence: Int32 = 1
        var validPeriod = periods.first!
        var merged = false
        for index in 1..<periods.count {
            let subtitlePeriod = periods[index]

            // merge similarity period
            if CMTimeGetSeconds(subtitlePeriod.startTime) - CMTimeGetSeconds(validPeriod.endTime) < 0.5 &&
                (validPeriod.getSubtitle() ?? "").cosineSimilarity(to: subtitlePeriod.getSubtitle() ?? "") > similarityFactor {
                validPeriod.merge(from: subtitlePeriod)
                merged = true
            } else {
                merged = false
                // jump
                if (subtitlePeriod.startTime == subtitlePeriod.endTime) {
                    continue
                }
            }
            
            if merged == false {
                subtitle.append("\(sequence)\r\n")
                subtitle.append(validPeriod.getSrtFormatTimeString())
                validPeriods.append(validPeriod)
                validPeriod = subtitlePeriod
                sequence += 1
            }
        }
        
        subtitle.append("\(sequence)\r\n")
        subtitle.append(validPeriod.getSrtFormatTimeString())
        validPeriods.append(validPeriod)
        
        srtSubtitleText = subtitle
        subtitlePeriods = validPeriods
        
        // writeToLocalFile
        if let url = videoFileUrl?.deletingPathExtension().appendingPathExtension("srt") {
            try? srtSubtitleText.write(to: url, atomically: true, encoding: .utf8)
            outputSubtitleFilePath = url
        }
    }
    
    func resetSubtitles() {
        srtSubtitleText = ""
        subtitlePeriods.removeAll()
    }

}





private class VideoSubtitleExtractor {
    
    private var endOfPeriod = false
    
    private var newPeriod = true
    
    private var stopped = true
    
    private var currentTime = CMTime()
    
    private var videoFps: Double = 0
    
    private var totalFrame: Double = 0
    
    private var startTime: TimeInterval = 0.0
    
    private var endTime: TimeInterval = 0.0
    
    private var subtitlePeriods: [SubtitlePeriod] = []
    
    private var currentSubtitlePeriod = SubtitlePeriod()
    
    private var regionOfInterest = CGRectZero
    
    private var asset: AVAsset?
    
    private var reader: AVAssetReader?
    
    var processingBlock: ProcessingBlock?
    
    // 是否开启使用VideoToolbox解码
    var enableGPUDecode = false
    
    // 是否支持快速识别模式，快速识别只支持["en-US", "fr-FR", "it-IT", "de-DE", "es-ES", "pt-BR"]
    var enableFastMode = false
    
    private var recognizeTextRequest : VNRecognizeTextRequest?
    
    func loadVideo(from url: URL) -> VideoInfo? {
        
        let asset = AVAsset(url: url)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        let frameRate = videoTrack.nominalFrameRate
        self.totalFrame = CMTimeGetSeconds(videoTrack.timeRange.duration) * Float64(frameRate)
        self.videoFps = Double(frameRate)
        self.asset = asset
        
        return VideoInfo(fps: self.videoFps, totalFrameCount: self.totalFrame, duration: asset.duration, videoFrameSize: videoTrack.naturalSize)
    }
    
    func setRoiRect(rect: CGRect) {
        regionOfInterest = rect
    }
    
   
    func start(_ from: Double,_ to: Double) -> Bool {
        if self.stopped == false {
            return false
        }
        self.stopped = false
        
        if asset == nil {
            return false
        }
        
        self.startTime = Date.timeIntervalSinceReferenceDate
        
        self.recognizeTextRequest = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.stopped {
                return
            }
            if (error != nil) {
                print(error!)
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            var subtitles: [String] = []
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                subtitles.append(topCandidate.string)
            }
            if (subtitles.count == 0) {
                return
            }
            
            let subtitle = subtitles.joined(separator: "\r\n")
            print(subtitle)
            strongSelf.endOfPeriod = false
            if (strongSelf.newPeriod) {
                strongSelf.newPeriod = false
                strongSelf.currentSubtitlePeriod.addStartPeriod(subtitle: subtitle, with: strongSelf.currentTime)
            } else {
                // 有可能连续两帧的字幕是不同的两个字幕，不应该放到同一个period里面。
                guard let preSubtitle = strongSelf.currentSubtitlePeriod.getSubtitle() else {
                    strongSelf.currentSubtitlePeriod.addPeriod(subtitle: subtitle, with: strongSelf.currentTime)
                    return
                }
                
                // 连续两帧字幕长相似度小于0.5，则判断是不同的字幕
                if (preSubtitle.cosineSimilarity(to: subtitle) < similarityFactor) {
                    strongSelf.addPeriodSubtitle()
                    strongSelf.currentSubtitlePeriod.addStartPeriod(subtitle: subtitle, with: strongSelf.currentTime)
                    strongSelf.newPeriod = false
                    return
                } else {
                    strongSelf.currentSubtitlePeriod.addPeriod(subtitle: subtitle, with: strongSelf.currentTime)
                }
                
            }
        }
        self.recognizeTextRequest!.recognitionLanguages = ["zh-Hans"]
        self.recognizeTextRequest!.usesLanguageCorrection = true
        if self.regionOfInterest != CGRectZero {
            self.recognizeTextRequest!.regionOfInterest = regionOfInterest
        }

        self.subtitlePeriods.removeAll()
        
        // 运行耗时基本取决于文字识别，获取视频帧耗时几乎可以忽略
        if (self.enableGPUDecode) {
            // TODO
        } else {
            DispatchQueue.global().async {
                self.softDecode(from, to)
            }
        }
        return true
    }
    
    func stop() -> Bool {
        if self.stopped == true {
            return false
        }
        self.stopped = true
        self.endOfPeriod = false
        self.newPeriod = true
        self.endTime = Date.timeIntervalSinceReferenceDate
        reader!.cancelReading()
        if let block = self.processingBlock {
            block(0, false, self.endTime - self.startTime, subtitlePeriods)
        }
        return true
    }
    
    
    func addPeriodSubtitle() {
        self.subtitlePeriods.append(self.currentSubtitlePeriod)
        print("add period: \(self.currentSubtitlePeriod.getSrtFormatTimeString())")
        self.currentSubtitlePeriod = SubtitlePeriod()
        self.newPeriod = true
    }
    
    private func softDecode(_ from: Double, _ to: Double) {
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                        kCVPixelBufferOpenGLCompatibilityKey as String: true,
            //            kCVPixelBufferIOSurfacePropertiesKey as String: []，
        ]
        let videoTrack = asset!.tracks(withMediaType: .video).first
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack!, outputSettings: outputSettings)
        let reader = try? AVAssetReader(asset: asset!)
        reader!.timeRange = CMTimeRange(start: CMTimeMakeWithSeconds(from, preferredTimescale: 1), end: CMTimeMakeWithSeconds(to, preferredTimescale: 1))
        reader!.add(videoOutput)
        reader!.startReading()
        self.reader = reader
        while let sampleBuffer = videoOutput.copyNextSampleBuffer() {
            if self.stopped {
                break
            }
            
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            

            if (pixelBuffer != nil) {
                
//                if let image = convertCVImageBufferToNSImage(imageBuffer: pixelBuffer!, rect: CGRect(x: 0, y: 0, width: 1280, height: 400)) {
//
//                }
                
                self.endOfPeriod = true
                
                let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer!, options: [:])
                self.currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//                let startTime = Date.timeIntervalSinceReferenceDate * 1000
                try? requestHandler.perform([self.recognizeTextRequest!])
//                let endTime = Date.timeIntervalSinceReferenceDate * 1000
                
//                print("文字识别耗时: " + String(endTime - startTime))
                if self.endOfPeriod == true && self.newPeriod == false {
                    self.addPeriodSubtitle()
                }
                CMSampleBufferInvalidate(sampleBuffer)
                if let block = self.processingBlock {
                    block(CMTimeGetSeconds(self.currentTime), false, Date.timeIntervalSinceReferenceDate - self.startTime, subtitlePeriods)
                }
                
            } else {
                self.addPeriodSubtitle()
                print("no pixelBuffer")
            }
        }
        // 关闭视频读取器
        reader!.cancelReading()
        self.endTime = Date.timeIntervalSinceReferenceDate
        self.stopped = true
        if let block = self.processingBlock {
            print("耗时: \(self.endTime - self.startTime)s")
            block(CMTimeGetSeconds(self.currentTime), true, self.endTime - self.startTime, subtitlePeriods)
        }
        
    }
    
    
    
    
    func convertCVImageBufferToNSImage(imageBuffer: CVImageBuffer, rect: CGRect) -> NSImage? {
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()

        if let cgImage = context.createCGImage(ciImage, from: rect) {
            
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        }
        
        return nil
    }
    
}

