//
//  draw_texture.metal
//  SPH
//
//  Created by Florian Plaswig on 07.12.24.
//

# include <metal_stdlib>
#include "definitions.h"

using namespace metal;

struct vertex_in {
    float2 position;
    float2 tex_coord;
};

struct vertex_out {
    float4 position [[ position ]];
    float2 tex_coord;
};

vertex vertex_out draw_texture_vertex_shader(const device vertex_in *vertices [[ buffer(0) ]],
                                             uint id [[ vertex_id ]]) {
    vertex_in in = vertices[id];
    vertex_out out;
    out.position = float4(in.position, 0.0, 1.0);
    out.tex_coord = in.tex_coord;

    return out;
}

fragment float4 draw_texture_fragment_shader(vertex_out in [[ stage_in ]],
                                             texture2d<float> texture [[ texture(0) ]],
                                             sampler sampler [[ sampler(0) ]]) {
    float intensity = texture.sample(sampler, in.tex_coord).r * 100;
    intensity = tanh(log(intensity + 1));
    
    if (intensity < 0.1) {
        discard_fragment();
    }
    float3 color = float3(0.1, 0.4, 1);
    
    return float4(color * intensity, 1);
}
