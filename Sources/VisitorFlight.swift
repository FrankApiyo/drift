import QuartzCore

/// One visitor crossing the screen on a single extra layer, which removes
/// itself when the flight ends.
final class VisitorFlight: NSObject, CAAnimationDelegate {
    let kind: VisitorKind
    private let layer = CALayer()

    private static let shootingStarSize = CGSize(width: 128, height: 16)
    private static let flightKey = "flight"

    init?(kind: VisitorKind, scale: CGFloat) {
        guard let image = VisitorImages.image(for: kind) else { return nil }
        self.kind = kind
        super.init()
        let side = VisitorPath.lanternSize
        let size = kind == .shootingStar ? Self.shootingStarSize : CGSize(width: side, height: side)
        CATransaction.withoutActions {
            layer.contents = image
            layer.contentsScale = scale
            layer.contentsGravity = .resize
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.zPosition = kind == .shootingStar ? -0.5 : 0.5
            layer.opacity = 0
        }
    }

    func launch(in container: CALayer, area: CGSize) {
        var rng = SystemRandomNumberGenerator()
        let route = VisitorPath.random(for: kind, area: area, using: &rng)
        let path = CGMutablePath()
        path.move(to: route.start)
        path.addQuadCurve(to: route.end, control: route.control)

        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = path
        move.calculationMode = .paced
        if kind == .shootingStar { move.rotationMode = .rotateAuto }

        let isStar = kind == .shootingStar
        let glow = CAKeyframeAnimation(keyPath: "opacity")
        glow.values = isStar ? [0, 0.7, 0.7, 0] : [0, 0.6, 0.6, 0]
        glow.keyTimes = isStar ? [0, 0.25, 0.7, 1] : [0, 0.1, 0.9, 1]
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
