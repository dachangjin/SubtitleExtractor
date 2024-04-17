//
//  TranslateService.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/31.
//

import Foundation

enum TranslateService: String {
    static var allCases: [TranslateService] = [.deepl, .microsoft, .google, .tencent]
    case google = "google"
    case microsoft = "microsoft"
    case tencent = "tencent"
    case deepl = "deepl"
}

