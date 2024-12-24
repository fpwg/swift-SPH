//
//  dft.metal
//  SPH
//
//  Created by Florian Plaswig on 12.12.24.
//

#include <metal_stdlib>
#include "../definitions.h"

using namespace metal;

#define HORIZONTAL 0
#define VERTICAL 1

#define M_PI 3.14159265358979323846

// TODO: everything here needs some love

struct DFT_uniforms {
    uint2 size;
    bool inverse;
};

kernel void dft_texture(texture2d<float, access::read> inputTexture [[texture(0)]],
                        texture2d<float, access::write> outputTexture [[texture(1)]],
                        constant DFT_uniforms &u [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    uint2 size = u.size;
    bool inverse = u.inverse;
    
    if (gid.x >= size.x || gid.y >= size.y) return; // Out of bounds check

    // Initialize variables
    int width = size.x;
    int height = size.y;
    float pi = 3.14159265358979323846;
    float2 result = float2(0.0, 0.0);

    // Determine the sign based on forward/inverse transform
    float sign = inverse ? 1.0 : -1.0;

    // Perform the DFT/IDFT
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            // Fetch the input value
            float2 pixel = inputTexture.read(uint2(x, y)).rg;

            // Compute the Fourier coefficients
            float theta = sign * 2.0 * pi * ((gid.x * x / float(width)) + (gid.y * y / float(height)));
            float2 exponent = float2(cos(theta), sin(theta));
            result += pixel * exponent;
        }
    }

    // For the inverse transform, normalize the result
    if (inverse) {
        result /= float2(width * height);
    }

    // Write the result to the output texture
    outputTexture.write(float4(result, 0, 0), gid);
}


kernel void apply_inverse_laplacian(texture2d<float, access::read_write> tex [[texture(0)]],
                                    constant DFT_uniforms &u [[buffer(0)]],
                                    uint2 gid [[thread_position_in_grid]]) {
    uint2 size = u.size;
    
    if (gid.x >= size.x || gid.y >= size.y) return; // Out of bounds check
    float2 k = float2(gid.x, gid.y) / float2(size.x, size.y);
    k += float2(1e-8); // Avoid division by zero
    
    // Compute the inverse Laplacian
    float2 result = tex.read(gid).rg;
    float2 k2 = k * k;
    float k2_sum = k2.x + k2.y;
    float k2_sum_sq = k2_sum * k2_sum;
    
    result *= -1.0 / k2_sum_sq;
    
    tex.write(float4(result, 0, 0), gid);
}
