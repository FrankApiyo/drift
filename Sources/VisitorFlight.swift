import QuartzCore

/// One visitor crossing the screen on a single extra layer, which removes
/// itself when the flight ends.
final class VisitorFlight: NSObject, CAAnimationDelegate {
    let kind: VisitorKind
    private let layer = CALayer()

    private static let flightKey = "flight"

    init?(kind: VisitorKind, scale: CGFloat) {
        guard let image = VisitorImages.image(for: kind) else { return nil }
        self.kind = kind
        super.init()
        CATransaction.withoutActions {
            layer.contents = image
            layer.contentsScale = scale
            layer.contentsGravity = .resize
            layer.bounds = CGRect(origin: .zero, size: kind.appearance.size)
            layer.zPosition = Self.zPosition(for: kind)
            layer.opacity = 0
        }
    }

    /// A shooting star crosses the sky behind the mid dots; a lantern rises in front of them.
    private static func zPosition(for kind: VisitorKind) -> CGFloat {
        switch kind {
        case .shootingStar: DepthTier.zPosition(between: .far, and: .mid)
        case .lantern: DepthTier.zPosition(between: .mid, and: .near)
        }
    }

    func launch(in container: CALayer, area: CGSize) {
        let appearance = kind.appearance
        var rng = SystemRandomNumberGenerator()
        let route = VisitorPath.random(for: kind, area: area, using: &rng)
        let path = CGMutablePath()
        path.move(to: route.start)
        path.addQuadCurve(to: route.end, control: route.control)

        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = path
        move.calculationMode = .paced
        if appearance.facesAlongPath { move.rotationMode = .rotateAuto }

        let bright = appearance.brightBetween
        let glow = CAKeyframeAnimation(keyPath: "opacity")
        glow.values = [0, appearance.peakOpacity, appearance.peakOpacity, 0]
        glow.keyTimes = [0, bright.lowerBound, bright.upperBound, 1].map { NSNumber(value: $0) }
        glow.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)

        let flight = CAAnimationGroup()
        flight.animations = [move, glow]
        flight.duration = route.duration
        flight.delegate = self
        flight.preferredFrameRateRange = DotMotion.frameRates

        CATransaction.withoutActions {
            layer.position = route.end
            container.addSublayer(layer)
            layer.add(flight, forKey: Self.flightKey)
        }
    }

    /// Ends the flight early, on pause or teardown.
    func land() {
        CATransaction.withoutActions {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
    }

    func animationDidStop(_ anim: CAAnimation, finished: Bool) {
        CATransaction.withoutActions { layer.removeFromSuperlayer() }
    }
}
