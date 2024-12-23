//
//  force_calculation.metal
//  SPH
//
//  Created by Florian Plaswig on 24.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"
#include "common/grid.h"
#include "common/kernel.h"

using namespace metal;

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

    auto grid = ParticleHashGrid(u.kernelRadius, u.body_count);
    
    for (auto iterator = grid.getNeighbourhoodIterator(particles, cell_starts, particle->position); iterator.hasNext(); iterator.next()) {
        if (iterator.getCurrentIndex() == vid) { continue; } // skip self-interaction
        
        float dist = length(particle->position - iterator->position);
        if (dist > u.kernelRadius || isnan(dist) || dist == 0) { continue; }
        
        // update acceleration
        float2 gradient = normalize(particle->position - iterator->position)
            * sph_kernel_grad(dist / u.kernelRadius);
        float2 rho = float2(particle->density, iterator->density);
        float2 p = u.rho0 * u.stiffness * (pow(rho / u.rho0, u.gamma) - 1e-8 * u.cohesion);
        float2 ff = p / pow(rho, 2);
        
        particle->acceleration -= gradient * (ff.x + ff.y);
        
        // update XSPH velocity
        float influence = sph_kernel(dist / u.kernelRadius);
        particle->xsph_velocity += 2 * influence * iterator->velocity / (iterator->density + particle->density); // TODO: something is broken here, fix it
    }
}
