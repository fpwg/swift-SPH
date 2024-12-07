//
//  draw_particles.metal
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

# include <metal_stdlib>
#include "definitions.h"

using namespace metal;

struct vertex_out {
    float4 position [[ position ]];
    float point_size [[ point_size ]];
    particle particle;
};

vertex vertex_out draw_particles_vertex_shader(const device particle *particles [[ buffer(0) ]],
                                               uint id [[ vertex_id ]]) {
    vertex_out out;
    out.position = float4(particles[id].position * 2 - 1, 0.0, 1.0);
    out.point_size = 5;
    out.particle = particles[id];

    return out;
}

fragment float4 draw_particles_fragment_shader(vertex_out in [[ stage_in ]],
                                               float2 point_coord [[ point_coord ]]) {
    
    float intensity = tanh(in.particle.density * 10);
    
    float2 dir = normalize(in.particle.velocity.xy)*0.5 + 0.5;
    
    return float4(intensity, dir, 1);
}
