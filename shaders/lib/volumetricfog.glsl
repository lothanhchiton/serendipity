#ifndef VOLUMETRIC_FOG_GLSL
    #define VOLUMETRIC_FOG_GLSL a

    #define FogScatteringCoefficient 0.8
    #define FogAbsorptionCoefficient 0.2
    #define FogMultiScatteringD 0.5

    float sampleFogDensity(vec3 worldPos, float fogHeight, float fogFalloff) {
        float height = worldPos.y - fogHeight;
        float heightFalloff = exp(-max0(height) * fogFalloff);

        float frequency = FOG_NOISE_SCALE;
        float weight = 1.0;
        float time = 0.015 * frameTimeCounter;

        float n = 0.0;
        float c = 0.0;
        for(int i = 0; i < 3; i++) {
            n += perlin2D((worldPos.xz + cameraPosition.xz) * frequency + time) * weight;
            c += weight;
            frequency *= 2.0;
            weight *= 0.5;
            time *= 1.1;
        }
        n = n / c * 0.5 + 0.5;

        float density = mix(0.6, 1.4, n) * heightFalloff;
        return saturate(density) * FOG_DENSITY;
    }

    vec4 RenderVFog(vec3 worldDir, float worldDis, vec3 lightDir, vec3 lightLuminance, vec3 skylight, float godray) {
        float fogHeight = FOG_HEIGHT;
        float fogFalloff = FOG_FALLOFF;

        vec3 lightColor = lightLuminance * remapSaturate(lightDir.y, 0.02, 0.1, 0.0, 1.0);
        vec3 ambientColor = saturation(skylight, 0.33) * 2.0;
        ambientColor *= remapSaturate(lightDir.y, 0.0, 0.25, 0.05, 1.0);

        float cosTheta = dot(lightDir, worldDir);
        float forwardPhase = getPhase(cosTheta, 0.4);
        float rearPhase = getPhase(cosTheta, -0.4);
        float phase = mix(forwardPhase, rearPhase, 0.25);
        float uniform_phase = 1.0 / (4.0 * PI);

        int sampleCount = max(1, int(FOG_QUALITY * clamp(worldDis * 0.5, 8.0, 32.0)));
        float ds = worldDis / float(sampleCount);
        vec3 stepVec = worldDir * ds;
        vec3 samplePos = cameraPosition + stepVec * blueNoise;

        float transmittance = 1.0;
        vec3 scattering = vec3(0.0);
        for(int i = 0; i < sampleCount; i++) {
            float density = sampleFogDensity(samplePos, fogHeight, fogFalloff);
            float stepTransmittance = 1.0;

            if(density > 1e-5) {
                float sigmaS = density * FogScatteringCoefficient;
                float sigmaA = density * FogAbsorptionCoefficient;
                float sigmaE = sigmaS + sigmaA;
                stepTransmittance = exp(-sigmaE * ds);

                vec3 lightEnergy = lightColor * godray * sigmaS;

                float D = FogMultiScatteringD;
                float f_ms = (sigmaS / sigmaE) * (1.0 - exp(-D * sigmaE));
                vec3 multiScattering = lightEnergy * f_ms / max(1.0 - f_ms, 1e-6) * uniform_phase;

                vec3 ambientlight = ambientColor * sigmaS;

                vec3 stepScattering = lightEnergy * phase + multiScattering + ambientlight;
                stepScattering = stepScattering * (1.0 - stepTransmittance) / max(sigmaE, 1e-6);

                scattering += stepScattering * transmittance;
            }

            samplePos += stepVec;
            transmittance *= stepTransmittance;
        }

        return vec4(scattering, transmittance);
    }

#endif