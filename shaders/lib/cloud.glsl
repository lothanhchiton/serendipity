#ifndef CLOUD_GLSL
    #define CLOUD_GLSL A

    #define CloudScatteringCoefficient 50.0
    #define CloudAbsorptionCoefficient 20.0
    #define CloudMultiScatteringD 0.5

    #define CloudHeight 2.0
    #define CloudThickness 1.0

    #define CloudDensityMultiplier 1.0

    const float CloudBottomHeight = EarthRadius + CloudHeight;
    const float CloudTopHeight = CloudBottomHeight + CloudThickness;

    float sampleCloudDensity(vec3 pos) {
        float frequency = 0.3;
        float weight = 1.0;
        float time = 0.02 * frameTimeCounter;

        float n = 0.0;
        float c = 0.0;
        for(int i = 0; i < 4; i++) {
            n += perlin2D(pos.xz * frequency + time) * weight;
            c += weight;

            frequency *= 2.0;
            weight *= 0.5;
            time *= 1.1;
        }
        n /= c;

        float cloudmap = saturate((sample2DNoise(pos.xz * 0.2 + frameTimeCounter * 0.01) * 3.0 - 0.5) * 0.5 + 0.5);
        n *= cloudmap;

        float bias = mix(0.5, 0.1, rainStrength);
        n = max0(n - bias) / max(1.0 - bias, 1e-4);
        n = saturate(n);

        float frequency1 = 5.0;
        float weight1 = 1.0;
        float time1 = 0.1 * frameTimeCounter;

        float n1 = 0.0;
        float c1 = 0.0;
        for(int i = 0; i < 4; i++) {
            n1 += sample3DNoise(pos * frequency1 + time1) * weight1;
            c1 += weight1;

            frequency1 *= 2.5;
            weight1 *= 0.5;
            time1 *= 1.1;
        }
        n1 /= c1;

        float h = saturate((length(pos) - CloudBottomHeight) / CloudThickness);

        float s = smoothstep(0.0, 1.0, h);
        s = s * 0.8 + 0.25;

        if(n <= 0.0) return 0.0;

        n = remapSaturate(n, n1 * s * 0.6, 1.0, 0.0, 1.0);

        float bottomFade = smoothstep(0.0, 0.08, h);
        n *= bottomFade;

        return saturate(n) * CloudDensityMultiplier;
    }
    float CloudOpticalDepth(vec3 pos, vec3 dir, float len, float currDensity, int N_SAMPLE) {
        if(len <= 0.0) return 0.0;

        float ds = len / float(N_SAMPLE);
        vec3 samplePos = pos;
        vec3 stepVec = dir * ds;

        float density0 = currDensity;

        float opticalDepth = 0.0;
        for(int i = 0; i < N_SAMPLE; i++) {
            samplePos += stepVec;

            float density = sampleCloudDensity(samplePos);

            opticalDepth += density0 + density;
            density0 = density;
        }

        return opticalDepth * 0.5 * ds;
    }
    float CloudTransmittance(vec3 pos, vec3 dir, float currDensity, int N_SAMPLE) {
        float lenToCloudTop = rayIntersectSphere(pos, dir, CloudTopHeight * CloudTopHeight);

        float len = min(lenToCloudTop, CloudThickness * 0.5);

        float optic = CloudOpticalDepth(pos, dir, len, currDensity, N_SAMPLE);
        return exp(-(CloudScatteringCoefficient + CloudAbsorptionCoefficient) * optic);
    }
    vec4 RenderCloud(vec3 pos, vec3 dir, vec3 lightDir, vec3 lightLuminance, vec3 skylight) {
        float lenToCloudBottom = rayIntersectSphere(pos, dir, CloudBottomHeight * CloudBottomHeight);
        float lenToCloudTop = rayIntersectSphere(pos, dir, CloudTopHeight * CloudTopHeight);

        float lenToCloud = 0.0;
        float lenToCloudEnd = 0.0;
        if(pos.y < CloudBottomHeight) {
            float lenToEarth = rayIntersectSphere(pos, dir, pow2(EarthRadius + ReferenceHeight));
            if(lenToEarth > 0.0) {
                return vec4(vec3(0.0), 1.0);
            } else {
                lenToCloud = max0(lenToCloudBottom);
                lenToCloudEnd = max0(lenToCloudTop);
            }
        } else if(pos.y < CloudTopHeight) {
            lenToCloud = 0.0;
            if(lenToCloudBottom > 0.0) {
                lenToCloudEnd = max0(lenToCloudBottom);
            } else {
                lenToCloudEnd = max0(lenToCloudTop);
            }
        } else {
            lenToCloud = max0(lenToCloudTop);
            lenToCloudEnd = max0(lenToCloudBottom);
        }
        float len = max0(lenToCloudEnd - lenToCloud);

        vec3 cloudTopPos = pos + dir * lenToCloudTop;
        lightLuminance *= remapSaturate(lightDir.y, 0.02, 0.1, 0.0, 1.0);
        vec3 lightColor = lightLuminance * TransToAtmos(cloudTopPos, lightDir);
        vec3 ambientColor = saturation(skylight, 0.33) * 3.0;
        ambientColor *= remapSaturate(lightDir.y, 0.0, 0.25, 0.05, 1.0);

        float cosTheta = dot(lightDir, dir);
        float forwardPhase = getPhase(cosTheta, 0.5);
        float rearPhase = getPhase(cosTheta, -0.5);
        float phase = mix(forwardPhase, rearPhase, 0.2);
        float uniform_phase = 1.0 / (4.0 * PI);

        int sampleCount = int(mix(72.0, 18.0, abs(dir.y)));
        //const int sampleCount = 12;

        float ds = len / float(sampleCount);
        vec3 stepVec = dir * ds;
        vec3 samplePos = pos + dir * lenToCloud;

        vec3 jitter = stepVec * blueNoise;
        samplePos += jitter;

        float transmittance = 1.0;
        vec3 scattering = vec3(0.0);
        for(int i = 0; i < sampleCount; i++) {
            float stepCloudDensity = sampleCloudDensity(samplePos);
            float stepTransmittance = 1.0;

            if(stepCloudDensity > 1e-5) {
                float sigmaS = stepCloudDensity * CloudScatteringCoefficient;
                float sigmaA = stepCloudDensity * CloudAbsorptionCoefficient;
                float sigmaE = sigmaS + sigmaA;
                stepTransmittance = exp(-sigmaE * ds);

                float lightVisibility = CloudTransmittance(samplePos, lightDir, stepCloudDensity, 3);
                vec3 lightEnergy = lightColor * lightVisibility * sigmaS;

                float D = CloudMultiScatteringD;
                float f_ms = (sigmaS / sigmaE) * (1.0 - exp(-D * sigmaE));
                vec3 multiScattering = lightEnergy * f_ms / max(1.0 - f_ms, 1e-6) * uniform_phase;

                float ambientVisibility = CloudTransmittance(samplePos, vec3(0.0, 1.0, 0.0), stepCloudDensity, 2) * 0.5 + 0.5;
                vec3 ambientlight = ambientColor * ambientVisibility * sigmaS;

                vec3 stepScattering = lightEnergy * phase + multiScattering + ambientlight;
                stepScattering = stepScattering * (1.0 - stepTransmittance) / max(sigmaE, 1e-6);

                scattering += stepScattering * transmittance;
            }

            samplePos += stepVec;
            transmittance *= stepTransmittance;
        }

        mat2x3 atmosphere = AtmosphereScattering(pos, dir, lenToCloud, lightDir, lightLuminance, 4);
        vec3 insca = atmosphere[0];
        vec3 outsca = atmosphere[1];
        scattering = scattering * outsca + insca * (1.0 - transmittance);

        return vec4(scattering, transmittance);
    }

    #define Cloud2DHeight 8.0

    const float Cloud2DReallyHeight = EarthRadius + Cloud2DHeight;

    vec4 RenderCloud2D(vec3 pos, vec3 dir, vec3 lightDir, vec3 lightLuminance) {
        float lenToEarth = rayIntersectSphere(pos, dir, pow2(EarthRadius + ReferenceHeight));
        if(pos.y < Cloud2DReallyHeight && lenToEarth > 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

        float lenToCloud = rayIntersectSphere(pos, dir, Cloud2DReallyHeight * Cloud2DReallyHeight);
        if(lenToCloud < 0.0) return vec4(0.0, 0.0, 0.0, 1.0);

        vec3 cloudpos = pos + dir * lenToCloud;
        lightLuminance *= remapSaturate(lightDir.y, 0.02, 0.1, 0.0, 1.0);
        vec3 lightColor = lightLuminance * TransToAtmos(cloudpos, lightDir);

        float frequency = 500.0;
        float weight = 1.0;
        float time = 0.01 * frameTimeCounter;

        vec2 np = cloudpos.xz / Cloud2DReallyHeight;
        np -= (1.0 - worley2DCell(np * frequency * 1.0 + time)) * 0.001;
        float n = 0.0;
        float c = 0.0;
        for(int i = 0; i < 6; i++) {
            n += perlin2D(np * frequency + time) * weight;
            c += weight;

            frequency *= 2.5;
            weight *= 0.5;
            time *= 1.1;
        }
        n /= c;
        float cloudRange = 0.55;
        float cloudDensity = remapSaturate(n - 1.0 + cloudRange, 0.0, cloudRange, 0.0, 1.0) * 0.07 * CloudDensityMultiplier;
        if(cloudDensity < 1e-5) return vec4(0.0, 0.0, 0.0, 1.0);

        float cosTheta = dot(lightDir, dir);
        float forwardPhase = getPhase(cosTheta, 0.5);
        float rearPhase = getPhase(cosTheta, -0.5);
        float phase = mix(forwardPhase, rearPhase, 0.2);

        float sigmaS = cloudDensity * CloudScatteringCoefficient;
        float sigmaA = cloudDensity * CloudAbsorptionCoefficient;
        float sigmaE = sigmaS + sigmaA;
        float transmittance = exp(-sigmaE);
        vec3 scattering = lightColor * sigmaS * phase;

        mat2x3 atmosphere = AtmosphereScattering(pos, dir, lenToCloud, lightDir, lightLuminance, 4);
        vec3 insca = atmosphere[0];
        vec3 outsca = atmosphere[1];
        scattering = scattering * outsca + insca * (1.0 - transmittance);

        return vec4(scattering, transmittance);
    }

#endif
