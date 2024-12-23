//
//  kernel.h
//  SPH
//
//  Created by Florian Plaswig on 24.12.24.
//

#ifndef kernel_h
#define kernel_h

#include <metal_stdlib>
using namespace metal;

constant float kernel_vol = 3.14159 / 12;

inline float sph_kernel(float r) {
    return max(0.0, pow(r - 1, 2)) / kernel_vol;
}

inline float sph_kernel_grad(float r) {
    return min(0.0, 2 * (r - 1)) / kernel_vol;
}

#endif /* kernel_h */
