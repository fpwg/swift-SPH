//
//  simulation.metal
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"
#include "grid.h"

using namespace metal;

constant uint2 hash_params = uint2(37, 1297);

uint2 getGridIndex(float2 position, float kernelRadius) {
    return uint2(floor(position / kernelRadius));
}

uint getGridHash(uint2 idc, int particleCount) {
    return (idc.x * hash_params.x + idc.y * hash_params.y) % particleCount;
}

constant float kernel_vol = 3.14159 / 12;
float sph_kernel(float r) {
    return max(0.0, pow(r - 1, 2)) / kernel_vol;
}

float sph_kernel_grad(float r) {
    return min(0.0, 2 * (r - 1)) / kernel_vol;
}

float query_density(float2 position,
                    simulation_uniforms u,
                    device particle *particles,
                    device const uint *cell_starts) {
    auto grid = ParticleHashGrid(u.kernelRadius, u.body_count);
    int2 grid_index = grid.getGridPosition(position);
    
    float density = 0;
    
    for (uint off_idx = 0; off_idx < 9; ++off_idx) {
        uint hash = grid.hash(grid_index + cellOffsets[off_idx]);

        uint start = cell_starts[hash];
        if (start < 0 || start >= u.body_count) { continue; } // empty cell
        
        for (uint j = start; j < u.body_count; ++j) {
            if (particles[j].cellHash != hash) { break; } // end of cell
            
            float dist = length(position - particles[j].position);
            if (dist > u.kernelRadius || isnan(dist)) { continue; }

            float influence = sph_kernel(dist / u.kernelRadius) / float(u.body_count);
            density += influence;
        }
    }
    
    return density;
}

float2 query_velocity(float2 position,
                    simulation_uniforms u,
                    device particle *particles,
                    device const uint *cell_starts) {
    
    uint2 grid_index = getGridIndex(position, u.kernelRadius);
    float2 velocity = 0;
    
    for (uint off_idx = 0; off_idx < 9; ++off_idx) {
        uint hash = getGridHash(
                                uint2(int2(grid_index) + cellOffsets[off_idx]),
            u.body_count
        );

        uint start = cell_starts[hash];
        if (start < 0 || start >= u.body_count) { continue; } // empty cell
        
        for (uint j = start; j < u.body_count; ++j) {
            if (particles[j].cellHash != hash) { break; } // end of cell
            
            float dist = length(position - particles[j].position);
            if (dist > u.kernelRadius || isnan(dist)) { continue; }

            float influence = sph_kernel(dist / u.kernelRadius) / float(u.body_count);
            velocity += particles[j].velocity * influence / particles[j].density;
        }
    }
    
    return velocity;
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

kernel void compute_hashes(device const simulation_uniforms &u [[ buffer(0 )]],
                           device particle *particles [[ buffer(1) ]],
                           uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.body_count)) { return; }
    
    auto grid = ParticleHashGrid(u.kernelRadius, u.body_count);
    grid.updateParticleHash(particles[vid]);
}

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



kernel void update_densities(device const simulation_uniforms &u [[ buffer(0)]],
                             device particle *particles [[ buffer(1) ]],
                             device const uint *cell_starts [[ buffer(2) ]],
                             uint vid [[ thread_position_in_grid ]]) {
    if (vid >= u.body_count) { return; }
    
    device particle *particle = particles + vid;
    particle->density = query_density(particle->position, u, particles, cell_starts);
}

kernel void update_density_texture(device const simulation_uniforms &u [[ buffer(0 )]],
                                   device particle *particles [[ buffer(1) ]],
                                   device const uint *cell_starts [[ buffer(2) ]],
                                   texture2d<float, access::write> density_texture [[ texture(0) ]],
                                   texture2d<float, access::write> velocity_texture [[ texture(1) ]],
                                   uint2 gid [[ thread_position_in_grid ]]) {
    if (gid.x >= u.densityTextureSize.x || gid.y >= u.densityTextureSize.y) { return; }
    
    float2 position = float2(gid) / float2(u.densityTextureSize);
    // TODO: possibly merge these two queries into one
    float density = query_density(position, u, particles, cell_starts);
    float2 velocity = query_velocity(position, u, particles, cell_starts);
    
    density_texture.write(density, gid);
    velocity_texture.write(float4(velocity, 0, 0), gid);
}


kernel void update_accelerations_and_XSPH(device const simulation_uniforms &u [[ buffer(0 )]],
                                          device particle *particles [[ buffer(1) ]],
                                          device const uint *cell_starts [[ buffer(2) ]],
                                          texture2d<float, access::read> potential_texture [[ texture(0) ]],
                                          uint vid [[ thread_position_in_grid ]]) {
    
    if (vid >= uint(u.body_count)) { return; }
    
    device particle *particle = particles + vid;
        
    particle->acceleration = float2(0);
    particle->xsph_velocity = float2(0);
    
    uint2 particle_index_in_density_texture = uint2(round(particle->position * float2(u.densityTextureSize)));
    
    
    float gradientX = 0.5 * (potential_texture.read(particle_index_in_density_texture+uint2(0,1)).r - potential_texture.read(particle_index_in_density_texture-uint2(1,0)).r) /
    u.densityTextureSize.x;
    float gradientY = 0.5 * (potential_texture.read(particle_index_in_density_texture+uint2(0,1)).r - potential_texture.read(particle_index_in_density_texture-uint2(0,1)).r) / u.densityTextureSize.y;
    
    particle->acceleration += 1e4 * float2(gradientX, gradientY) * length(u.gravity) * particle->density;
    
//     particle->acceleration += u.gravity;
//    float r = length(particle->position - float2(0.5));
//    float2 d = normalize(particle->position - float2(0.5));
//    particle->acceleration -= 0.1*d / pow(r+0.1, 2);
    
    
    
    if (u.isDragging && u.dragRadius > length(particle->position - u.dragCenter)) {
        
        
        particle->acceleration -= u.dragStrength * (particle->position - u.dragCenter) / u.dragRadius;
        
        if (u.dragStrength >= 0) {
            particle->acceleration -= u.gravity;
        }
    }

    uint2 grid_index = getGridIndex(particle->position, u.kernelRadius);
    
    for (int off_idx = 0; off_idx < 9; ++off_idx) {
        uint hash = getGridHash(
                                uint2(int2(grid_index) + cellOffsets[off_idx]),
            u.body_count
        );

        uint start = cell_starts[hash];
        if (start < 0 || start >= u.body_count) { continue; } // empty cell
        
        for (uint j = start; j < u.body_count; ++j) {
            if (particles[j].cellHash != hash) { break; } // end of cell
            if (j == vid) { continue; } // skip self-interaction
            
            float dist = length(particle->position - particles[j].position);
            if (dist > u.kernelRadius || isnan(dist) || dist == 0) { continue; }
            
            // update acceleration
            float2 gradient = normalize(particle->position - particles[j].position)
                * sph_kernel_grad(dist / u.kernelRadius);
            float2 rho = float2(particle->density, particles[j].density);
            float2 p = u.rho0 * u.stiffness * (pow(rho / u.rho0, u.gamma) - 1e-8 * u.cohesion);
            float2 ff = p / pow(rho, 2);
            
            particle->acceleration -= gradient * (ff.x + ff.y);
            
            // update XSPH velocity
            float influence = sph_kernel(dist / u.kernelRadius);
            particle->xsph_velocity += 2 * influence * particles[j].velocity / (particles[j].density + particle->density); // TODO: something is broken here, fix it
        }
    }
}


kernel void update_starts_buffer(device const simulation_uniforms &u [[ buffer(0)]],
                                 device const particle *particles [[ buffer(1) ]],
                                 device uint *cell_starts [[ buffer(2) ]],
                                 uint tid [[ thread_position_in_grid ]]) {
    if (tid >= u.body_count) { return; }
    
    // binary search for the start of the cell
    uint hash = tid;
    
    uint start = 0;
    uint end = u.body_count;
    
    while (start < end) {
        uint mid = (start + end) / 2;
        if (particles[mid].cellHash < hash) {
            start = mid + 1;
        } else {
            end = mid;
        }
    }
    
    cell_starts[hash] = start;
}
