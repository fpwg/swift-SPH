//
//  render_commons.metal
//  SPH
//
//  Created by Florian Plaswig on 10.12.24.
//

#ifndef render_commons_metal
#define render_commons_metal

float3 compute_fluid_color(renderer_uniforms u, float density, float2 velocity, float2 position);

#endif
