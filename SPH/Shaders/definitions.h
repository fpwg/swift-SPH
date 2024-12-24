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
    uint hashOfContainingCell;
    
    float3 color;
};

struct simulation_uniforms {
    float timeStep;
    uint particleCount;
    float wallCollisionDampeningFactor;
    float kernelSupportRadius;
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
    
    bool leapfrogIsSecondPhase;
};

struct renderer_uniforms {
    float3 fluidColor;
    float3 draggedFluidColor;
    float3 velocityHighlightColor;
    
    float2 dragCenter;
    bool isDragging;
    float dragRadius;
    
    float intensityMultiplier;
};

#endif /* definitions_h */
