//
//  Particle.swift
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

import simd

struct SimulationParticle {
    var position: simd_float2
    var velocity: simd_float2
    var xsph_velocity: simd_float2
    var acceleration: simd_float2

    var density: simd_float1

    var cellHash: simd_int1 = 0
}
