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

kernel void perform_euler_integration_step(device const simulation_uniforms &u [[ buffer(0 )]],
                                           device particle *particles [[ buffer(1) ]],
                                           uint vid [[ thread_position_in_grid ]]) {
    if (vid >= u.body_count) { return; }
    
    device particle *particle = particles + vid;
    
    
    particle->velocity += particle->acceleration * u.time_step;
    particle->position += particle->velocity * u.time_step;
    particle->position += particle->xsph_velocity * u.time_step * u.xsph_strength;
    
    particle->velocity *= 1-u.friction;
    
    box_collision(particle, u);
}

kernel void perform_leapfrog_partial_step(device const simulation_uniforms &u [[ buffer(0) ]],
                                        device particle *particles [[ buffer(1) ]],
                                        uint vid [[ thread_position_in_grid ]]) {
    if (vid >= u.body_count) { return; }
    

    device particle *particle = particles + vid;
    particle->velocity = particle->velocity + 0.5 * u.time_step * particle->acceleration;
    if (u.leapfrogIsSecondPhase) return;
    
    particle->velocity *= 1-u.friction; // friction only every other partial step
    
    particle->position = particle->position + u.time_step * particle->velocity;
    particle->position += particle->xsph_velocity * u.time_step * u.xsph_strength;
    
    box_collision(particle, u);
}

void box_collision(device particle *particle, simulation_uniforms u) {
    if (particle->position.y < 0) {
        particle->position.y = 0;
        particle->velocity.y *= -1 * u.wallCollisionDampening;
    } else if (particle->position.y > 1) {
        particle->position.y = 1;
        particle->velocity.y *= -1 * u.wallCollisionDampening;
    }
    
    if (particle->position.x < 0) {
        particle->position.x = 0;
        particle->velocity.x *= -1 * u.wallCollisionDampening;
    } else if (particle->position.x > 1) {
        particle->position.x = 1;
        particle->velocity.x *= -1 * u.wallCollisionDampening;
    }
}
