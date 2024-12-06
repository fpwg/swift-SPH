//
//  SimulationView.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import Cocoa
import MetalKit
import SwiftUI

struct SimulationView: NSViewRepresentable {
    typealias NSViewType = SimulationMetalView

    func makeNSView(context: Context) -> NSViewType {
        return SimulationMetalView()
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {}
}

class SimulationMetalView: MTKView {
    var renderer: SimulationRenderer!
    

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())

        guard let defaultDevice = device else {
            fatalError("Device loading error")
        }

        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)

        renderer = SimulationRenderer(device: defaultDevice)
        delegate = renderer
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
