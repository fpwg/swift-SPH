//
//  density_calculation.metal
//  SPH
//
//  Created by Florian Plaswig on 24.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"
#include "common/grid.h"
#include "common/kernel.h"

using namespace metal;

float query_density(float2 position,
                    simulation_uniforms u,
                    device particle *particles,
                    device const uint *cell_starts) {
    auto grid = ParticleHashGrid(u.kernelRadius, u.body_count);
    float density = 0;
    
    for (auto iterator = grid.getNeighbourhoodIterator(particles, cell_starts, position); iterator.hasNext(); iterator.next()) {
        float dist = length(position - iterator->position);
        if (dist > u.kernelRadius || isnan(dist)) { continue; }

        float influence = sph_kernel(dist / u.kernelRadius) / float(u.body_count);
        density += influence;
    }
    
    return density;
}

float2 query_velocity(float2 position,
                    simulation_uniforms u,
                    device particle *particles,
                    device const uint *cell_starts) {
    auto grid = ParticleHashGrid(u.kernelRadius, u.body_count);
    float2 velocity = 0;
    
    for (auto iterator = grid.getNeighbourhoodIterator(particles, cell_starts, position); iterator.hasNext(); iterator.next()) {
        float dist = length(position - iterator->position);
        if (dist > u.kernelRadius || isnan(dist)) { continue; }

        float influence = sph_kernel(dist / u.kernelRadius) / float(u.body_count);
        velocity += iterator->velocity * influence / iterator->density;
    }
    
    return velocity;
}

kernel void update_densities(device const simulation_uniforms &u [[ buffer(0)]],
                             device particle *particles [[ buffer(1) ]],
                             device const uint *cell_starts [[ buffer(2) ]],
                             uint vid [[ thread_position_in_grid ]]) {
    if (vid >= u.body_count) { return; }
    particles[vid].density = query_density(particles[vid].position, u, particles, cell_starts);
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
