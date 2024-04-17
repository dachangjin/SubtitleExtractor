//
//  ContentView.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/21.
//

import SwiftUI
import AVKit

struct ContentView: View {
    
    @State var url: URL?

    var body: some View {
        VideoControlView(videoURL: $url)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

