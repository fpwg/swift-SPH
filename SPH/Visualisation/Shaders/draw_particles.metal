//
//  draw_particles.metal
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

# include <metal_stdlib>

using namespace metal;

struct particle {
    float2 position;
    float2 velocity;
    float2 xsph_velocity;
    float2 acceleration;

    float density;
    int cellHash;
};

struct vertex_out {
    float4 position [[ position ]];
    float point_size [[ point_size ]];
    float intensity;
};

vertex vertex_out draw_particles_vertex_shader(const device particle *particles [[ buffer(0) ]],
                                               uint id [[ vertex_id ]]) {
    vertex_out out;
    out.position = float4(particles[id].position * 2 - 1, 0.0, 1.0);
    out.point_size = 5;
    out.intensity = particles[id].density; //length(particles[id].velocity);

    return out;
}

fragment float4 draw_particles_fragment_shader(vertex_out in [[ stage_in ]],
                                               float2 point_coord [[ point_coord ]]) {
    float intensity = tanh(in.intensity);
    return float4(intensity, 1-intensity, 1-intensity, 1);
}
