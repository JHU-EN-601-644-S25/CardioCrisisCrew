import SwiftUI

struct EkgGraphView: View {
    var readings: [Float]
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let xStep = width / CGFloat(max(1, readings.count - 1))
                let yMid = height / 2
                let yScale = height / 2

                // Rounded background card with drop shadow
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                let path = Path(roundedRect: rect, cornerRadius: 24)
                context.fill(path, with: .color(Color(.systemGray6)))
                context.addFilter(.shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4))

                // Grid lines
                let gridSize: CGFloat = 50
                for i in stride(from: 0, to: width, by: gridSize) {
                    let line = Path { path in
                        path.move(to: CGPoint(x: i, y: 0))
                        path.addLine(to: CGPoint(x: i, y: height))
                    }
                    context.stroke(line, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                }
                for i in stride(from: 0, to: height, by: gridSize) {
                    let line = Path { path in
                        path.move(to: CGPoint(x: 0, y: i))
                        path.addLine(to: CGPoint(x: width, y: i))
                    }
                    context.stroke(line, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                }

                // EKG line path
                if !readings.isEmpty {
                    var ekgPath = Path()
                    ekgPath.move(to: CGPoint(x: 0, y: yMid - CGFloat(readings[0]) * yScale))

                    for i in 1..<readings.count {
                        let x = CGFloat(i) * xStep
                        let y = yMid - CGFloat(readings[i]) * yScale
                        ekgPath.addLine(to: CGPoint(x: x, y: y))
                    }

                    context.stroke(ekgPath, with: .color(.red), lineWidth: 2)
                }
            }
        }
        .frame(height: 200)
        .padding()
    }
}
