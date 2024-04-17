//
//  String+Extension.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/22.
//

import Foundation

extension String {
    func cosineSimilarity(to other: String) -> Double {
        let words1 = Set(self)
        let words2 = Set(other)
        
        let intersection = words1.intersection(words2).count
        let denominator = sqrt(Double(words1.count) * Double(words2.count))
        print("self:\(self), other:\(other), similarity:\(Double(intersection) / denominator)")
        return Double(intersection) / denominator
    }
}


