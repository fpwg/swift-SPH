//
//  force_calculation.metal
//  SPH
//
//  Created by Florian Plaswig on 24.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"
#include "common/grid.h"
#include "common/kernel.h"

using namespace metal;

float2 computeSelfGravityAccelerationContribution(device const particle* particle,
                                                  device const simulation_uniforms &u,
                                                  texture2d<float, access::read> potential_texture);

float2 computeExternalGravityAccelerationContribution(device const particle &particle,
                                                      device const simulation_uniforms &u);

float2 computeDragForceContribution(device const particle &particle,
                                    device const simulation_uniforms &u);

float2 computePressureForceContribution(device const particle &particle,
                                        device const struct particle &other,
                                        device const simulation_uniforms &u);


kernel void update_accelerations_and_XSPH(device const simulation_uniforms &u [[ buffer(0 )]],
                                          device particle *particles [[ buffer(1) ]],
                                          device const uint *cell_starts [[ buffer(2) ]],
                                          texture2d<float, access::read> potential_texture [[ texture(0) ]],
                                          uint vid [[ thread_position_in_grid ]]) {
    if (vid >= uint(u.particleCount)) { return; }
    
    device particle *particle = particles + vid;
    
    particle->acceleration = float2(0);
    particle->xsph_velocity = float2(0);
    
    // TODO: this is currently not physically accurate - derive a proper implementation
    // particle->acceleration += computeSelfGravityAccelerationContribution(particle, u, potential_texture);
    
    particle->acceleration += computeExternalGravityAccelerationContribution(*particle, u);
    particle->acceleration += computeDragForceContribution(*particle, u);
        

    auto grid = ParticleHashGrid(u.kernelSupportRadius, u.particleCount);
    
    for (auto iterator = grid.getNeighbourhoodIterator(particles, cell_starts, particle->position); iterator.hasNext(); iterator.next()) {
        if (iterator.getCurrentIndex() == vid) { continue; } // skip self-interaction
        
        float dist = length(particle->position - iterator->position);
        // TODO: for now this simply ignores particles that are in the exact same spot, which can in rare cases give clumps
        if (dist > u.kernelSupportRadius || isnan(dist) || dist == 0) { continue; }
        
        particle->acceleration += computePressureForceContribution(*particle, *iterator, u);
        
        // update XSPH velocity
        float influence = sph_kernel(dist / u.kernelSupportRadius);
        particle->xsph_velocity += 2 * influence * iterator->velocity / (iterator->density + particle->density); // TODO: something is broken here, fix it
    }
}

float2 computeExternalGravityAccelerationContribution(device const particle &particle,
                                                      device const simulation_uniforms &u) {
    return u.gravity; // TODO: verify if this needs to be multiplied by density
}

float2 computeDragForceContribution(device const particle &particle,
                                    device const simulation_uniforms &u) {
    if (!u.isDragging || u.dragRadius <= length(particle.position - u.dragCenter)) {
        return float2(0);
    }
    return -u.dragStrength * (particle.position - u.dragCenter) / u.dragRadius;
}

float2 computePressureForceContribution(device const particle &particle,
                                        device const struct particle &other,
                                        device const simulation_uniforms &u) {
    float dist = length(particle.position - other.position);
    float2 gradient = normalize(particle.position - other.position)
        * sph_kernel_grad(dist / u.kernelSupportRadius);
    float2 rho = float2(particle.density, other.density);
    float2 p = u.rho0 * u.stiffness * (pow(rho / u.rho0, u.gamma) - 1e-8 * u.cohesion);
    float2 ff = p / pow(rho, 2);
    
    return - gradient * (ff.x + ff.y);
}

float2 computeSelfGravityAccelerationContribution(device const particle* particle,
                                                  device const simulation_uniforms &u,
                                                  texture2d<float, access::read> potential_texture) {
    uint2 particle_index_in_density_texture = uint2(round(particle->position * float2(u.densityTextureSize)));

    // Note that this sampling is not compatible with what one would usually do in a density
    // grid simulation. The way the force is calculated here allows for self interaction
    // and asymmetric forces - hence this needs to be reworked and is currently just a hacky WIP/placeholder.
    float gradientX = 0.5 * (potential_texture.read(particle_index_in_density_texture+uint2(0,1)).r - potential_texture.read(particle_index_in_density_texture-uint2(1,0)).r) /
    u.densityTextureSize.x;
    float gradientY = 0.5 * (potential_texture.read(particle_index_in_density_texture+uint2(0,1)).r - potential_texture.read(particle_index_in_density_texture-uint2(0,1)).r) / u.densityTextureSize.y;
    float2 gradient = float2(gradientX, gradientY);
    
    return 1e4 * gradient * length(u.gravity) * particle->density;
}
