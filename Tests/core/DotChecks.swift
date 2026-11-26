import QuartzCore

/// A layer outside any window keeps its animations only until the outermost
/// transaction commits, so each scenario runs inside one.
private func scenario(_ body: () -> Void) {
    CATransaction.begin()
    body()
    CATransaction.commit()
}

private func moodOf(_ shape: DotShape, motion: MotionStyle = .drift) -> Mood {
    Mood(palette: .meadow, shapes: [shape], pace: 1, motion: motion)
}

private func makeDot(_ shape: DotShape, motion: MotionStyle = .drift, reduceMotion: Bool = false) -> Dot {
    Dot(setup: setup(), scale: 2, speedFactor: 1, mood: moodOf(shape, motion: motion),
        reduceMotion: reduceMotion, oddOneOutChance: 0)
}

private func wrap(_ dot: Dot) {
    guard let drift = dot.layer.animation(forKey: DotMotion.driftKey) else {
        return check(false, "fixture: the dot is drifting")
    }
    dot.animationDidStop(drift, finished: true)
}

private func now(_ layer: CALayer) -> CFTimeInterval {
    layer.convertTime(CACurrentMediaTime(), from: nil)
}

private func modelAngle(_ layer: CALayer) -> Double {
    (layer.value(forKeyPath: DotMotion.rotationKey) as? NSNumber)?.doubleValue ?? .nan
}

private func settle(on layer: CALayer) -> CABasicAnimation? {
    layer.animation(forKey: DotMotion.settleKey) as? CABasicAnimation
}

private func fromAngle(_ animation: CABasicAnimation?) -> Double {
    (animation?.fromValue as? NSNumber)?.doubleValue ?? .nan
}

/// No window means no presentation layer, so the model rotation stands in
/// for the angle on screen.
private func show(_ dot: Dot, at angle: Double) {
    CATransaction.withoutActions { dot.layer.setValue(angle, forKeyPath: DotMotion.rotationKey) }
}

private func isAdditive(_ animation: CAAnimation?) -> Bool {
    (animation as? CAPropertyAnimation)?.isAdditive == true
}

/// Settles upright from `angle` straight away. A key re-added within one
/// transaction keeps its old place in the layer's order, so the settle and
/// any turn must both be additive to combine whichever comes first.
private func checkSettles(_ dot: Dot, from angle: Double, _ what: String, line: Int = #line) {
    let settling = settle(on: dot.layer)
    check(settling.map { $0.beginTime <= now(dot.layer) + 0.1 } ?? false, "\(what) eases upright at once", line: line)
    check(near(fromAngle(settling), remainder(angle, 2 * .pi), within: 1e-6), "\(what) settles from \(angle)", line: line)
    check(modelAngle(dot.layer) == 0, "\(what) has an upright model rotation", line: line)
    check(isAdditive(settling), "\(what) settles on top of its upright model", line: line)
    if let turn = dot.layer.animation(forKey: DotMotion.turnKey) {
        check(isAdditive(turn), "\(what) turns on top of the settle", line: line)
    }
}

private func checkWraps() {
    scenario {
        let dot = makeDot(.circle, motion: .fireflies)
        dot.start()
        check(dot.layer.animation(forKey: DotMotion.glowKey) != nil, "fixture: a firefly glows")
        dot.adopt(moodOf(.circle), desktop: screen, after: 0, fadingOver: 1)
        wrap(dot)
        check(dot.layer.animation(forKey: DotMotion.driftKey) != nil, "fixture: the wrapped dot drifts again")
        check(dot.layer.animation(forKey: DotMotion.glowKey) == nil, "a firefly that wraps to a plain pass stops glowing")
    }
    scenario {
        let dot = makeDot(.star)
        dot.start()
        check(dot.layer.animation(forKey: DotMotion.turnKey) != nil, "fixture: a star spins")
        dot.adopt(moodOf(.circle), desktop: screen, after: 0, fadingOver: 1)
        wrap(dot)
        check(dot.layer.animation(forKey: DotMotion.turnKey) == nil
              && settle(on: dot.layer) == nil, "a star that wraps to a circle stops turning")
    }
}

private func checkTurnChanges() {
    scenario {
        let dot = makeDot(.star)
        dot.start()
        show(dot, at: 2.9)
        let begin = now(dot.layer) + 10
        dot.adopt(moodOf(.heart), desktop: screen, after: 10, fadingOver: 5)
        checkSettles(dot, from: 2.9, "a spin that becomes a rock")
        let rock = dot.layer.animation(forKey: DotMotion.turnKey)
        check(rock.map { near($0.beginTime, begin, within: 0.1) } ?? false, "the rock starts as the heart arrives")
    }
    scenario {
        let dot = makeDot(.heart)
        dot.start()
        show(dot, at: 0.3)
        dot.adopt(moodOf(.star), desktop: screen, after: 2, fadingOver: 5)
        checkSettles(dot, from: 0.3, "a rock that becomes a spin")
        check(dot.layer.animation(forKey: DotMotion.turnKey) != nil, "a rock that becomes a star spins")
    }
    scenario {
        let dot = makeDot(.star)
        dot.start()
        show(dot, at: 2.9)
        dot.adopt(moodOf(.circle), desktop: screen, after: 10, fadingOver: 5)
        checkSettles(dot, from: 2.9, "a spin that stops")
        check(dot.layer.animation(forKey: DotMotion.turnKey) == nil, "a star that becomes a circle stops turning")
    }
}

private func checkResumes() {
    scenario {
        let dot = makeDot(.star)
        dot.start()
        show(dot, at: 2.9)
        dot.stop()
        dot.adopt(moodOf(.heart), desktop: screen, after: 0, fadingOver: 1)
        dot.start()
        checkSettles(dot, from: 2.9, "a stopped star that becomes a heart")
    }
    scenario {
        let dot = makeDot(.heart)
        dot.start()
        show(dot, at: 0.3)
        dot.stop()
        dot.start()
        checkSettles(dot, from: 0.3, "a heart resumed mid-rock")
        dot.stop()
        dot.start()
        check(modelAngle(dot.layer) == 0, "repeated pauses don't add up a rocking offset")
    }
    scenario {
        let dot = makeDot(.heart)
        dot.start()
        show(dot, at: 2.9)
        dot.setReduceMotion(true)
        checkSettles(dot, from: 2.9, "a tilted heart under Reduce Motion")
        check(dot.layer.animation(forKey: DotMotion.turnKey) == nil, "Reduce Motion stops the rock")
    }
    scenario {
        let dot = makeDot(.star)
        dot.start()
        show(dot, at: 2.9)
        dot.stop()
        dot.start()
        check(settle(on: dot.layer) == nil && modelAngle(dot.layer) == 2.9, "a resumed star spins on from its angle")
    }
}

private func checkBuilders() {
    check(near(fromAngle(DotMotion.settle(from: 5, beginTime: 0)), 5 - 2 * .pi, within: 1e-9),
          "a settle takes the short way round to upright")
    let shown = CGSize(width: 13, height: 13)
    let swell = DotMotion.swell(from: shown, to: CGSize(width: 10, height: 10), beginTime: 0, duration: 1)
    check((swell.values?.first as? NSValue)?.sizeValue == shown, "a swell starts from the size on screen")
}

func checkDotMotion() {
    checkWraps()
    checkTurnChanges()
    checkResumes()
    checkBuilders()
}
