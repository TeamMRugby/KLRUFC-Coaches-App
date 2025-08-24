
import SwiftUI
import AVFoundation
import Vision

struct PoseOverlayView: View {
    let player: AVPlayer

    @State private var timer: Timer? = nil
    @State private var poses: [[CGPoint]] = []
    @State private var frameSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for points in poses {
                    drawSkeleton(points: points, in: context, size: size)
                }
            }
            .onAppear { start() }
            .onDisappear { stop() }
        }
        .allowsHitTesting(false)
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            analyzeCurrentFrame()
        }
    }
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func analyzeCurrentFrame() {
        guard let item = player.currentItem else { return }
        let t = item.currentTime()
        guard let asset = item.asset as? AVAsset else { return }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceAfter = .zero
        gen.requestedTimeToleranceBefore = .zero

        do {
            var actual = CMTime.zero
            let cg = try gen.copyCGImage(at: t, actualTime: &actual)
            let ui = UIImage(cgImage: cg)
            frameSize = ui.size
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            let req = VNDetectHumanBodyPoseRequest()
            try handler.perform([req])
            var newPoses: [[CGPoint]] = []
            if let results = req.results as? [VNHumanBodyPoseObservation] {
                for obs in results {
                    if let points = try? obs.recognizedPoints(.all) {
                        // Select a subset for skeleton
                        let keys: [VNHumanBodyPoseObservation.JointName] = [
                            .nose, .neck,
                            .leftShoulder, .leftElbow, .leftWrist,
                            .rightShoulder, .rightElbow, .rightWrist,
                            .leftHip, .leftKnee, .leftAnkle,
                            .rightHip, .rightKnee, .rightAnkle
                        ]
                        var arr: [CGPoint] = []
                        for k in keys {
                            if let p = points[k], p.confidence > 0.1 {
                                arr.append(CGPoint(x: CGFloat(p.location.x), y: CGFloat(1.0 - p.location.y)))
                            } else {
                                arr.append(.zero)
                            }
                        }
                        newPoses.append(arr)
                    }
                }
            }
            poses = newPoses
        } catch {
            // ignore frame errors (e.g., during seeks)
        }
    }

    func drawSkeleton(points: [CGPoint], in context: GraphicsContext, size: CGSize) {
        func pt(_ idx: Int) -> CGPoint { CGPoint(x: points[idx].x * size.width, y: points[idx].y * size.height) }
        var path = Path()
        // Torso
        path.move(to: pt(1)) // neck
        path.addLine(to: pt(2)) // left shoulder
        path.addLine(to: pt(8)) // left hip
        path.move(to: pt(1))
        path.addLine(to: pt(5)) // right shoulder
        path.addLine(to: pt(11)) // right hip
        // Arms
        path.move(to: pt(2))
        path.addLine(to: pt(3))
        path.addLine(to: pt(4))
        path.move(to: pt(5))
        path.addLine(to: pt(6))
        path.addLine(to: pt(7))
        // Legs
        path.move(to: pt(8))
        path.addLine(to: pt(9))
        path.addLine(to: pt(10))
        path.move(to: pt(11))
        path.addLine(to: pt(12))
        path.addLine(to: pt(13))

        context.stroke(path, with: .color(.green), lineWidth: 2)
    }
}
