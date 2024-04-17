//
//  SubtitleTranslateViewModel.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/25.
//

import Foundation


private struct SubtitleBlock {
    
    var startTime: String
    
    var endTime: String
    
    var orgContent: String
    
    var translatedContent: String?
    
}

final class SubtitleTranslateViewModel: NSObject, ObservableObject {
    
    @Published var translatedSubtitleFilePath: URL?
    
    @Published var translateState: TranslateState = .initial
    
    @Published var translateService: TranslateService = .deepl

    let targetLangs = ["en", "fr", "de", "it", "ja", "ru", "es"]
    
//    private let url = URL(string: "http://127.0.0.1:1188/translate")
    
    private let deeplUrl = URL(string: "http://127.0.0.1:3000/deeplTranslate")

    
//    private let url = URL(string: "https://api-free.deepl.com/v2/translate")

    // 本地翻译服务
    private let googleTranslationUrl = URL(string: "http://127.0.0.1:3000/googleTranslate")
    
    private let tencentTranslationUrl = URL(string: "http://127.0.0.1:3000/tencentTranslate")

    private let msTranslationUrl = URL(string: "http://127.0.0.1:3000/msTranslate")

    
    
    private let apiKey = "56be75a6-e297-a6af-a63e-19795b2445e9:fx"
    
    
    func translateSrt(with fileUrl: URL, from sourceLanguage: String, to targetLanguage: String) {
        if !fileUrl.isFileURL {
            return
        }
        DispatchQueue.global().async {
            
            guard let fileContent = try? String(contentsOfFile: fileUrl.path, encoding: .utf8) else {
                return
            }
            // 把srt格式字幕中每条字幕拆分，然后转换为content\r\n格式，翻译完后在拼接为srt格式。减少翻译成本。（deepl免费账号限频，Google等免费额度有限）

            DispatchQueue.main.async {
                self.translateState = .processing
            }
            
            let subtitleBlocks: [SubtitleBlock] = self.getSubtitleBlocks(from: fileContent)
            
            var subtitleBlockClutter: [[SubtitleBlock]] = []
            
            var content = ""
            var hasMore = false
            var subtiles = [SubtitleBlock]()
            
            var url = self.deeplUrl
            
            var requsetMaxSize = 1000
            var maxConcurrentTaskCout = 3
            
            if self.translateService == .google {
                url = self.googleTranslationUrl
                requsetMaxSize = 5000
            }
            if self.translateService == .tencent {
                url = self.tencentTranslationUrl
                requsetMaxSize = 5000
            }
            if self.translateService == .microsoft {
                url = self.msTranslationUrl
                requsetMaxSize = 5000
            }
            
            for subtitleBlock in subtitleBlocks {
                subtiles.append(subtitleBlock)
                // Google 建议每个请求上限为5k
                // https://cloud.google.com/translate/quotas?hl=zh-cn
                content.append(subtitleBlock.orgContent)
                if (content.count > requsetMaxSize) {
                    subtitleBlockClutter.append(subtiles)
                    subtiles = []
                    content = ""
                    hasMore = false
                } else {
                    hasMore = true
                }
            }
            if (hasMore) {
                subtitleBlockClutter.append(subtiles)
            }
            
            let semaphore = DispatchSemaphore(value: min(subtitleBlockClutter.count, maxConcurrentTaskCout))
            let group = DispatchGroup()
           
            
            for index in 0..<subtitleBlockClutter.count {
                // 添加任务到 DispatchGroup
                group.enter()
                semaphore.wait()
                
                self.translate(contents: subtitleBlockClutter[index].map({ $0.orgContent }),
                          sourceLanguage: sourceLanguage,
                          to: targetLanguage,
                          from: url!) {  data, resp ,err  in
                    if let err = err , let response = resp as? HTTPURLResponse, response.statusCode != 200 {
                        print(err)
                        print(response)
                        semaphore.signal()
                        group.leave()
                        return
                    }
                    guard let data = data, let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                        semaphore.signal()
                        group.leave()
                        return
                    }
                    if let error = dict["error"] as? Dictionary<String, Any> {
                        print("error: ", error)
                        semaphore.signal()
                        group.leave()
                        return
                    }
                    guard let results = dict["translations"] as? [Dictionary<String, Any>] else {
                        print("dict: ", dict)
                        semaphore.signal()
                        group.leave()
                        return
                    }
                    
                    if results.count == subtitleBlockClutter[index].count {
                        for jndex in 0..<subtitleBlockClutter[index].count {
                            subtitleBlockClutter[index][jndex].translatedContent = results[jndex]["translatedText"] as? String
                        }
                    }
                    semaphore.signal()
                    group.leave()
                }
            }
    
            // 等待所有任务完成
            group.notify(queue: DispatchQueue.global()) {
                // 在所有任务完成后异步执行
                print("All tasks completed, performing other tasks...")
                

                var result = ""
                let subtitleBlocks = subtitleBlockClutter.flatMap { $0 }
                for i in 0..<subtitleBlocks.count {
                    let subtitleBlock = subtitleBlocks[i]
                    result += String("\(i+1)\r\n\(subtitleBlock.startTime) --> \(subtitleBlock.endTime)\r\n\(subtitleBlock.translatedContent ?? "")\r\n\r\n")
                }
                
                // writeToLocalFile
                print(result)
                let filePath = fileUrl.deletingPathExtension().appendingPathExtension(self.translateService.rawValue).appendingPathExtension(targetLanguage).appendingPathExtension("srt")
                try? result.write(to: filePath, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self.translatedSubtitleFilePath = filePath
                    self.translateState = .done
                }
            }
        }
    }
    
    private func getSubtitleBlocks(from content: String) -> [SubtitleBlock] {
        var text = ""
        if (content.contains("\r\n")) {
            text = content
        } else if (content.contains("\r")) {
            text = content.replacingOccurrences(of: "\r", with: "\r\n")
        } else if (content.contains("\n")) {
            text = content.replacingOccurrences(of: "\n", with: "\r\n")
        }
        let subtitles = text.components(separatedBy: "\r\n\r\n").filter { $0.count > 0 }
        if subtitles.count == 0 {
            return [SubtitleBlock]()
        }
        
        var subtitleBlocks = [SubtitleBlock]()
        
        for subtitle in subtitles {
            if (subtitle.count == 0) {
                continue
            }
            let subtitleComponents = subtitle.components(separatedBy: "\r\n")
            if subtitleComponents.count < 3 {
                print("subtitleBlock format error: \(subtitle)")
                continue
            }
            let times = subtitleComponents[1].components(separatedBy: " --> ")
            // timestamp format error or content format error
            if  times.count != 2 || subtitleComponents[2].count == 0 {
                
                print("timestamp format error or content format error: \(subtitle)")
                continue
            }
            var subContent = ""
            if subtitleComponents.count == 3 {
                subContent = subtitleComponents[2]
            } else {
                subContent = subtitleComponents.suffix(from: 2).joined(separator: "\r\n")
            }
            if (subtitleComponents.count == 0) {
                print("subtitle content is empty: \(subtitle)")
                continue
            }
            let subtitleBlock = SubtitleBlock(startTime: times.first!, endTime: times.last!, orgContent: subContent)
            subtitleBlocks.append(subtitleBlock)
        }
        
        return subtitleBlocks
    }
    
    private func translate(contents: [String], sourceLanguage: String ,to targetLanguage: String ,from url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)  {
        
        let dict: [String: Any] = [
//            "mimeType": "text/plain",
            "contents": contents,
            "sourceLanguageCode": sourceLanguage,
            "targetLanguageCode": targetLanguage,
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            print("http body data invalid")
            return
        }
        print(contents)
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpMethod = "POST"
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request, completionHandler: completionHandler).resume()
    }
}
