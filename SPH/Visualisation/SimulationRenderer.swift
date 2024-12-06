//
//  SimulationRenderer.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import Foundation
import MetalKit
import simd

class SimulationRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice

    let simulation: Simulation
    var particlesBuffer: MTLBuffer {
        simulation.particlesBuffer
    }

    var commandQueue: MTLCommandQueue!
    var drawParticlesRenderPipelineState: MTLRenderPipelineState!

    init(device: MTLDevice) {
        self.device = device
        simulation = Simulation(on: device)

        super.init()

        commandQueue = device.makeCommandQueue()

        let library = device.makeDefaultLibrary()!
        let rpd = MTLRenderPipelineDescriptor()
        rpd.vertexFunction = library.makeFunction(name: "draw_particles_vertex_shader")
        rpd.fragmentFunction = library.makeFunction(name: "draw_particles_fragment_shader")
        rpd.colorAttachments[0].pixelFormat = .bgra8Unorm

        drawParticlesRenderPipelineState = try! device.makeRenderPipelineState(descriptor: rpd)
    }

    func draw(in view: MTKView) {
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let drawable = view.currentDrawable
        else { return }

        simulation.update()

        renderEncoder.setRenderPipelineState(drawParticlesRenderPipelineState)
        renderEncoder.setVertexBuffer(particlesBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: simulation.particleCount)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
