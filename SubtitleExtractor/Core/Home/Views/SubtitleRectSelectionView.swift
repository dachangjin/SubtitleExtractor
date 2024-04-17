//
//  VideoSubtitleReactView.swift
//  SubtitleExtractor
//
//  Created by 王伟 on 2023/8/24.
//

import SwiftUI


struct SubtitleRectSelectionView: View {
    
    @Binding var currentRectangle: CGRect
    @State private var dragGestureActive = false
    
    private let lineWidth: CGFloat = 2
    
    var completeBlock: ((_ rect: CGRect) -> ())?
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                if CGRectZero != currentRectangle {
                    context.stroke(Path(currentRectangle), with: .color(Color.red), lineWidth: lineWidth)
                }
            }
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged({ value in

                    let startPoint = value.startLocation
                    var endPointX = value.location.x
                    var endPointY = value.location.y
                    if endPointX < 0 {
                        endPointX = lineWidth
                    }
                    if endPointX > geometry.size.width {
                        endPointX = geometry.size.width - lineWidth
                    }
                    if endPointY < 0 {
                        endPointY = lineWidth
                    }
                    if endPointY > geometry.size.height {
                        endPointY = geometry.size.height - lineWidth
                    }
                    let endPoint = CGPointMake(endPointX, endPointY)
                    currentRectangle = CGRect(x: min(startPoint.x, endPoint.x),
                                              y: min(startPoint.y, endPoint.y),
                                              width: abs(endPoint.x - startPoint.x),
                                              height: abs(endPoint.y - startPoint.y))

                })
                .onEnded({ value in
                    if CGRectZero != currentRectangle , let block = completeBlock {
                        block(currentRectangle)
                    }
                })
            )
        }
        
    }
}

