#include <metal_stdlib>
using namespace metal;

struct VisionUIVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct VisionUICompositeUniforms {
    float time;
    float opacity;
    float cornerRadius;
    float4 layerMix;
    float2 uvScale;
    float2 uvOffset;
};

vertex VisionUIVertexOut visionUIVertex(uint vid [[vertex_id]], constant float4 *verts [[buffer(0)]]) {
    VisionUIVertexOut out;
    float4 v = verts[vid];
    out.position = float4(v.xy, 0.0, 1.0);
    out.uv = v.zw;
    return out;
}

fragment float4 visionUIFragment(
    VisionUIVertexOut in [[stage_in]],
    constant VisionUICompositeUniforms &uniforms [[buffer(0)]],
    texture2d<float> videoTexture [[texture(0)]],
    texture2d<float> overlayTexture [[texture(1)]]
) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = in.uv * uniforms.uvScale + uniforms.uvOffset;

    float4 videoColor = videoTexture.get_width() > 0 ? videoTexture.sample(s, uv) : float4(0.05, 0.06, 0.08, 1.0);
    float4 overlayColor = overlayTexture.get_width() > 0 ? overlayTexture.sample(s, uv) : float4(0.0);

    float grain = fract(sin(dot(uv + uniforms.time * 0.03, float2(12.9898,78.233))) * 43758.5453) * 0.012;
    float vignette = smoothstep(1.1, 0.25, distance(uv, float2(0.5, 0.5)));

    float4 color = mix(videoColor, overlayColor, clamp(overlayColor.a * uniforms.layerMix.y, 0.0, 1.0));
    color.rgb += grain;
    color.rgb *= (0.85 + 0.15 * vignette);
    color.a = uniforms.opacity;
    return color;
}

kernel void visionNV12ToRGB(
    texture2d<float, access::sample> yTex [[texture(0)]],
    texture2d<float, access::sample> uvTex [[texture(1)]],
    texture2d<float, access::write> outTex [[texture(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;

    float2 uv = (float2(gid) + 0.5) / float2(outTex.get_width(), outTex.get_height());
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    float Y = yTex.sample(s, uv).r;
    float2 CbCr = uvTex.sample(s, uv).rg;
    float U = CbCr.x - 0.5;
    float V = CbCr.y - 0.5;

    float r = Y + 1.4020 * V;
    float g = Y - 0.3441 * U - 0.7141 * V;
    float b = Y + 1.7720 * U;

    outTex.write(float4(r, g, b, 1.0), gid);
}

kernel void visionSphereProject(
    texture2d<float, access::sample> src [[texture(0)]],
    texture2d<float, access::write> dst [[texture(1)]],
    constant float2 &uvScale [[buffer(0)]],
    constant float2 &uvOffset [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(dst.get_width(), dst.get_height());
    float2 srcUV = uv * uvScale + uvOffset;
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    dst.write(src.sample(s, srcUV), gid);
}
