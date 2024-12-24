//
//  draw_particles.metal
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

# include <metal_stdlib>
#include "../definitions.h"
#include "render_commons.h"

#define PARTICLE_SIZE 5

using namespace metal;

struct particle_vertex_out {
    float4 position [[ position ]];
    float point_size [[ point_size ]];
    particle particle;
};



vertex particle_vertex_out draw_particles_vertex_shader(const device renderer_uniforms &u [[ buffer(0) ]],
                                                        const device particle *particles [[ buffer(1) ]],
                                                        uint id [[ vertex_id ]]) {
    particle_vertex_out out;
    out.position = float4(particles[id].position * 2 - 1, 0.0, 1.0);
    out.point_size = PARTICLE_SIZE;
    out.particle = particles[id];

    return out;
}

float4 hash_to_color(uint hash) {
    float phi = float(hash);
    return float4(sin(phi), cos(phi), 1, 1);
}

fragment float4 draw_particles_fragment_shader(const device renderer_uniforms &u [[ buffer(0) ]],
                                               particle_vertex_out in [[ stage_in ]],
                                               float2 point_coord [[ point_coord ]]) {
    if (length(point_coord - float2(0.5, 0.5)) > 0.5) {
        discard_fragment();
    }
        
    return float4(in.particle.color, 1);
    
    particle p = in.particle;
    float3 color = compute_fluid_color(u, p.density, p.velocity, p.position);
    
    return float4(color, 1);
}
