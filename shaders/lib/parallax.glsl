

vec2 pomClamp(vec2 uv, vec4 tb) {
    return clamp(uv, tb.xy + 0.0005, tb.zw - 0.0005);
}

float pomHeight(vec2 uv, vec4 tb, vec2 dx, vec2 dy) {
    return textureGrad(normals, pomClamp(uv, tb), dx, dy).a;
}

vec2 pomUVStep(vec3 dirTS, vec2 tileUVExtent) {
    float dz = max(abs(dirTS.z), 0.15);
    vec2 step = (dirTS.xy / dz) * POM_DEPTH_SCALE * 1.6 * tileUVExtent;
    float len = length(step);
    if (len > tileUVExtent.x * 0.5) step *= (tileUVExtent.x * 0.5) / len;
    return step;
}

vec2 parallaxOcculusionMapping(vec2 baseUV, vec3 viewDirTS, vec4 tileBounds, out float outRayDepth) {
    vec2 dx = dFdx(baseUV);
    vec2 dy = dFdy(baseUV);
    vec2 ext = tileBounds.zw - tileBounds.xy;

    float dt = 1.0 / float(POM_STEPS);
    vec2 stepXY = pomUVStep(viewDirTS, ext) * dt;

    float dep = 0.0;
    vec2 uv = baseUV;
    float h = pomHeight(uv, tileBounds, dx, dy);

    vec2 pUV = uv;
    float pDep = 0.0;
    float pH = h;

    for (int i = 0; i < POM_STEPS; i++) {
        if (dep >= 1.0 - h) break;
        pUV = uv;
        pDep = dep;
        pH = h;
        uv += stepXY;
        dep += dt;
        h = pomHeight(uv, tileBounds, dx, dy);
    }

    vec2 loUV = pUV;
    float loDep = pDep;
    vec2 hiUV = uv;
    float hiDep = dep;
    float hiH = h;

    for (int r = 0; r < POM_REFINEMENT_STEPS; r++) {
        vec2 mUV = (loUV + hiUV) * 0.5;
        float mDep = (loDep + hiDep) * 0.5;
        float mH = pomHeight(mUV, tileBounds, dx, dy);

        if (mDep < 1.0 - mH) {
            loUV = mUV;
            loDep = mDep;
        } else {
            hiUV = mUV;
            hiDep = mDep;
            hiH = mH;
        }
    }

    float below = hiDep - (1.0 - hiH);
    float above = (1.0 - pH) - loDep;
    float t = above / max(above + below, 1e-5);

    outRayDepth = mix(loDep, hiDep, t);
    return pomClamp(mix(loUV, hiUV, t), tileBounds);
}

vec2 parallaxOcculusionMappingShadow(vec2 baseUV, vec3 viewDirTS, vec3 lightDirTS, vec4 tileBounds, out float outRayDepth, out float outShadow) {
    vec2 finalUV = parallaxOcculusionMapping(baseUV, viewDirTS, tileBounds, outRayDepth);
    vec2 dx = dFdx(baseUV);
    vec2 dy = dFdy(baseUV);
    outShadow = 1.0;

    #ifdef PARALLAX_SHADOW
        if (outRayDepth > 0.001 && lightDirTS.z > 0.001) {
            vec2 ext = tileBounds.zw - tileBounds.xy;
            float dStp = outRayDepth / float(POM_SHADOW_STEPS);
            vec2 sStp = pomUVStep(-lightDirTS, ext) * dStp;

            vec2 sUV = finalUV;
            float sDep = outRayDepth;
            float minRatio = 0.0;

            for (int s = 0; s < POM_SHADOW_STEPS; s++) {
                sUV += sStp;
                sDep -= dStp;
                if (sDep <= 0.0) break;
                float occH = pomHeight(sUV, tileBounds, dx, dy);
                float occ = (1.0 - occH - sDep) * (POM_SHADOW_SOFTNESS / max(outRayDepth, 0.001));
                minRatio = max(minRatio, occ);
            }
            outShadow = clamp(1.0 - minRatio, 0.0, 1.0);
        }
    #endif

    return finalUV;
}