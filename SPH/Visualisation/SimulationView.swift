//
//  SimulationView.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import Cocoa
import MetalKit
import simd
import SwiftUI

struct SimulationView: NSViewRepresentable {
    typealias NSViewType = SimulationMetalView
    let simulation: Simulation

    func makeNSView(context: Context) -> NSViewType {
        return SimulationMetalView(simulation: simulation)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {}
}

class SimulationMetalView: MTKView {
    var renderer: SimulationRenderer!

    let simulation: Simulation

    init(simulation: Simulation) {
        self.simulation = simulation
        super.init(frame: .zero, device: simulation.metalDevice)

        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        renderer = SimulationRenderer(simulation: self.simulation)
        delegate = renderer
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        let normalizedLocation = CGPoint(x: locationInView.x / bounds.width, y: locationInView.y / bounds.height)

        simulation.mouseLocation = simd_float2(Float(normalizedLocation.x), Float(normalizedLocation.y))
    }

    override func mouseDragged(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        let normalizedLocation = CGPoint(x: locationInView.x / bounds.width, y: locationInView.y / bounds.height)

        simulation.mouseLocation = simd_float2(Float(normalizedLocation.x), Float(normalizedLocation.y))
    }

    override func mouseUp(with event: NSEvent) {
        simulation.mouseLocation = nil
    }
}
