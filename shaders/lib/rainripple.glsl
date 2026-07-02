#ifndef RAIN_RIPPLE_GLSL
    #define RAIN_RIPPLE_GLSL a

    vec3 blendRNormal(vec3 baseN, vec3 rippleN) {
        vec3 t = baseN + vec3(0.0, 0.0, 1.0);
        vec3 u = rippleN * vec3(-1.0, -1.0, 1.0);
        return normalize(t * dot(t, u) - u * t.z);
    }

    float hash21(vec2 p) {
        p = fract(p * vec2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    vec3 sampleRFrame(vec2 worldUV, float time, vec2 tileOffset, float timeOffset) {
        float frame = floor(mod((time + timeOffset) * RIPPLE_SPEED * 8.0, 64.0));

        vec2 uv = fract(worldUV * RIPPLE_SCALE + tileOffset);
        uv.y = uv.y * (1.0 / 64.0) + frame * (1.0 / 64.0);

        vec4 data = texture(rippleTex, uv);
        vec3 n = data.xyz * 2.0 - 1.0;
        return normalize(n);
    }

    vec3 rainR(vec3 worldPos, vec3 surfaceNormal, vec3 baseNormal, float wetness) {
        float upFacing = clamp(surfaceNormal.y, 0.0, 1.0);
        upFacing = smoothstep(0.6, 1.0, upFacing);

        float strength = wetness * upFacing;
        if (strength <= 0.001) return baseNormal;

        vec2 tileId = floor(worldPos.xz * RIPPLE_SCALE);
        float h1 = hash21(tileId);
        float h2 = hash21(tileId + 17.0);
        vec2 tileOffset = vec2(h1, h2) * 4.0;
        float timeOffset = h1 * 37.0;

        vec3 rippleA = sampleRFrame(worldPos.xz, frameTimeCounter, tileOffset, timeOffset);

        vec2 tileId2 = floor(worldPos.xz * RIPPLE_SCALE * 0.37 + 11.0);
        float h3 = hash21(tileId2);
        vec3 rippleB = sampleRFrame(worldPos.xz * 1.7, frameTimeCounter * 0.83, vec2(h3, h3 * 3.1) * 4.0, h3 * 53.0);

        vec3 rippleN = normalize(mix(rippleA, rippleB, 0.35));
        rippleN = normalize(mix(vec3(0.0, 0.0, 1.0), rippleN, strength));

        return blendRNormal(baseNormal, rippleN);
    }

#endif