#include <metal_stdlib>
using namespace metal;

static float luma(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

static float3 restoreVideoColor(float3 rgb, float colorBoost) {
    float3 color = clamp(rgb, 0.0, 1.0);
    float boost = clamp(colorBoost, 0.8, 1.4);
    float t = (boost - 1.0) / 0.4;

    float gamma = 1.08 + 0.08 * t;
    color = pow(color, float3(gamma));

    float baseLuma = luma(color);
    float saturation = 1.08 + 0.14 * t;
    color = mix(float3(baseLuma), color, saturation);
    color = (color - 0.5) * (1.08 + 0.12 * t) + 0.5;
    color = min(color * (1.0 + 0.04 * t), 1.0);
    color = color + (0.02 * t) * color * (1.0 - color);
    return clamp(color, 0.0, 1.0);
}

static float stableDepthSample(texture2d<float, access::sample> depthTexture,
                               sampler sampleState,
                               float2 uv) {
    float2 texel = 1.0 / float2(depthTexture.get_width(), depthTexture.get_height());
    float center = clamp(depthTexture.sample(sampleState, uv).r, 0.0, 1.0);
    float left = clamp(depthTexture.sample(sampleState, uv + float2(-texel.x, 0.0)).r, 0.0, 1.0);
    float right = clamp(depthTexture.sample(sampleState, uv + float2(texel.x, 0.0)).r, 0.0, 1.0);
    float top = clamp(depthTexture.sample(sampleState, uv + float2(0.0, -texel.y)).r, 0.0, 1.0);
    float bottom = clamp(depthTexture.sample(sampleState, uv + float2(0.0, texel.y)).r, 0.0, 1.0);

    float weightLeft = 1.0 - smoothstep(0.02, 0.12, abs(left - center));
    float weightRight = 1.0 - smoothstep(0.02, 0.12, abs(right - center));
    float weightTop = 1.0 - smoothstep(0.02, 0.12, abs(top - center));
    float weightBottom = 1.0 - smoothstep(0.02, 0.12, abs(bottom - center));

    float sum = center * 0.46
        + left * (0.135 * weightLeft)
        + right * (0.135 * weightRight)
        + top * (0.135 * weightTop)
        + bottom * (0.135 * weightBottom);
    float normalizer = 0.46 + 0.135 * (weightLeft + weightRight + weightTop + weightBottom);
    return sum / max(normalizer, 1e-4);
}

static float localDepthInstability(texture2d<float, access::sample> depthTexture,
                                   sampler sampleState,
                                   float2 uv) {
    float2 texel = 1.0 / float2(depthTexture.get_width(), depthTexture.get_height());
    float left = stableDepthSample(depthTexture, sampleState, uv + float2(-texel.x, 0.0));
    float right = stableDepthSample(depthTexture, sampleState, uv + float2(texel.x, 0.0));
    float top = stableDepthSample(depthTexture, sampleState, uv + float2(0.0, -texel.y));
    float bottom = stableDepthSample(depthTexture, sampleState, uv + float2(0.0, texel.y));

    float gradientX = abs(right - left);
    float gradientY = abs(bottom - top);
    return clamp(gradientX + gradientY, 0.0, 1.0);
}

static float4 stableShiftedColorSample(texture2d<float, access::sample> sourceTexture,
                                       sampler sampleState,
                                       float2 uv,
                                       float instability) {
    float2 texel = 1.0 / float2(sourceTexture.get_width(), sourceTexture.get_height());
    float radius = mix(0.0, 1.2, smoothstep(0.08, 0.35, instability));
    float2 leftUV = clamp(uv + float2(-texel.x * radius, 0.0), 0.0, 1.0);
    float2 rightUV = clamp(uv + float2(texel.x * radius, 0.0), 0.0, 1.0);

    float4 center = sourceTexture.sample(sampleState, uv);
    if (radius <= 0.001) {
        return center;
    }

    float4 left = sourceTexture.sample(sampleState, leftUV);
    float4 right = sourceTexture.sample(sampleState, rightUV);
    return center * 0.60 + left * 0.20 + right * 0.20;
}

static float4 stereoColor(texture2d<float, access::sample> sourceTexture,
                          texture2d<float, access::sample> depthTexture,
                          sampler sampleState,
                          float2 baseUV,
                          float eyeSign,
                          float maxDisparityPixels,
                          float convergence,
                          float colorBoost,
                          float stabilityAmount) {
    float depth = stableDepthSample(depthTexture, sampleState, baseUV);
    depth = smoothstep(0.06, 0.94, depth);
    depth = mix(pow(depth, 0.85), pow(depth, 0.75), 0.4);

    float centeredDepth = depth - 0.5;
    float convergenceBias = clamp((convergence - 1.0) * 0.12, -0.18, 0.18);
    centeredDepth -= convergenceBias;

    float deadZone = 0.028;
    if (abs(centeredDepth) < deadZone) {
        centeredDepth = centeredDepth * (1.0 - (deadZone - abs(centeredDepth)) / deadZone * 0.6);
    } else {
        float depthSign = sign(centeredDepth);
        float absoluteDepth = abs(centeredDepth);
        centeredDepth = depthSign * (pow(absoluteDepth * 1.8, 1.15) / 1.8) * 0.52;
    }

    centeredDepth *= centeredDepth > 0.0 ? 1.45 : 0.92;

    float shiftPixels = centeredDepth * maxDisparityPixels * 1.06;
    float instability = localDepthInstability(depthTexture, sampleState, baseUV);
    float stability = 1.0 - smoothstep(0.06, 0.22, instability);
    shiftPixels *= mix(0.68, 1.0, stability);
    shiftPixels = clamp(shiftPixels, -0.0052 * sourceTexture.get_width(), 0.0052 * sourceTexture.get_width());

    float2 shiftedUV = baseUV;
    shiftedUV.x -= eyeSign * (shiftPixels / sourceTexture.get_width());
    shiftedUV = clamp(shiftedUV, 0.0, 1.0);

    float4 shiftedSource = stableShiftedColorSample(sourceTexture, sampleState, shiftedUV, instability);
    float4 baseSource = sourceTexture.sample(sampleState, clamp(baseUV, 0.0, 1.0));

    float edgeFade = min(min(shiftedUV.x, 1.0 - shiftedUV.x), min(shiftedUV.y, 1.0 - shiftedUV.y)) * 15.0;
    edgeFade = clamp(edgeFade, 0.0, 1.0);

    float3 shiftedConverted = restoreVideoColor(shiftedSource.rgb, colorBoost);
    float3 baseConverted = restoreVideoColor(baseSource.rgb, colorBoost);

    float shiftAmount = abs(shiftPixels / sourceTexture.get_width());
    float blendByShift = smoothstep(0.0022, 0.0052, shiftAmount);
    float blendByInstability = smoothstep(0.06, 0.26, instability);
    float antiFlickerBlend = clamp(0.18 * blendByShift + 0.82 * blendByInstability, 0.0, 0.90);
    antiFlickerBlend *= clamp(stabilityAmount, 0.0, 1.0);

    float3 converted = mix(shiftedConverted, baseConverted, antiFlickerBlend);
    converted = mix(converted * 0.95, converted, edgeFade);
    return float4(converted, shiftedSource.a);
}

kernel void depthMapKernel(
    texture2d<float, access::sample> sourceTexture [[texture(0)]],
    texture2d<half, access::write> depthTexture [[texture(1)]],
    constant float &depthStrength [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= depthTexture.get_width() || gid.y >= depthTexture.get_height()) {
        return;
    }

    float2 uv = (float2(gid) + 0.5) / float2(depthTexture.get_width(), depthTexture.get_height());

    float2 texel = 1.0 / float2(depthTexture.get_width(), depthTexture.get_height());
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    float3 c = sourceTexture.sample(s, uv).rgb;
    float3 l = sourceTexture.sample(s, uv + float2(-texel.x, 0)).rgb;
    float3 r = sourceTexture.sample(s, uv + float2(texel.x, 0)).rgb;
    float3 t = sourceTexture.sample(s, uv + float2(0, -texel.y)).rgb;
    float3 b = sourceTexture.sample(s, uv + float2(0, texel.y)).rgb;

    float lumC = luma(c);
    float lumL = luma(l);
    float lumR = luma(r);
    float lumT = luma(t);
    float lumB = luma(b);

    float edgeX = abs(lumR - lumL);
    float edgeY = abs(lumB - lumT);
    float edge = clamp(sqrt(edgeX * edgeX + edgeY * edgeY), 0.0, 1.0);

    float depth = clamp((1.0 - lumC) * 0.55 + edge * 0.45, 0.0, 1.0);
    depth = pow(depth, clamp(depthStrength, 0.2, 3.0));
    depth = smoothstep(0.04, 0.96, depth);

    depthTexture.write(half(depth), gid);
}

kernel void stereoSBSKernel(
    texture2d<float, access::sample> sourceTexture [[texture(0)]],
    texture2d<float, access::sample> depthTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant float &maxDisparityPixels [[buffer(0)]],
    constant float &convergence [[buffer(1)]],
    constant float &colorBoost [[buffer(2)]],
    constant float &stabilityAmount [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint outW = outputTexture.get_width();
    uint srcW = sourceTexture.get_width();
    uint srcH = sourceTexture.get_height();

    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    bool isLeftEye = gid.x < (outW / 2);
    uint eyeX = isLeftEye ? gid.x : (gid.x - outW / 2);
    float2 baseUV = float2(float(eyeX) + 0.5, float(gid.y) + 0.5) / float2(srcW, srcH);
    float eyeSign = isLeftEye ? -1.0 : 1.0;

    float4 color = stereoColor(sourceTexture, depthTexture, s, baseUV, eyeSign, maxDisparityPixels, convergence, colorBoost, stabilityAmount);
    outputTexture.write(color, gid);
}

kernel void stereoTABKernel(
    texture2d<float, access::sample> sourceTexture [[texture(0)]],
    texture2d<float, access::sample> depthTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant float &maxDisparityPixels [[buffer(0)]],
    constant float &convergence [[buffer(1)]],
    constant float &colorBoost [[buffer(2)]],
    constant float &stabilityAmount [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    uint outW = outputTexture.get_width();
    uint outH = outputTexture.get_height();
    uint srcH = sourceTexture.get_height();
    uint srcW = sourceTexture.get_width();

    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);

    bool isTopEye = gid.y < (outH / 2);
    uint eyeY = isTopEye ? gid.y : (gid.y - outH / 2);
    float2 baseUV = float2(float(gid.x) + 0.5, float(eyeY) + 0.5) / float2(srcW, srcH);
    float eyeSign = isTopEye ? -1.0 : 1.0;

    float4 color = stereoColor(sourceTexture, depthTexture, s, baseUV, eyeSign, maxDisparityPixels, convergence, colorBoost, stabilityAmount);
    outputTexture.write(color, gid);
}
