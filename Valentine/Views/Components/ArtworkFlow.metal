#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Smooth value noise, evaluated entirely on the GPU without a noise asset.
static float artworkHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static float artworkNoise(float2 p) {
    float2 cell = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(artworkHash(cell), artworkHash(cell + float2(1, 0)), u.x),
               mix(artworkHash(cell + float2(0, 1)), artworkHash(cell + float2(1, 1)), u.x), u.y);
}

[[ stitchable ]] half4 artworkFlow(float2 position, SwiftUI::Layer layer, float time, float pulse) {
    float2 uv = position / 320.0;
    float2 drift = float2(time * 0.075, -time * 0.055);
    float2 first = float2(artworkNoise(uv * 2.2 + drift),
                          artworkNoise(uv * 2.2 + drift + 7.3));
    float2 second = float2(artworkNoise(uv * 2.0 + first * 1.4 + drift),
                           artworkNoise(uv * 2.0 + first * 1.4 - drift + 11.7));
    // Inset sampling prevents transparent edges as the artwork flows.
    float2 orbit = float2(sin(time * 0.18), cos(time * 0.14)) * 0.07;
    float energy = clamp(pulse, 0.0, 1.0);
    float2 breathingUV = (uv - 0.5) * (1.0 - energy * 0.10) + 0.5;
    float2 sampleUV = clamp(breathingUV * 0.56 + 0.22 + (second - 0.5) * (0.48 + energy * 0.12) + orbit,
                            float2(0.04), float2(0.96));
    return layer.sample(sampleUV * 320.0);
}
