//
//  grid_maintenance.metal
//  SPH
//
//  Created by Florian Plaswig on 24.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"
#include "common/grid.h"

using namespace metal;

kernel void updateGridHashesForParticles(device const simulation_uniforms &u [[ buffer(0 )]],
                                         device particle *particles [[ buffer(1) ]],
                                         uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.particleCount)) { return; }
    
    auto grid = ParticleHashGrid(u.kernelSupportRadius, u.particleCount);
    grid.updateParticleHash(particles[vid]);
}
