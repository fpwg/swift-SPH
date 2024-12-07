//
//  SimulationRenderer.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import Foundation
import MetalKit
import simd

struct Vertex {
    var position: simd_float2
    var texCoord: simd_float2
}

let squareVertices: [Vertex] = [
    Vertex(position: .init(-1, -1), texCoord: .init(0, 0)),
    Vertex(position: .init(1, -1), texCoord: .init(1, 0)),
    Vertex(position: .init(1, 1), texCoord: .init(1, 1)),
    Vertex(position: .init(-1, 1), texCoord: .init(0, 1)),
    Vertex(position: .init(-1, -1), texCoord: .init(0, 0)),
]

class SimulationRenderer: NSObject, MTKViewDelegate {
    var device: MTLDevice {
        simulation.metalDevice
    }

    let simulation: Simulation
    var particlesBuffer: MTLBuffer {
        simulation.particlesBuffer
    }

    var densityTexture: MTLTexture {
        simulation.densityTexture
    }

    var vertexBuffer: MTLBuffer!

    var commandQueue: MTLCommandQueue!
    var drawParticlesRenderPipelineState: MTLRenderPipelineState!
    var drawTextureRenderPipelineState: MTLRenderPipelineState!

    var sampler: MTLSamplerState!

    init(simulation: Simulation) {
        self.simulation = simulation

        super.init()

        commandQueue = device.makeCommandQueue()

        let library = device.makeDefaultLibrary()!

        let rpd = MTLRenderPipelineDescriptor()
        rpd.vertexFunction = library.makeFunction(name: "draw_particles_vertex_shader")
        rpd.fragmentFunction = library.makeFunction(name: "draw_particles_fragment_shader")
        rpd.colorAttachments[0].pixelFormat = .bgra8Unorm

        drawParticlesRenderPipelineState = try! device.makeRenderPipelineState(descriptor: rpd)

        rpd.vertexFunction = library.makeFunction(name: "draw_texture_vertex_shader")
        rpd.fragmentFunction = library.makeFunction(name: "draw_texture_fragment_shader")
        rpd.colorAttachments[0].pixelFormat = .bgra8Unorm

        drawTextureRenderPipelineState = try! device.makeRenderPipelineState(descriptor: rpd)

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)

        vertexBuffer = device.makeBuffer(
            bytes: squareVertices, length: MemoryLayout<Vertex>.stride * squareVertices.count, options: [])
    }

    func draw(in view: MTKView) {
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
            let drawable = view.currentDrawable
        else { return }

        simulation.update()

        // Draw density texture
        renderEncoder.setRenderPipelineState(drawTextureRenderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(densityTexture, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: squareVertices.count)

        // Draw particles on top
//        renderEncoder.setRenderPipelineState(drawParticlesRenderPipelineState)
//        renderEncoder.setVertexBuffer(particlesBuffer, offset: 0, index: 0)
//        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: simulation.particleCount)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
