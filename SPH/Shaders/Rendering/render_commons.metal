//
//  render_commons.metal
//  SPH
//
//  Created by Florian Plaswig on 10.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"

using namespace metal;

float3 compute_fluid_color(renderer_uniforms u, float density, float2 velocity, float2 position) {
    float intensity = density * u.intensityMultiplier;
    intensity = tanh(log(intensity))*0.5 + 0.5;
    
    float speed = length(velocity);
    
    float3 color = u.fluidColor;
    
    if (u.isDragging) {
        float center_dist_sq = length_squared(position - u.dragCenter);
        
        float lightUp = exp(- center_dist_sq / pow(0.5 * u.dragRadius, 2));
        intensity += lightUp * 0.1;
        
        color = mix(color, u.draggedFluidColor, lightUp);
    }
    
    color = mix(color, float3(0,1,0), tanh(2*speed - 1)*0.5+0.5);
    
    intensity = clamp(intensity, 0.0, 1.0);
    intensity = smoothstep(0.05, 0.4, intensity);

    return color * intensity;
}
