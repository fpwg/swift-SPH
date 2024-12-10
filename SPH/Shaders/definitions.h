//
//  definitions.h
//  SPH
//
//  Created by Florian Plaswig on 06.12.24.
//

#ifndef definitions_h
#define definitions_h

struct particle {
    float2 position;
    float2 velocity;
    float2 xsph_velocity;
    float2 acceleration;

    float density;
    uint cellHash;
};

struct simulation_uniforms {
    float time_step;
    uint body_count;
    float wallCollisionDampening;
    float kernelRadius;
    float2 gravity;
    float stiffness;
    float rho0;
    float cohesion;
    float gamma;
    float xsph_strength;
    float friction;
    
    uint2 densityTextureSize;
    
    float2 dragCenter;
    bool isDragging;
    float dragRadius;
    float dragStrength;
    
    bool verletIsSecondPhase;
};

struct renderer_uniforms {
    float3 fluidColor;
    float3 draggedFluidColor;
    
    float2 dragCenter;
    bool isDragging;
    float dragRadius;
    
    float intensityMultiplier;
};

#endif /* definitions_h */
