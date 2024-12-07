//
//  simulation.metal
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

#include <metal_stdlib>
#include "definitions.h"

using namespace metal;

constant int2 hash_params = int2(1291, 10079);
constant int2 cell_offsets[9] = {
    int2(-1, -1), int2(-1, 0), int2(-1, 1),
    int2(0, -1), int2(0, 0), int2(0, 1),
    int2(1, -1), int2(1, 0), int2(1, 1)
};


int getGridHash(int2 idc, int particleCount) {
    return (idc.x * hash_params.x + idc.y * hash_params.y) % particleCount;
}

constant float kernel_vol = 3.14159 / 12;
float sph_kernel(float r) {
    return max(0.0, pow(r - 1, 2)) / kernel_vol;
}


float sph_kernel_grad(float r) {
    return min(0.0, 2 * (r - 1)) / kernel_vol;
}

kernel void compute_hashes(device const simulation_uniforms &u [[ buffer(0 )]],
                           device particle *particles [[ buffer(1) ]],
                           uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.body_count)) { return; }
    
    device particle *particle = particles + vid;
    particle->cellHash = getGridHash(int2(floor(particle->position / u.kernelRadius)),
                                     u.body_count);
}

kernel void perform_euler_integration_step(device const simulation_uniforms &u [[ buffer(0 )]],
                                           device particle *particles [[ buffer(1) ]],
                                           uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.body_count)) { return; }
    
    device particle *particle = particles + vid;
    particle->velocity += particle->acceleration * u.time_step;
    particle->position += particle->velocity * u.time_step + particle->xsph_velocity * u.time_step;
    
    // Collision check
    if (particle->position.y < 0) {
        particle->position.y = 0;
        particle->velocity.y *= -1 * u.wallCollisionDampening;
    } else if (particle->position.y > 1) {
        particle->position.y = 1;
        particle->velocity.y *= -1 * u.wallCollisionDampening;
    } else if (particle->position.x < 0) {
        particle->position.x = 0;
        particle->velocity.x *= -1 * u.wallCollisionDampening;
    } else if (particle->position.x > 1) {
        particle->position.x = 1;
        particle->velocity.x *= -1 * u.wallCollisionDampening;
    }
}

kernel void update_densities(device const simulation_uniforms &u [[ buffer(0 )]],
                             device particle *particles [[ buffer(1) ]],
                             device const int *cell_starts [[ buffer(2) ]],
                             uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.body_count)) { return; }
    
    device particle *particle = particles + vid;
    particle->density = 0;

    int2 grid_index = int2(floor(particle->position / u.kernelRadius));
    
    for (int off_idx = 0; off_idx < 9; ++off_idx) {
        int hash = getGridHash(
            grid_index + cell_offsets[off_idx],
            u.body_count
        );

        int start = cell_starts[hash];
        if (start < 0 || start >= u.body_count) { continue; } // empty cell
        
        for (int j = start; j < u.body_count; ++j) {
            if (particles[j].cellHash != hash) { break; } // end of cell
            
            float dist = length(particle->position - particles[j].position);
            if (dist > u.kernelRadius) { continue; }

            float influence = sph_kernel(dist / u.kernelRadius) / float(u.body_count);
            particle->density += influence;
        }
    }
}


kernel void update_accelerations_and_XSPH(device const simulation_uniforms &u [[ buffer(0 )]],
                                          device particle *particles [[ buffer(1) ]],
                                          device const int *cell_starts [[ buffer(2) ]],
                                          uint vid [[ thread_position_in_grid ]]) {
    
    if (vid >= uint(u.body_count)) { return; }
    
    device particle *particle = particles + vid;
    
    particle->acceleration = float2(0);
    particle->xsph_velocity = float2(0);

    int2 grid_index = int2(floor(particle->position / u.kernelRadius));
    
    for (int off_idx = 0; off_idx < 9; ++off_idx) {
        int hash = getGridHash(
            grid_index + cell_offsets[off_idx],
            u.body_count
        );

        int start = cell_starts[hash];
        if (start < 0 || start >= u.body_count) { continue; } // empty cell
        
        for (int j = start; j < u.body_count; ++j) {
            if (particles[j].cellHash != hash) { break; } // end of cell
            if (uint(j) == vid) { continue; } // skip self-interaction
            
            float dist = length(particle->position - particles[j].position);
            if (dist > u.kernelRadius) { continue; }
            
            // update acceleration
            float2 gradient = normalize(particle->position - particles[j].position)
                * sph_kernel_grad(dist / u.kernelRadius);
            float2 rho = float2(particle->density, particles[j].density);
            float2 p = u.stiffness * pow(rho, u.gamma);
            float2 ff = p / (rho * rho);
            
            particle->acceleration -= gradient * (ff.x + ff.y);
            
            // update XSPH velocity
            float influence = sph_kernel(dist / u.kernelRadius);
            particle->xsph_velocity += influence * particles[j].velocity / (particles[j].density + particle->density) * 2 * u.xsph_strength;
        }
    }
}

