//
//  draw_texture.metal
//  SPH
//
//  Created by Florian Plaswig on 07.12.24.
//

# include <metal_stdlib>
#include "definitions.h"
#include "render_commons.h"

using namespace metal;

struct vertex_in {
    float2 position;
    float2 tex_coord;
};

struct vertex_out {
    float4 position [[ position ]];
    float2 tex_coord;
};

vertex vertex_out draw_texture_vertex_shader(const device renderer_uniforms &u [[ buffer(0) ]],
                                             const device vertex_in *vertices [[ buffer(1) ]],
                                             uint id [[ vertex_id ]]) {
    vertex_in in = vertices[id];
    vertex_out out;
    out.position = float4(in.position, 0.0, 1.0);
    out.tex_coord = in.tex_coord;

    return out;
}

fragment float4 draw_texture_fragment_shader(const device renderer_uniforms &u [[ buffer(0) ]],
                                             vertex_out in [[ stage_in ]],
                                             texture2d<float> density_tex [[ texture(0) ]],
                                             texture2d<float> velocity_tex [[ texture(1) ]],
                                             texture2d<float> potential_tex [[ texture(2) ]],
                                             sampler sampler [[ sampler(0) ]]) {    
    float density = density_tex.sample(sampler, in.tex_coord).r;
    float2 velocity = velocity_tex.sample(sampler, in.tex_coord).rg;

    float3 color = compute_fluid_color(u, density, velocity, in.tex_coord);
    
    return float4(color, 1);
}
