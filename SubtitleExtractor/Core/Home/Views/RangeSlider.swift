import SwiftUI

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(height: 4)
                    .foregroundColor(Color.blue)
                
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: 12, height: 24)
                    .foregroundColor(Color.blue)
                    .offset(x: self.offsetForValue(self.lowerValue, in: geometry.size.width) - 6, y: 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = self.valueForOffset(value.location.x, in: geometry.size.width)
                                if newValue < self.range.lowerBound {
                                    self.lowerValue = self.range.lowerBound
                                } else if newValue > self.upperValue {
                                    self.lowerValue = self.upperValue
                                } else {
                                    self.lowerValue = newValue
                                }
                            }
                    )
                
                RoundedRectangle(cornerRadius: 5)
                    .frame(width: 12, height: 24)
                    .foregroundColor(Color.blue)
                    .offset(x: self.offsetForValue(self.upperValue, in: geometry.size.width) - 6, y: 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = self.valueForOffset(value.location.x, in: geometry.size.width)
                                if newValue > self.range.upperBound {
                                    self.upperValue = self.range.upperBound
                                } else if newValue < self.lowerValue {
                                    self.upperValue = self.lowerValue
                                } else {
                                    self.upperValue = newValue
                                }
                            }
                    )
            }
        }
    }
    
    private func offsetForValue(_ value: Double, in width: CGFloat) -> CGFloat {
        let relativeValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return relativeValue * width
    }
    
    private func valueForOffset(_ offset: CGFloat, in width: CGFloat) -> Double {
        let relativeOffset = max(0, min(offset, width)) / width
        return range.lowerBound + Double(relativeOffset) * (range.upperBound - range.lowerBound)
    }
}
