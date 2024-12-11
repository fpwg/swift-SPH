//
//  SimulationViewModel.swift
//  SPH
//
//  Created by Florian Plaswig on 07.12.24.
//

import Foundation
import simd
import SwiftUICore

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
            return simd_length(uniforms.gravity)
        }
        set {
            if uniforms.gravity == .zero { uniforms.gravity = simd_float2(0, -newValue) }
            uniforms.gravity = simd_normalize(uniforms.gravity) * simd_float1(newValue)
        }
    }
    
    var gravityDirection: Double {
        get {
            if uniforms.gravity == .zero { return -90 }
            return Angle(radians: Double(atan2(uniforms.gravity.y, uniforms.gravity.x))).degrees
        } set {
            let angle: Float = .init(Angle(degrees: Double(newValue)).radians)
            uniforms.gravity = simd_float2(cos(angle), sin(angle)) * gravity
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
    
    var intensityMultiplierLog: Float {
        get {
            return log(Float(rendererUniforms.intensityMultiplier))
        }
        set {
            rendererUniforms.intensityMultiplier = simd_float1(exp(newValue))
        }
    }
    
    var cohesion: Float {
        get {
            return Float(uniforms.cohesion)
        }
        set {
            uniforms.cohesion = simd_float1(newValue)
        }
    }
    
    var dragRadius: Float {
        get {
            return Float(uniforms.drag_radius)
        }
        set {
            uniforms.drag_radius = simd_float1(newValue)
            rendererUniforms.drag_radius = simd_float1(newValue)
        }
    }
}
