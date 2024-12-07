//
//  SimulationViewModel.swift
//  SPH
//
//  Created by Florian Plaswig on 07.12.24.
//

import Foundation
import simd

extension Simulation {
    var wallCollisionDampening: Float {
        get {
            return Float(uniforms.wallCollisionDampening)
        }
        set {
            uniforms.wallCollisionDampening = simd_float1(newValue)
        }
    }
    
    var kernelRadius: Float {
        get {
            return Float(uniforms.kernelRadius)
        }
        set {
            guard newValue >= 0, newValue < 1 else { return }
            uniforms.kernelRadius = simd_float1(newValue)
        }
    }
    
    var gravity: Float {
        get {
            return -uniforms.gravity.y
        }
        set {
            uniforms.gravity = simd_float2(0, -newValue)
        }
    }
    
    var stiffness: Float {
        get {
            return Float(uniforms.stiffness)
        }
        set {
            uniforms.stiffness = simd_float1(newValue)
        }
    }
      
    var xsph_strength: Float {
        get {
            guard uniforms.xsph_strength >= 0 else { return 0 }
            return Float(uniforms.xsph_strength)
        }
        set {
            uniforms.xsph_strength = simd_float1(newValue)
        }
    }
    
    var friction: Float {
        get {
            return Float(uniforms.friction)
        }
        set {
            guard friction <= 1 else { return }
            uniforms.friction = simd_float1(newValue)
        }
    }
    
    var mousePushesParticles: Bool {
        get {
            return uniforms.drag_strength < 0
        }
        set {
            guard newValue != mousePushesParticles else { return }
            uniforms.drag_strength *= -1
        }
    }
}
