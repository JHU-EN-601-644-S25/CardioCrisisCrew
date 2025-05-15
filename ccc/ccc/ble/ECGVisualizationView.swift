import SwiftUI

struct ECGVisualizationView: View {
    @Binding var data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw axes
                VStack(spacing: 0) {
                    // Y-axis labels
                    HStack(alignment: .top, spacing: 0) {
                        // Y-axis labels
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("5.0V")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("2.5V")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("0.0V")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 35)
                        
                        // Main graph area
                        ZStack {
                            // Grid lines
                            VStack(spacing: 0) {
                                ForEach(0..<3) { i in
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                    if i < 2 { Spacer() }
                                }
                            }
                            
                            // ECG line
                            Path { path in
                                let width = geometry.size.width - 35 // Account for y-axis labels
                                let height = geometry.size.height - 20 // Account for x-axis labels
                                let step = width / CGFloat(data.count - 1)
                                
                                for i in data.indices {
                                    let x = step * CGFloat(i)
                                    // Scale the voltage to fit the 0-5V range
                                    let y = height - (CGFloat(data[i]) / 5.0) * height
                                    
                                    if i == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(Color.red, lineWidth: 2)
                        }
                    }
                    
                    // X-axis labels
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 35) // Match y-axis label width
                        HStack {
                            ForEach(0..<(data.count/5 + 1)) { i in
                                Text("\(i * 5)s")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                if i < data.count/5 { Spacer() }
                            }
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
    }
} 