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
    int cellHash;
};

struct simulation_uniforms {
    int body_count;
    float wallCollisionDampening;
    float kernelRadius;
    float gravity;
    float stiffness;
    float gamma;
    float xsph_strength;
};

#endif /* definitions_h */
