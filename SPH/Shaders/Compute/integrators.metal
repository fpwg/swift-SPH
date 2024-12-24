//
//  integrators.metal
//  SPH
//
//  Created by Florian Plaswig on 24.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"
#include "common/kernel.h"

using namespace metal;

void box_collision(device particle *particle, simulation_uniforms u);


kernel void perform_leapfrog_partial_step(device const simulation_uniforms &u [[ buffer(0) ]],
                                        device particle *particles [[ buffer(1) ]],
                                        uint vid [[ thread_position_in_grid ]]) {
    if (vid >= u.particleCount) { return; }
    

    device particle *particle = particles + vid;
    particle->velocity = particle->velocity + 0.5 * u.timeStep * particle->acceleration;
    if (u.leapfrogIsSecondPhase) return;
    
    particle->velocity *= 1-u.friction; // friction only every other partial step
    
    particle->position = particle->position + u.timeStep * particle->velocity;
    particle->position += particle->xsph_velocity * u.timeStep * u.xsph_strength;
    
    box_collision(particle, u);
}

void box_collision(device particle *particle, simulation_uniforms u) {
    if (particle->position.y < 0) {
        particle->position.y = 0;
        particle->velocity.y *= -1 * u.wallCollisionDampeningFactor;
    } else if (particle->position.y > 1) {
        particle->position.y = 1;
        particle->velocity.y *= -1 * u.wallCollisionDampeningFactor;
    }
    
    if (particle->position.x < 0) {
        particle->position.x = 0;
        particle->velocity.x *= -1 * u.wallCollisionDampeningFactor;
    } else if (particle->position.x > 1) {
        particle->position.x = 1;
        particle->velocity.x *= -1 * u.wallCollisionDampeningFactor;
    }
}


// --- DEPRECATED ---
kernel void perform_euler_integration_step(device const simulation_uniforms &u [[ buffer(0 )]],
                                           device particle *particles [[ buffer(1) ]],
                                           uint vid [[ thread_position_in_grid ]]) {
    if (vid >= u.particleCount) { return; }
    
    device particle *particle = particles + vid;
    
    particle->velocity += particle->acceleration * u.timeStep;
    particle->position += particle->velocity * u.timeStep;
    particle->position += particle->xsph_velocity * u.timeStep * u.xsph_strength;
    
    particle->velocity *= 1-u.friction;
    
    box_collision(particle, u);
}
