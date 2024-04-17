//
//  VideoControlView.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/22.
//

import SwiftUI
import AVKit


//extension VideoFrameDisplayView {
//    func convertCVImageBufferToNSImage(_ cvImageBuffer: CVImageBuffer?) -> NSImage? {
//           guard let cvImageBuffer = cvImageBuffer else {
//               return nil
//           }
//
//           let ciImage = CIImage(cvImageBuffer: cvImageBuffer)
//           let context = CIContext()
//           if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
//               return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
//           }
//
//           return nil
//       }
//}
//
//struct VideoFrameDisplayView: View {
//
//    @State var currentFrameIndex: Double = 0
//
//    @EnvironmentObject var extractorViewModel: VideoSubtitleExtractorViewModel
//
//    var body: some View {
//        VStack {
//            ZStack {
//                Image(nsImage: convertCVImageBufferToNSImage(extractorViewModel.currentImageBuffer) ?? NSImage())
//                    .background(Color(.black))
//            }.frame(width: 1280, height: 720)
//            Slider(value: $extractorViewModel.currentFrameIndex,
//                   in: 0...extractorViewModel.totalFrameCount)
//            .disabled(extractorViewModel.videoState == .processing || extractorViewModel.videoState == .initial)
//
//            Text("\(extractorViewModel.currentFrameIndex)")
//            Text("\(extractorViewModel.totalFrameCount)")
////            Text(videoURL?.absoluteString ?? "nil")
//            VideoSubtitleReactView(state: extractorViewModel.videoState) { rect in
//                print(rect)
//            }
//
//            Button {
//                let openPanel = NSOpenPanel()
//                openPanel.allowsMultipleSelection = false
//                openPanel.canChooseFiles = true
//                openPanel.canChooseDirectories = false
//                openPanel.allowedFileTypes = ["MP4"] // Allowed file types
//
//                if openPanel.runModal() == NSApplication.ModalResponse.OK {
//                    if let selectedFileURL = openPanel.urls.first {
//                        print(selectedFileURL)
//                        extractorViewModel.loadVideo(from: selectedFileURL)
//                        currentFrameIndex = 0
//                    }
//                }
//            } label: {
//                Text("选择文件")
//            }.disabled(extractorViewModel.videoState == .processing)
//        }
//    }
//}


struct VideoControlView: View {
    
    @Binding var videoURL: URL?
    
    @State var sourceSrtURL: URL?

    @State var selectedItems = [String]()
    
    private let viewSize = CGSizeMake(1280, 720)
    @State var regionOfSubtitle = CGRectZero
    
    @EnvironmentObject var extractorViewModel: VideoSubtitleExtractorViewModel
    @EnvironmentObject var translateViewModel: SubtitleTranslateViewModel
    
    var videoPlayerSize: CGSize {
        get {
            let videoFrameSize = extractorViewModel.videoInfo.videoFrameSize
            if videoFrameSize.height == 0 || videoFrameSize.width == 0 {
                return CGSizeZero
            }
            // 适配视频播放器大小
            let viewAspectRatio = viewSize.width / viewSize.height
            let videoAspectRatio = videoFrameSize.width / videoFrameSize.height
            if viewAspectRatio > videoAspectRatio {
                let videoHeight = viewSize.height
                let videoWidth = videoFrameSize.width * (viewSize.height / videoFrameSize.height)
                return CGSizeMake(videoWidth, videoHeight)
            } else if viewAspectRatio < videoAspectRatio {
                let videoWidth = viewSize.width
                let videoHeight = videoFrameSize.height * (viewSize.width / videoFrameSize.width)
                return CGSizeMake(videoWidth, videoHeight)
            } else {
                return viewSize
            }
        }
    }
    
    
    var body: some View {
        VStack {
            ZStack(alignment: .center) {
                // 视频显示
                VideoPlayerView(url: videoURL,
                                currentTime: $extractorViewModel.videoProcessInfo.currentTime,
                                state: $extractorViewModel.state)
                .frame(width: videoPlayerSize.width, height: videoPlayerSize.height)
                
                // 字幕选择
                SubtitleRectSelectionView(currentRectangle: $regionOfSubtitle) { rect in
                    // 计算
                    if rect.isEmpty {
                        return
                    }
                    let x = rect.origin.x / videoPlayerSize.width
                    let y = (videoPlayerSize.height - rect.origin.y - rect.height) / videoPlayerSize.height
                    let roiRect = CGRectMake(x, y, rect.width / videoPlayerSize.width, rect.height / videoPlayerSize.height)
                    extractorViewModel.setRoiRect(rect: roiRect)
                    
                }.disabled(extractorViewModel.state == .initial || extractorViewModel.state == .processing)
                    .frame(width: videoPlayerSize.width, height: videoPlayerSize.height)

            }
            .frame(width: viewSize.width, height: viewSize.height)
            .background(.black)
            
            // 控制条
            let value = CMTimeGetSeconds(extractorViewModel.videoInfo.duration)
            Slider(value: $extractorViewModel.videoProcessInfo.currentTime,
                   in: 0...value)
            .disabled(extractorViewModel.state == .processing || extractorViewModel.state == .initial)
            
            Text("Range: \(extractorViewModel.startTime, specifier: "%.2f") - \(extractorViewModel.endTime, specifier: "%.2f")")
//            RangeSlider(lowerValue: $extractorViewModel.startTime, upperValue: $extractorViewModel.endTime, range: 0...CMTimeGetSeconds(extractorViewModel.videoInfo.duration))
           
            HStack {
                VStack {
                    Text("\(extractorViewModel.videoProcessInfo.currentTime)")
                    Text("\(CMTimeGetSeconds(extractorViewModel.videoInfo.duration))")
                    
                    HStack {
                        Text("开始时间:\(extractorViewModel.startTime)")
                        Button {
                            extractorViewModel.startTime = extractorViewModel.videoProcessInfo.currentTime
                        } label: {
                            Text("设定")
                                .frame(width: 100, height: 50)
                        }
                    }
                    
                    HStack {
                        Text("结束时间:\(extractorViewModel.endTime)")
                        Button {
                            extractorViewModel.endTime = extractorViewModel.videoProcessInfo.currentTime
                        } label: {
                            Text("设定")
                                .frame(width: 100, height: 50)
                        }
                    }
                    
                    FileSelector(title: "选择", placeHolder: "请选择MP4文件", allowedFileTypes: ["mp4"]) { selectedUrl in
                        videoURL = selectedUrl
                        regionOfSubtitle = CGRectZero
                        extractorViewModel.loadVideo(from: selectedUrl)
                    }
                    .disabled(extractorViewModel.state == .processing)
                    
                    HStack {
                        Text(extractorViewModel.outputSubtitleFilePath?.relativePath ?? "")
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(height: 30)
                        Button {
                            if let folderPath = extractorViewModel.outputSubtitleFilePath?.deletingLastPathComponent().path {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderPath)
                            }
                        } label: {
                            Text("打开文件夹")
                                .frame(width: 100, height: 50)
                            //                        .background(Color(.red))
                            //                        .foregroundColor(.blue)
                                .cornerRadius(10)
                        }.disabled(extractorViewModel.state != .done)
                    }
                    
                    // 开始/停止
                    HStack {
                        Button {
                            extractorViewModel.start()
                        } label: {
                            Text("开始")
                        }.disabled(extractorViewModel.state == .initial || extractorViewModel.state == .processing)
                        
                        Button {
                            extractorViewModel.stop()
                        } label: {
                            Text("停止")
                        }.disabled(extractorViewModel.state != .processing)
                    }
                    
                }
                
                VStack {
                    
                    FileSelector(title: "选择字幕文件",
                                 placeHolder: "请选择字幕文件",
                                 allowedFileTypes: ["srt"]) { selectedUrl in
                        sourceSrtURL = selectedUrl
                        translateViewModel.translateState = .prepared
                    }.disabled(translateViewModel.translateState == .processing)
                    
                    HStack {
                        Picker("翻译服务", selection: $translateViewModel.translateService) {
                            ForEach(TranslateService.allCases, id: \.self) { servece in
                                Text(servece.rawValue).tag(servece)
                            }
                        }
                        .pickerStyle(.inline)
                        .disabled(translateViewModel.translateState == .processing)
                    }
                    
                    
                    
                    Button {
                        translateViewModel.translateSrt(with: sourceSrtURL!, from: "zh" , to: "en")
                    } label: {
                        Text("开始翻译为英文")
                    }
                    .disabled(translateViewModel.translateState == .initial || translateViewModel.translateState == .processing)
                    
                    Button {
                        translateViewModel.translateSrt(with: sourceSrtURL!, from: "zh" , to: "ja")
                    } label: {
                        Text("开始翻译为日文")
                    }
                    .disabled(translateViewModel.translateState == .initial || translateViewModel.translateState == .processing)
                    Button {
                        translateViewModel.translateSrt(with: sourceSrtURL!, from: "zh" , to: "ko")
                    } label: {
                        Text("开始翻译为韩文")
                    }
                    .disabled(translateViewModel.translateState == .initial || translateViewModel.translateState == .processing)
                    Button {
                        translateViewModel.translateSrt(with: sourceSrtURL!, from: "zh" , to: "id")
                    } label: {
                        Text("开始翻译为印尼文")
                    }
                    .disabled(translateViewModel.translateState == .initial || translateViewModel.translateState == .processing)
                    Button {
                        translateViewModel.translateSrt(with: sourceSrtURL!, from: "zh" , to: "th")
                    } label: {
                        Text("开始翻译为泰文(ms)")
                    }
                    .disabled(translateViewModel.translateState == .initial || translateViewModel.translateState == .processing)
                }
                
                Spacer()
                
            }

        }
        .padding()
    }
    
    
    func getVideoSize() {
        
    }
}

//struct VideoControlView_Previews: PreviewProvider {
//    static var previews: some View {
//        VideoControlView(currentTime: (0.0), videoURL: URL(fileURLWithPath: "/Users/wangwei/Desktop/output.mp4")!)
//    }
//}



