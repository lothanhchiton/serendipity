

#include "/lib/basefiles.glsl"

varying vec2 texcoord;
varying vec3 suncol;
varying vec3 mooncol;
varying vec3 lightcol;
varying vec4 skySHR;
varying vec4 skySHG;
varying vec4 skySHB;

#ifdef VSH

    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        suncol = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(0, 0), 0).rgb;
        mooncol = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(1, 0), 0).rgb;
        lightcol = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(2, 0), 0).rgb;
        skySHR = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(3, 0), 0);
        skySHG = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(4, 0), 0);
        skySHB = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(5, 0), 0);
    }

#endif

#ifdef FSH

    layout(std430, binding = 0) buffer ssptBuffer {
        vec4 ssptData[];
    };

    #include "/lib/light.glsl"
    #include "/lib/sky.glsl"
    #include "/lib/shadow.glsl"
    #include "/lib/sspt.glsl"

    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 color0;

    vec3 heldLightColor(vec3 handPos) {
        vec3 screenPos = ViewSpaceToScreenSpace(handPos, gbufferProjection);
        if(inScreen(screenPos.xy)) {
            return texture(colortex7, screenPos.xy).rgb;
        }
        return vec3(1.0);
    }

    void main() {
        vec3 outcol = vec3(0.1, 0.2, 0.4) * (max0(sunDir.y) * 1.5 + max0(moonDir.y) * 0.25);

        float depth = texelFetch(depthtex1, texelUV, 0).r;

        if(depth < 1.0) {
            vec3 data0 = texelFetch(colortex0, texelUV, 0).rgb;
            vec4 data1 = texelFetch(colortex1, texelUV, 0);
            vec4 data2 = texelFetch(colortex2, texelUV, 0);
            vec4 data3 = texelFetch(colortex3, texelUV, 0);
            vec4 data4 = texture(colortex4, texcoord * 0.5);

            vec3 viewPos = GetViewPosition(texcoord, depth);
            vec3 worldPos = matrixMultiply(gbufferModelViewInverse, vec4(viewPos, 1.0));
            vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos);
            float worldDis = length(worldPos);

            vec3 albedo = GammaToLinear(data0);
            vec3 worldOriNormal = normalDecode(data2.xy);
            vec3 worldNormal = normalDecode(data2.zw);
            vec3 viewOriNormal = normalize(mat3(gbufferModelView) * worldOriNormal);

            vec2 uv1 = remap(data1.rg, vec2(0.5 / 16.0), vec2(15.5 / 16.0), vec2(0.0), vec2(1.0));
            float blockID = data1.b * 10000.0;
            float roughness = (1.0 - data3.r);
            float metallic = data3.g;
            float wetFactor = pow2(rainStrength) * uv1.y;
            albedo *= 1.0 - wetFactor * 0.25;
            roughness = mix(roughness, roughness * 0.7, wetFactor * 0.5);
            bool isGrass = abs(blockID - 31.0) < 0.5 || abs(blockID - 32.0) < 0.5 || abs(blockID - 33.0) < 0.5;
            bool isLeaves = abs(blockID - 18.0) < 0.5;
            bool isHand = abs(blockID - 9999.0) < 0.5;

            vec3 shadow = vec3(1.0);
            if(isHand) {
                shadow = vec3(pow5(uv1.y));
            } else if(isGrass) {
                shadow = getShadow(worldPos + worldNormal * 0.01 * worldDis, 1.0) * 0.5;
                worldNormal = vec3(0.0, 1.0, 0.0);
                roughness = 1.0;
            } else if(dot(worldNormal, lightDir) > 0.0) {
                shadow = getShadow(worldPos + worldNormal * 0.01 * worldDis);
            }

            if (!isHand && !isGrass) {
                shadow *= data1.a;
            }

            float repairlightleakage = isEyeInWater == 0 ? linearstep(0.035, 0.1, uv1.y) : 1.0;

            vec3 sunlight = suncol * shadow;
            vec3 moonlight = mooncol * shadow;
            vec3 gtao = GTAOMultiBounce(data4.a, albedo);

            vec3 directlight = CalculateDirectlight(albedo, roughness, metallic, worldNormal, worldDir, sunlight, moonlight);
            directlight *= repairlightleakage;

            vec3 skylight = FromSphericalHarmonics(skySHR, skySHG, skySHB, worldNormal);
            skylight = skylight * pow5(uv1.y) * gtao;
            skylight *= pow2(dot(worldNormal, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5) * 2.0;

            #if LIGHT_MODE == 2
                vec3 ambientlight = skylight * albedo;
                if(!isHand) ambientlight += sspt(viewPos, worldPos, worldNormal, albedo);
            #else
                vec3 rsm = data4.rgb * lightcol;
                vec3 ambientlight = (skylight + rsm) * albedo;
            #endif

            #if LIGHT_MODE == 2
                ambientlight += sspt(viewPos, worldPos, worldNormal, albedo);
            #endif

            vec3 ssslight = vec3(0.0);
            if(isLeaves) {
                ssslight = SSS(albedo, worldPos, worldDir, lightcol);
            }

            bool isEmissive = abs(blockID - 89.0) < 0.5;

            #if LIGHT_MODE == 2
                vec3 blocklight = isEmissive ? albedo * pow10(uv1.x) * 4.0 : vec3(0.0);
            #else
                vec3 blocklightcol = albedo * vec3(5.0, 2.5, 0.25) * 0.05 * gtao;
                vec3 blocklight = blocklightcol * pow10(uv1.x);
            #endif

            #if LIGHT_MODE == 2
                vec3 handlight = vec3(0.0);
                if(heldBlockLightValue > 0.0) {
                    vec3 lightCol = heldLightColor(handPosition);
                    float disToLight = distance(viewPos, handPosition);
                    handlight += albedo * lightCol * gtao * 5.0 * (heldBlockLightValue / 15.0) / max(pow2(disToLight), 0.1) * exp(-disToLight * 0.1);
                }
                if(heldBlockLightValue2 > 0.0) {
                    vec3 lightCol = heldLightColor(handPosition2);
                    float disToLight = distance(viewPos, handPosition2);
                    handlight += albedo * lightCol * gtao * 5.0 * (heldBlockLightValue2 / 15.0) / max(pow2(disToLight), 0.1) * exp(-disToLight * 0.1);
                }
            #else
                vec3 handlight = vec3(0.0);
                if(heldBlockLightValue > 0.0) {
                    float disToLight = distance(viewPos, handPosition);
                    handlight += blocklightcol * (heldBlockLightValue / 15.0) / max(pow2(disToLight), 0.1) * exp(-disToLight * 0.1);
                }
                if(heldBlockLightValue2 > 0.0) {
                    float disToLight = distance(viewPos, handPosition2);
                    handlight += blocklightcol * (heldBlockLightValue2 / 15.0) / max(pow2(disToLight), 0.1) * exp(-disToLight * 0.1);
                }
            #endif

            vec3 baselight = vec3(0.002) * albedo * gtao * (1.0 - uv1.y);

            outcol = directlight + ambientlight + ssslight + blocklight + handlight + baselight;

            #ifdef SPECULAR_REFLECTION
                float smoothness = 1.0 - roughness;
                vec3 F0 = mix(vec3(0.04), albedo, metallic);

                vec3 worldReflectDir = reflect(worldDir, worldNormal);
                vec3 viewReflectDir = normalize(mat3(gbufferModelView) * worldReflectDir);

                vec2 rayTracingPos = vec2(0.0);
                bool rayTracingIsHit = false;
                screenRayTracingDDA(viewPos, viewReflectDir, rayTracingPos, rayTracingIsHit);

                vec3 reflectionCol = sampleSkybox(worldReflectDir) * uv1.y;
                if(rayTracingIsHit) {
                    vec2 prevUV = getPreCoord(rayTracingPos.xy);
                    reflectionCol = texture(colortex7, outScreen(prevUV) ? rayTracingPos.xy : prevUV).rgb;
                }

                float fresnel = fresnelSchlick(max0(dot(worldNormal, -worldDir)), 0.04);
                vec3 specF = mix(vec3(fresnel), F0, metallic);

                outcol += reflectionCol * specF * pow2(smoothness);
            #endif

            if(rainStrength > 1e-6 && uv1.y > 1e-6 && !isGrass) {
                float smoothness = data3.r;
                float puddleMask = smoothstep(0.7, 0.92, smoothness);

                vec3 worldReflectDir = reflect(worldDir, worldNormal);
                vec3 viewReflectDir = normalize(mat3(gbufferModelView) * worldReflectDir);

                vec2 rayTracingPos = vec2(0.0);
                bool rayTracingIsHit = false;
                screenRayTracingDDA(viewPos, viewReflectDir, rayTracingPos, rayTracingIsHit);

                vec3 rayTracingCol = sampleSkybox(worldReflectDir) * uv1.y;
                if(rayTracingIsHit) {
                    vec2 prevUV = getPreCoord(rayTracingPos.xy);
                    rayTracingCol = texture(colortex7, outScreen(prevUV) ? rayTracingPos.xy : prevUV).rgb;
                }

                float wetFresnel = fresnelSchlick(max0(dot(worldNormal, -worldDir)), 0.02);
                outcol = mix(outcol, rayTracingCol, wetFresnel * wetFactor * 0.4);

                if(puddleMask > 0.001) {
                    float fresnel = fresnelSchlick(max0(dot(worldNormal, -worldDir)), 0.02);
                    outcol = mix(outcol, rayTracingCol, fresnel * puddleMask);
                }
            }
        }

        outcol = max0(outcol);

        color0 = vec4(outcol, 1.0);
    }

#endif