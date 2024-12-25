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
struct RendererUniforms {
    var fluid_color: simd_float3 = .init(5, 117, 237) / 255.0
    var dragged_fluid_color: simd_float3 = .init(87, 162, 242) / 255.0
    var velocity_highlight_color: simd_float3 = .init(189, 69, 237) / 255.0

    var drag_center: simd_float2 = .init(0.5, 0.5)
    var is_dragging: simd_bool = false
    var drag_radius: simd_float1 = 0.1

    var intensityMultiplier: simd_float1 = exp(6.0)
}

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

    var velocityTexture: MTLTexture {
        simulation.velocityTexture
    }

    var potentialTexture: MTLTexture {
        simulation.potentialTexture
    }

    var vertexBuffer: MTLBuffer!

    var commandQueue: MTLCommandQueue!
    var drawParticlesRenderPipelineState: MTLRenderPipelineState!
    var drawTextureRenderPipelineState: MTLRenderPipelineState!

    var uniforms: RendererUniforms {
        get { simulation.rendererUniforms }
        set { simulation.rendererUniforms = newValue }
    }

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

        uniforms.drag_center = simulation.uniforms.drag_center
        uniforms.is_dragging = simulation.uniforms.is_dragging
        uniforms.drag_radius = simulation.uniforms.drag_radius

        // Draw density texture
        renderEncoder.setRenderPipelineState(drawTextureRenderPipelineState)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<RendererUniforms>.stride, index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<RendererUniforms>.stride, index: 0)
        renderEncoder.setFragmentTexture(densityTexture, index: 0)
        renderEncoder.setFragmentTexture(velocityTexture, index: 1)
        renderEncoder.setFragmentTexture(potentialTexture, index: 2)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: squareVertices.count)

        // Draw particles on top
        renderEncoder.setRenderPipelineState(drawParticlesRenderPipelineState)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<RendererUniforms>.stride, index: 0)
        renderEncoder.setVertexBuffer(particlesBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<RendererUniforms>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: simulation.particleCount)

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
