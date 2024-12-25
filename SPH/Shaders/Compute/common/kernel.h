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

constant float KERNEL_NORMALISATION_2D = 6 / 3.14159265359;


inline float sph_kernel(float r) {
    if (r >= 1 || r < 0) return 0;
    return KERNEL_NORMALISATION_2D * pow(r - 1, 2);
}

inline float sph_kernel_grad(float r) {
    if (r >= 1 || r < 0) return 0;
    return KERNEL_NORMALISATION_2D * 2 * (r - 1);
}

#endif /* kernel_h */
