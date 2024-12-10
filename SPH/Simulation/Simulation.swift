//
//  Simulation.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import Foundation
import MetalKit
import simd

struct SimulationUniforms {
    var step_size: simd_float1 = 0.01
    var body_count: simd_uint1 = 500
    var wallCollisionDampening: simd_float1 = 1
    var kernelRadius: simd_float1 = 0.04
    var gravity: simd_float2 = .init(0, -1)
    var stiffness: simd_float1 = 0.1
    var rho0: simd_float1 = 1000
    var cohesion: simd_float1 = 1
    var gamma: simd_float1 = 1.4
    var xsph_strength: simd_float1 = 0 // for now

    var friction: simd_float1 = 1e-2

    var density_texture_size: simd_uint2 = .init(300, 300)

    var drag_center: simd_float2 = .init(0.5, 0.5)
    var is_dragging: simd_bool = false
    var drag_radius: simd_float1 = 0.1
    var drag_strength: simd_float1 = 10

    var verletIsSecondPhase: simd_bool = false
}

class Simulation: ObservableObject {
    typealias Particle = SimulationParticle
    typealias Uniforms = SimulationUniforms

    public var metalDevice: MTLDevice
    public var particlesBuffer: MTLBuffer!
    private var cellStartBuffer: MTLBuffer!

    private var commandQueue: MTLCommandQueue!

    private var updateDensititesPipeline: MTLComputePipelineState!
    private var computeHashesPipeline: MTLComputePipelineState!
    private var updateAccelerationsAndXSPHVelocitiesPipeline: MTLComputePipelineState!
    private var performEulerIntegrationStepPipeline: MTLComputePipelineState!
    private var performVerletPartialStepPipeline: MTLComputePipelineState!

    var densityTexture: MTLTexture!
    var velocityTexture: MTLTexture!
    private var updateDensityTexturePipeline: MTLComputePipelineState!

    private var threadsPerThreadgroup: MTLSize {
        MTLSize(width: 64, height: 1, depth: 1)
    }

    private var threadgroupsPerGrid: MTLSize {
        MTLSize(
            width: (particleCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: 1, depth: 1
        )
    }

    private var _particleCount: Int!
    public var particleCount: Int {
        get {
            return _particleCount
        }
        set {
            guard newValue > 0
            else { return }
            _particleCount = newValue
            uniforms.body_count = simd_uint1(newValue)
            initBuffers()
        }
    }

    public var mouseLocation: simd_float2? {
        set {
            if let newValue = newValue {
                uniforms.drag_center = newValue
                uniforms.is_dragging = true
            } else {
                uniforms.is_dragging = false
            }
        }

        get {
            return uniforms.is_dragging ? uniforms.drag_center : nil
        }
    }

    public var isRunning = false

    @Published
    public var currentDeltaTime: Float = 0

    private var lastUpdatedTime: TimeInterval?
    private let maxTimeStepDuration: TimeInterval = 1 / 60

    var uniforms = Uniforms()
    var rendererUniforms = RendererUniforms()

    init(on device: MTLDevice, particleCount: Int = 5000) {
        self.metalDevice = device
        self._particleCount = particleCount
        uniforms.body_count = simd_uint1(particleCount)

        initBuffers()

        self.commandQueue = device.makeCommandQueue()!

        let library = device.makeDefaultLibrary()!
        self.updateDensititesPipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "update_densities")!
        )
        self.computeHashesPipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "compute_hashes")!
        )
        self.updateAccelerationsAndXSPHVelocitiesPipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "update_accelerations_and_XSPH")!
        )
        self.performEulerIntegrationStepPipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "perform_euler_integration_step")!
        )
        self.performVerletPartialStepPipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "perform_verlet_partial_step")!
        )

        let tex_desc = MTLTextureDescriptor()
        tex_desc.pixelFormat = .r32Float
        tex_desc.width = Int(uniforms.density_texture_size.x)
        tex_desc.height = Int(uniforms.density_texture_size.y)
        tex_desc.usage = [.shaderRead, .shaderWrite]
        self.densityTexture = device.makeTexture(
            descriptor: tex_desc
        )!

        let tex_desc2 = MTLTextureDescriptor()
        tex_desc2.pixelFormat = .rg32Float
        tex_desc2.width = Int(uniforms.density_texture_size.x)
        tex_desc2.height = Int(uniforms.density_texture_size.y)
        tex_desc2.usage = [.shaderRead, .shaderWrite]
        self.velocityTexture = device.makeTexture(
            descriptor: tex_desc2
        )!

        self.updateDensityTexturePipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "update_density_texture")!
        )
    }

    private func initBuffers() {
        particlesBuffer =
            metalDevice.makeBuffer(
                length: MemoryLayout<Simulation.Particle>.stride * particleCount,
                options: []
            )
        generateRandomParticlePositions() // TODO: eventually replace this

        cellStartBuffer =
            metalDevice.makeBuffer(
                length: MemoryLayout<simd_uint1>.stride * particleCount,
                options: []
            )
    }

    private func tickAndGetDeltaTime() -> Float {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let deltaTime = Float(min(lastUpdatedTime.map { currentTime - $0 } ?? 0, maxTimeStepDuration))
        lastUpdatedTime = currentTime
        currentDeltaTime = deltaTime

        return deltaTime
    }

    private func updateDensities(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(updateDensititesPipeline)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(cellStartBuffer, offset: 0, index: 2)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        computeEncoder.setComputePipelineState(updateDensityTexturePipeline)
        computeEncoder.setTexture(densityTexture, index: 0)
        computeEncoder.setTexture(velocityTexture, index: 1)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(cellStartBuffer, offset: 0, index: 2)

        let threadsPerThreadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (Int(uniforms.density_texture_size.x) + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
            height: (Int(uniforms.density_texture_size.y) + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
            depth: 1
        )
        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func updateCellHashes(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(computeHashesPipeline)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func sortHashes() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)

        let particlesArray = Array(UnsafeBufferPointer(start: particles, count: particleCount))
        let sortedParticles = particlesArray.sorted { $0.cellHash < $1.cellHash }

        let cellStarts = cellStartBuffer.contents().bindMemory(to: simd_uint1.self, capacity: particleCount)
        for i in 0..<particleCount {
            cellStarts[i] = .max
        }

        var lastHash: simd_uint1 = .max
        for i in 0..<particleCount {
            if sortedParticles[i].cellHash != lastHash {
                cellStarts[Int(sortedParticles[i].cellHash)] = simd_uint1(simd_int1(i))
                lastHash = sortedParticles[i].cellHash
            }
            particles[i] = sortedParticles[i]
        }
    }

    private func updateAccelerationsAndXSPHVelocities(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(updateAccelerationsAndXSPHVelocitiesPipeline)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(cellStartBuffer, offset: 0, index: 2)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func performEulerIntegrationStep(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(performEulerIntegrationStepPipeline)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    private func performVerletPartialStep(computeEncoder: MTLComputeCommandEncoder, onlyKick: Bool = false) {
        computeEncoder.setComputePipelineState(performVerletPartialStepPipeline)
        uniforms.verletIsSecondPhase = onlyKick
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    public func update() {
        uniforms.step_size = tickAndGetDeltaTime()

        if !isRunning {
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else { assertionFailure(); return }

        updateCellHashes(computeEncoder: computeEncoder)

        // uses the old value of the acceleration
        performVerletPartialStep(computeEncoder: computeEncoder, onlyKick: false)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        sortHashes()

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else { assertionFailure(); return }

        updateDensities(computeEncoder: computeEncoder)
        updateAccelerationsAndXSPHVelocities(computeEncoder: computeEncoder)
        // second partial verlet step using the new acceleration
        performVerletPartialStep(computeEncoder: computeEncoder, onlyKick: true)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func generateRandomParticlePositions() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        for i in 0..<particleCount {
            particles[i].position = simd_float2(
                Float.random(in: 0.01..<0.99),
                Float.random(in: 0.01..<0.99)
            )
            particles[i].velocity = simd_float2(
                0,
                0
            )
        }
    }
}
