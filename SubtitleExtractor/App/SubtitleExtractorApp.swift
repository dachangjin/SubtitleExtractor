//
//  SubtitleExtractorApp.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/21.
//

import SwiftUI

@main
struct SubtitleExtractorApp: App {
    @StateObject var subtitleExtractorViewModel = VideoSubtitleExtractorViewModel()
    @StateObject var translateViewModel = SubtitleTranslateViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subtitleExtractorViewModel)
                .environmentObject(translateViewModel)
                .frame(width: 1300)
                
        }.windowResizabilityContentSize()
    }
}

extension Scene {
    func windowResizabilityContentSize() -> some Scene {
        if #available(macOS 13.0, *) {
            return windowResizability(.contentSize)
        } else {
            return self
        }
    }
}
