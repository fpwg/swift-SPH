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
    var step_size: Float = 0.01
    var body_count: simd_int1 = 500
    let wallCollisionDampening: Float = 0.9
    let kernelRadius: Float = 0.1
    let gravity: simd_float2 = .init(0, -1)
    let stiffness: Float = 0.1

    let gamma: Float = 2

    let xsph_strength: Float = 0.01
}

class Simulation {
    typealias Particle = SimulationParticle
    typealias Uniforms = SimulationUniforms

    private var metalDevice: MTLDevice
    public var particlesBuffer: MTLBuffer!
    private var cellStartBuffer: MTLBuffer!

    private var commandQueue: MTLCommandQueue!

    private var updateDensititesPipeline: MTLComputePipelineState!
    private var computeHashesPipeline: MTLComputePipelineState!
    private var updateAccelerationsAndXSPHVelocitiesPipeline: MTLComputePipelineState!
    private var performEulerIntegrationStepPipeline: MTLComputePipelineState!

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
            _particleCount = newValue
            uniforms.body_count = simd_int1(newValue)
            initBuffers()
        }
    }

    private var lastUpdatedTime: TimeInterval?
    private let maxTimeStepDuration: TimeInterval = 1 / 10

    var uniforms = Uniforms()

    init(on device: MTLDevice, particleCount: Int = 5000) {
        self.metalDevice = device
        self._particleCount = particleCount
        uniforms.body_count = simd_int1(particleCount)

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
                length: MemoryLayout<simd_int1>.stride * particleCount,
                options: []
            )
    }

    private func tickAndGetDeltaTime() -> Float {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let deltaTime = Float(min(lastUpdatedTime.map { currentTime - $0 } ?? 0, maxTimeStepDuration))
        lastUpdatedTime = currentTime

        return deltaTime
    }

    private func updateDensities(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(updateDensititesPipeline)
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        computeEncoder.setBuffer(particlesBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(cellStartBuffer, offset: 0, index: 2)

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

        let cellStarts = cellStartBuffer.contents().bindMemory(to: simd_int1.self, capacity: particleCount)
        for i in 0..<particleCount {
            cellStarts[i] = .max
        }

        var lastHash: simd_int1 = -1
        for i in 0..<particleCount {
            if sortedParticles[i].cellHash != lastHash {
                cellStarts[Int(sortedParticles[i].cellHash)] = simd_int1(i)
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

    public func update() {
        uniforms.step_size = 0.001 * tickAndGetDeltaTime()

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else { assertionFailure(); return }

        updateCellHashes(computeEncoder: computeEncoder)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        sortHashes()

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        else { assertionFailure(); return }

        updateDensities(computeEncoder: computeEncoder)
        updateAccelerationsAndXSPHVelocities(computeEncoder: computeEncoder)
        performEulerIntegrationStep(computeEncoder: computeEncoder)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func generateRandomParticlePositions() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        for i in 0..<particleCount {
            particles[i].position = simd_float2(
                Float.random(in: 0.5..<1),
                Float.random(in: 0..<1)
            )
            particles[i].velocity = simd_float2(
                0,
                0
            )
        }
    }
}
