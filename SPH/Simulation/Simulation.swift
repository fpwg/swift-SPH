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

    private let CELL_OFFSETS: [(simd_int1, simd_int1)] =
        [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 0), (0, 1), (1, -1), (1, 0), (1, 1)]

    private var _particleCount: Int!
    public var particleCount: Int {
        get {
            return _particleCount
        }
        set {
            _particleCount = newValue
            initBuffers()
        }
    }

    private var lastUpdatedTime: TimeInterval?
    private let maxTimeStepDuration: TimeInterval = 1 / 10

    var uniforms = Uniforms()

    private func kernel(_ r: Float) -> Float {
        let vol = Float.pi / 12
        return max(0, pow(r - 1, 2)) / vol
    }

    private func kernelGrad(_ r: Float) -> Float {
        let vol = Float.pi / 12
        return min(0, 2 * (r - 1) / vol)
    }

    init(on device: MTLDevice, particleCount: Int = 500) {
        self.metalDevice = device
        self._particleCount = particleCount

        initBuffers()
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

    func getGridHash(_ i: simd_int1, _ j: simd_int1) -> simd_int1 {
        return (i * 1291 + j * 10079) % simd_int1(particleCount)
    }

    private func tickAndGetDeltaTime() -> Float {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let deltaTime = Float(min(lastUpdatedTime.map { currentTime - $0 } ?? 0, maxTimeStepDuration))
        lastUpdatedTime = currentTime

        return deltaTime
    }

    private func updateDensities() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        let cellStarts = cellStartBuffer.contents().bindMemory(to: simd_int1.self, capacity: particleCount)

        for i in 0..<particleCount {
            particles[i].density = 0
            let grid_i = simd_int1(particles[i].position.x / uniforms.kernelRadius)
            let grid_j = simd_int1(particles[i].position.y / uniforms.kernelRadius)

            for (oi, oj) in CELL_OFFSETS {
                let hash = getGridHash(grid_i + oi, grid_j + oj)
                let start = Int(cellStarts[Int(hash)])

                guard start >= 0, start < particleCount else { continue } // empty cell

                for j in start..<particleCount {
                    guard particles[j].cellHash == hash else { break }

                    let distance = simd_distance(particles[i].position, particles[j].position)
                    guard distance < uniforms.kernelRadius else { continue }

                    let influence = kernel(distance / uniforms.kernelRadius) / Float(particleCount)
                    particles[i].density += influence
                }
            }
        }
    }

    private func updateXSPHVelocities() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        let cellStarts = cellStartBuffer.contents().bindMemory(to: simd_int1.self, capacity: particleCount)

        for i in 0..<particleCount {
            particles[i].xsph_velocity = .zero

            let grid_i = simd_int1(particles[i].position.x / uniforms.kernelRadius)
            let grid_j = simd_int1(particles[i].position.y / uniforms.kernelRadius)

            for (oi, oj) in CELL_OFFSETS {
                let hash = getGridHash(grid_i + oi, grid_j + oj)
                let start = Int(cellStarts[Int(hash)])

                guard start >= 0, start < particleCount else { continue } // empty cell

                for j in start..<particleCount {
                    guard particles[j].cellHash == hash else { break }
                    guard i != j else { continue }

                    let distance = simd_distance(particles[i].position, particles[j].position)
                    guard distance > 0, distance < uniforms.kernelRadius else { continue }

                    let influence = kernel(distance / uniforms.kernelRadius)
                    particles[i].xsph_velocity += influence * particles[j].velocity / (particles[j].density + particles[i].density) * 2 * uniforms.xsph_strength
                }
            }
        }
    }

    private func updateCellHashes() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        for i in 0..<particleCount {
            particles[i].cellHash = getGridHash(
                simd_int1(particles[i].position.x / uniforms.kernelRadius),
                simd_int1(particles[i].position.y / uniforms.kernelRadius)
            )
        }

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

    private func updateAccelerations() {
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        let cellStarts = cellStartBuffer.contents().bindMemory(to: simd_int1.self, capacity: particleCount)

        for i in 0..<particleCount {
            particles[i].acceleration = .zero
            particles[i].acceleration += uniforms.gravity
        }

        // pressure force
        for i in 0..<particleCount {
            let grid_i = simd_int1(particles[i].position.x / uniforms.kernelRadius)
            let grid_j = simd_int1(particles[i].position.y / uniforms.kernelRadius)

            for (oi, oj) in CELL_OFFSETS {
                let hash = getGridHash(grid_i + oi, grid_j + oj)
                let start = Int(cellStarts[Int(hash)])

                guard start >= 0, start < particleCount else { continue } // empty cell

                for j in start..<particleCount {
                    guard particles[j].cellHash == hash else { break }
                    guard i != j else { continue }

                    let distance = simd_distance(particles[i].position, particles[j].position)
                    guard distance > 0, distance < uniforms.kernelRadius else { continue }

                    let gradient = simd_normalize(particles[i].position - particles[j].position)
                        * kernelGrad(distance / uniforms.kernelRadius)

                    let rho = simd_float2(particles[i].density, particles[j].density)
                    var p: simd_float2 = uniforms.stiffness * pow(rho, simd_float2(repeating: uniforms.gamma))
                    let ff = p / (rho * rho)

                    particles[i].acceleration -= gradient * (ff.x + ff.y)

                    // TODO: debug; remove later
                    if particles[i].acceleration.x.isNaN || particles[i].acceleration.y.isNaN {
                        fatalError("NaN acceleration")
                    }
                }
            }
        }
    }

    public func update() {
        let h = 0.1 * tickAndGetDeltaTime()
        let particles = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)

        updateCellHashes()
        updateDensities()
        updateXSPHVelocities()
        updateAccelerations()

        // naive euler integrator + wall collision check
        for i in 0..<particleCount {
            particles[i].velocity += particles[i].acceleration * h
            particles[i].position += particles[i].velocity * h + particles[i].xsph_velocity * h

            // Collision check
            if particles[i].position.y < 0 {
                particles[i].position.y = 0
                particles[i].velocity.y *= -1 * uniforms.wallCollisionDampening
            } else if particles[i].position.y > 1 {
                particles[i].position.y = 1
                particles[i].velocity.y *= -1 * uniforms.wallCollisionDampening
            }
            if particles[i].position.x < 0 {
                particles[i].position.x = 0
                particles[i].velocity.x *= -1 * uniforms.wallCollisionDampening
            } else if particles[i].position.x > 1 {
                particles[i].position.x = 1
                particles[i].velocity.x *= -1 * uniforms.wallCollisionDampening
            }
        }
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
