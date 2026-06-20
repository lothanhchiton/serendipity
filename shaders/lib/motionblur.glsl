

vec2 getVelocity(vec2 uv) {
    float depth = texelFetch(depthtex1, ivec2(uv * viewSize), 0).r;
    vec3 viewPos = GetViewPosition(uv, depth);
    vec3 worldPos = matrixMultiply(gbufferModelViewInverse, vec4(viewPos, 1.0));

    vec3 preScreenPos = getPreScreenPos(worldPos);
    vec2 velocity = uv - preScreenPos.xy;

    float blockID = texture(colortex1, uv).b * 10000.0;
    bool ishand = abs(blockID - 9999.0) < 0.5;

    velocity *= float(depth < 1.0 && inScreen(preScreenPos.xy));
    velocity *= float(!ishand);
    return velocity;
}

vec3 motionBlur(vec2 texcoord) {
    float depth = texelFetch(depthtex1, texelUV, 0).r;

    #ifdef MOTION_BLUR_SKY
        if(depth == 1.0) {
            return texelFetch(colortex0, texelUV, 0).rgb;
        }
    #endif

    vec2 velocity = getVelocity(texcoord) * MOTION_BLUR_STRENGTH;

    float speedPx = length(velocity * viewSize);
    speedPx = min(speedPx, MOTION_BLUR_MAX_PX);

    if(speedPx < 0.6) {
        return texelFetch(colortex0, texelUV, 0).rgb;
    }

    vec2 dir = velocity / max(length(velocity), 1e-6);
    vec2 step = dir * (speedPx / viewSize) / float(MOTION_BLUR_SAMPLES - 1);

    float dither = interleavedGradientNoise(gl_FragCoord.xy) - 0.5;

    vec3 accum = vec3(0.0);
    float total = 0.0;

    for(int i = 0; i < MOTION_BLUR_SAMPLES; i++) {
        float t = float(i) - float(MOTION_BLUR_SAMPLES - 1) * 0.5 + dither;
        vec2 sampleUV = clamp(texcoord + step * t, vec2(0.0), vec2(1.0));

        accum += texture(colortex0, sampleUV).rgb;
        total += 1.0;
    }

    return accum / total;
}