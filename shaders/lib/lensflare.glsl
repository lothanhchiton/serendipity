#ifndef LENSFLARE_GLSL
    #define LENSFLARE_GLSL a

    // https://www.shadertoy.com/view/MdGSWy

    #define ORB_FLARE_COUNT 6.0
    #define DISTORTION_BARREL 1.0

    float sunVisibility(vec2 sunUV) {
        float vis = float(texture(depthtex1, sunUV).r >= 1.0);
        const int N = 6;
        for (int i = 0; i < N; i++) {
            float a = float(i) * (6.28318530718 / float(N));
            vec2 s = sunUV + vec2(cos(a), sin(a)) * 0.02;
            if (inScreen(s)) vis += float(texture(depthtex1, s).r >= 1.0);
        }
        return vis / float(N + 1);
    }

    float cOcclusion(vec2 sunUV) {
        vec3 right = normalize(cross(sunDir, vec3(0.0, 1.0, 0.0)));
        vec3 up = cross(right, sunDir);

        float clearLum = 0.0;
        float actualLum = 0.0;
        int count = 0;
        const int N = 6;

        for (int i = 0; i < N; i++) {
            float a = float(i) * (6.28318530718 / float(N));
            vec2 offset = vec2(cos(a), sin(a));
            vec2 s = sunUV + offset * 0.05;
            if (!inScreen(s)) continue;
            if (texture(depthtex1, s).r < 1.0) continue;

            vec3 sampleDir = normalize(sunDir + (offset.x * right + offset.y * up) * 0.1);
            vec2 skyUV = sph2tex(sampleDir) * 0.25;
            clearLum += getLuminance(texture(colortex5, skyUV).rgb);
            actualLum += getLuminance(texture(colortex0, s).rgb);
            count++;
        }

        if (count == 0 || clearLum < 0.001) return 0.0;
        clearLum /= float(count);
        actualLum /= float(count);

        return saturate(1.0 - actualLum / clearLum);
    }

    vec2 GetDistOffset(vec2 uv, vec2 pxoffset) {
        vec2 tocenter = uv.xy;
        vec3 prep = normalize(vec3(tocenter.y, -tocenter.x, 0.0));

        float angle = length(tocenter.xy) * 2.221 * DISTORTION_BARREL;
        vec3 oldoffset = vec3(pxoffset, 0.0);

        vec3 rotated = oldoffset * cos(angle) + cross(prep, oldoffset) * sin(angle) + prep * dot(prep, oldoffset) * (1.0 - cos(angle));

        return rotated.xy;
    }

    vec3 flare(vec2 uv, vec2 pos, float dist, float chromaOffset, float size) {
        pos = GetDistOffset(uv, pos);

        float r = max(0.01 - pow(length(uv + (dist - chromaOffset) * pos), 2.4) * (1.0 / (size * 2.0)), 0.0) * 0.85;
        float g = max(0.01 - pow(length(uv + dist                 * pos), 2.4) * (1.0 / (size * 2.0)), 0.0) * 1.0;
        float b = max(0.01 - pow(length(uv + (dist + chromaOffset) * pos), 2.4) * (1.0 / (size * 2.0)), 0.0) * 1.5;

        return vec3(r, g, b);
    }

    vec3 orb(vec2 uv, vec2 pos, float dist, float size) {
        vec3 c = vec3(0.0);

        for (float i = 0.0; i < ORB_FLARE_COUNT; i++) {
            float j = i + 1.0;
            float offset = j / (j + 0.1);
            float colOffset = j / ORB_FLARE_COUNT * 0.5;
            float ss = size / (j + 1.0);

            c += flare(uv, pos, dist + offset, ss * 2.0, ss) * vec3(1.0 - colOffset, 1.0, 0.5 + colOffset) * j;
        }

        c += flare(uv, pos, dist + 0.8, 0.05, 3.0 * size) * 0.5;

        return c;
    }

    vec3 ring(vec2 uv, vec2 pos, float dist, float chromaOffset, float blur) {
        vec2 uvd = uv * length(uv);

        float r = max(1.0 / (1.0 + 250.0 * pow(length(uvd + (dist - chromaOffset) * pos), blur)), 0.0) * 0.8;
        float g = max(1.0 / (1.0 + 250.0 * pow(length(uvd +  dist * pos), blur)), 0.0) * 1.0;
        float b = max(1.0 / (1.0 + 250.0 * pow(length(uvd + (dist + chromaOffset) * pos), blur)), 0.0) * 1.5;

        return vec3(r, g, b);
    }

    vec3 lensFlare(vec2 texcoord) {
        if (sunDir.y < -0.05) return vec3(0.0);

        float rainFade = 1.0 - rainStrength;
        if (rainFade < 0.01) return vec3(0.0);

        vec3 sunViewDir = normalize(mat3(gbufferModelView) * sunDir);
        if (sunViewDir.z >= 0.0) return vec3(0.0);

        vec3 sunScreen = ViewSpaceToScreenSpace(sunViewDir * 100.0, gbufferProjection);
        if (!inScreen(sunScreen.xy)) return vec3(0.0);

        float vis = sunVisibility(sunScreen.xy);
        if (vis < 0.01) return vec3(0.0);

        float finalVis = vis * (1.0 - cOcclusion(sunScreen.xy)) * rainFade;
        if (finalVis < 0.01) return vec3(0.0);

        float aspectRatio = viewSize.x / viewSize.y;
        float fovFactor = max(gbufferProjection[1][1], 2.0);

        vec2 coord = texcoord - 0.5;
        vec2 sunPos = sunScreen.xy - 0.5;
        coord.x *= aspectRatio;
        sunPos.x *= aspectRatio;

        vec3 lf = vec3(0.0);

        vec2 v = coord - sunPos;
        float dist = length(v);
        float gDist = dist * 13.0 / fovFactor;
        float phase = atan(v.y, v.x) + 0.131;

        float gl = 2.0 - saturate(gDist) + sin(phase * 12.0) * saturate(gDist * 2.5 - 0.2);
        gl = gl * gl;
        gDist = gDist * gDist;
        gl *= 8e-5 / (gDist * gDist);
        gl = min(gl, 200.0);

        lf += vec3(gl * FLARE_BRIGHTNESS);

        float size = 0.5 * fovFactor;
        vec3 fl = vec3(0.0);

        fl += orb(coord, sunPos, 0.0, size * 0.01) * 0.1;
        fl += ring(coord, sunPos,  1.0, 0.02, 1.4) * 0.01;
        fl += ring(coord, sunPos, -1.0, 0.02, 1.4) * 0.01;

        fl += flare(coord, sunPos, -2.00, 0.05, size * 0.05) * 0.5;
        fl += flare(coord, sunPos, -0.90, 0.02, size * 0.03) * 0.3;
        fl += flare(coord, sunPos, -0.70, 0.01, size * 0.06) * 0.5;
        fl += flare(coord, sunPos, -0.55, 0.02, size * 0.02) * 0.2;
        fl += flare(coord, sunPos, -0.35, 0.02, size * 0.04) * 0.7;
        fl += flare(coord, sunPos, -0.25, 0.01, size * 0.15) * vec3(0.3, 0.4, 0.38);
        fl += flare(coord, sunPos, -0.25, 0.02, size * 0.08) * 0.2;
        fl += flare(coord, sunPos,  0.05, 0.01, size * 0.03) * 0.1;
        fl += flare(coord, sunPos,  0.30, 0.02, size * 0.20) * vec3(0.2, 0.18, 0.14);
        fl += flare(coord, sunPos,  1.20, 0.03, size * 0.10) * 0.2;

        lf += fl * (FLARE_BRIGHTNESS * 0.3);

        vec3 suncol = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(0, 0), 0).rgb;
        lf *= suncol * finalVis * saturate(sunDir.y * 5.0 + 0.2);

        return lf;
    }
#endif