//
//  FileSelector.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/31.
//

import SwiftUI

struct FileSelector: View {
    
    @State var selectedURL: URL?
    var title: String = ""
    var placeHolder: String = ""
    var allowedFileTypes: [String]?
    var selectedBlock: ((_ selectedFileURL: URL) -> ())?
    
    var body: some View {
        HStack {
            Text(selectedURL?.relativePath ?? placeHolder)
                .font(.body)
                .foregroundColor(selectedURL == nil ? .gray : .black)
                .fontWeight(.semibold)
                .frame(height: 30)
            
            Spacer()
            
            Button {
                let openPanel = NSOpenPanel()
                openPanel.allowsMultipleSelection = false
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.allowedFileTypes = allowedFileTypes // Allowed file types
                
                if openPanel.runModal() == NSApplication.ModalResponse.OK {
                    if let selectedFileURL = openPanel.urls.first {
                        selectedURL = selectedFileURL
                        if let block = self.selectedBlock {
                            block(selectedFileURL)
                        }
                    }
                }
            } label: {
                Text(title)
                    .frame(width: 100, height: 50)
                //                        .background(Color(.red))
                //                        .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
    }
}

struct FileSelector_Previews: PreviewProvider {
    static var previews: some View {
        FileSelector()
    }
}
