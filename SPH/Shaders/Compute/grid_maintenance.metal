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

kernel void compute_hashes(device const simulation_uniforms &u [[ buffer(0 )]],
                           device particle *particles [[ buffer(1) ]],
                           uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.body_count)) { return; }
    
    auto grid = ParticleHashGrid(u.kernelRadius, u.body_count);
    grid.updateParticleHash(particles[vid]);
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
