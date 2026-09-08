#include <metal_stdlib>
using namespace metal;

// Metal implementation of the NCS-style particle-sheet/sphere model.
// Continuous vector noise keeps the membrane coherent as audio changes its depth.
struct RingUniforms {
    float4 motion; // evolution, bass, vocal-band envelope, high-frequency energy
    float4 color;
    float4 viewport; // width, height, grid resolution, transient
    float4 energy; // overall intensity, reserved
};


struct RingParticle {
    float4 position [[position]];
    float size [[point_size]];
    float opacity;
};

uint ringHash(uint4 cell) {
    uint h = cell.x * 1597334677u ^ cell.y * 3812015801u;
    h ^= cell.z * 2798796415u ^ cell.w * 1979697957u;
    h = (h ^ (h >> 16)) * 2246822519u;
    return (h ^ (h >> 13)) * 3266489917u;
}

float3 ringLattice(int4 cell) {
    uint h = ringHash(uint4(cell));
    uint3 v = uint3(h, h * 1664525u + 1013904223u, h * 22695477u + 1u);
    return float3(v & 65535u) / 32767.5 - 1.0;
}

float3 ringNoise(float4 p) {
    int4 cell = int4(floor(p));
    float4 f = fract(p), w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float3 result = 0;
    for (uint corner = 0; corner < 16; ++corner) {
        int4 offset = int4(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1, (corner >> 3) & 1);
        float4 weight = mix(1.0 - w, w, float4(offset));
        result += ringLattice(cell + offset) * weight.x * weight.y * weight.z * weight.w;
    }
    return result;
}

// Evaluate the continuous field once on a fine lattice, not once per particle.
// Linear sampling retains the folds while eliminating most repeated noise work.
kernel void audioRingField(texture2d<half, access::write> field [[texture(0)]],
                           constant RingUniforms &u [[buffer(0)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= field.get_width() || id.y >= field.get_height()) return;
    float2 uv = float2(id) / float2(field.get_width() - 1, field.get_height() - 1);
    float t = u.motion.x;
    float2 sheet = (uv - 0.5) * 2.4;
    // A broad field creates continuous sheets that can traverse the interior.
    // Positive Y advection moves their creases down through the projected sphere.
    float4 domain = float4(sheet * 1.65 + float2(0, t * 0.18), 0.47, t * 0.21);
    float3 broad = ringNoise(domain);
    float3 fine = ringNoise(domain * 2.07 + float4(13.7, 5.1, 8.3, 0));
    field.write(half4(float4(broad + fine * (0.10 + 0.08 * u.motion.z), 1)), id);
}

vertex RingParticle audioRingParticle(uint id [[vertex_id]], constant RingUniforms &u [[buffer(0)]],
                                      texture2d<half> field [[texture(0)]]) {
    uint grid = uint(u.viewport.z);
    float2 uv = (float2(id % grid, id / grid) + 0.5) / float(grid);
    float2 sheet = (uv - 0.5) * 2.4;
    constexpr sampler lattice(filter::linear, address::clamp_to_edge);
    float2 fieldSize = float2(field.get_width(), field.get_height());
    float2 fieldUV = (uv * (fieldSize - 1.0) + 0.5) / fieldSize;
    float3 noise = float3(field.sample(lattice, fieldUV, level(0)).xyz);
    float t = u.motion.x;
    // Displace the sheet in XYZ *before* spherical projection, as in GLava.
    // Substantial depth is essential: a nearly planar sheet only draws a pulsing
    // circumference. Front/back folds overlap when projected onto the screen.
    // Vocal-band envelope alone shapes folds; percussion must not jerk the sheet.
    // Preserve quiet passages; emphasize louder syllables with a bounded curve.
    // No percussion/onset term: the independent radius response stays unchanged.
    float vocal = clamp(u.motion.z, 0.0, 0.82);
    float drive = 0.085 + vocal * 0.70 + vocal * vocal * 0.25;
    float3 p = float3(sheet, 0) + noise * float3(drive, drive * 0.93, drive * 1.65);
    // Restore visible breathing: bass/onsets carry rhythm, full-band energy size.
    float radius = 0.66 + u.motion.y * 0.12 + u.energy.x * 0.07 + u.viewport.w * 0.055;
    float distance = max(length(p), 0.0001);
    float shell = smoothstep(0.0, radius * 0.48, radius - distance);
    p *= min(mix(distance, radius, shell), radius) / distance;
    float tilt = 0.12 * sin(t * 0.24);
    p = float3(p.x * cos(tilt) + p.z * sin(tilt), p.y, p.z * cos(tilt) - p.x * sin(tilt));
    float angle = t * 0.035;
    p.xy = float2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
    // Fade the *source* sheet, not displaced XYZ distance. Culling by distance
    // erased precisely the deep folds that should cross the sphere's interior.
    // Spherical projection above keeps the silhouette within the artwork slot.
    float mask = 1.0 - smoothstep(1.05, 1.20, length(sheet));
    float side = min(u.viewport.x, u.viewport.y);
    float pointSize = clamp(side / 520.0, 1.0, 2.2);
    RingParticle out;
    out.position = float4(p.xy * side / u.viewport.xy, 0, 1);
    out.size = pointSize * 2.4;
    // Density compensation keeps exposure stable across retina sizes and grid LODs.
    out.opacity = mask * (0.10 + 0.045 * u.motion.z)
        * pow(side / (float(grid) * pointSize), 2.0);
    return out;
}

fragment half4 audioRingDensity(RingParticle in [[stage_in]], float2 uv [[point_coord]]) {
    float d = length(uv - 0.5) * 2.0;
    float intensity = exp(-5.0 * d * d) * (1.0 - smoothstep(0.8, 1.0, d));
    return half4(half(in.opacity * intensity));
}

struct RingQuad { float4 position [[position]]; float2 uv; };
vertex RingQuad audioRingQuad(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    return { float4(p * 2.0 - 1.0, 0, 1), float2(p.x, 1.0 - p.y) };
}

fragment half4 audioRingComposite(RingQuad in [[stage_in]],
                                  texture2d<half> density [[texture(0)]],
                                  texture2d<half> bloom [[texture(1)]],
                                  constant RingUniforms &u [[buffer(0)]]) {
    constexpr sampler sample(filter::linear, address::clamp_to_zero);
    float core = float(density.sample(sample, in.uv).r);
    float halo = float(bloom.sample(sample, in.uv).r);
    float luminance = 1.0 - exp(-core * 2.6);
    float glow = (1.0 - exp(-halo * 1.8)) * 0.45;
    float alpha = saturate(luminance + glow);
    float3 hue = u.color.rgb / max(max(u.color.r, u.color.g), max(u.color.b, 0.001));
    float3 light = mix(hue, float3(1), pow(luminance, 3.0) * 0.5);
    // Premultiplied output leaves the existing dynamic app background untouched.
    return half4(half3(light * alpha), half(alpha));
}
