

#include "/lib/basefiles.glsl"

varying vec2 texcoord;
varying vec3 lightcol;
varying vec3 upskylight;

#ifdef VSH

    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        lightcol = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(2, 0), 0).rgb;
        upskylight = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(6, 0), 0).rgb;
    }

#endif

#ifdef FSH

    #include "/lib/fog.glsl"
    #include "/lib/water.glsl"
    #include "/lib/end.glsl"

    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 color0;

    void main() {
        vec3 outcol = texelFetch(colortex0, texelUV, 0).rgb;
        float depth = texelFetch(depthtex0, texelUV, 0).r;

        if(depth < 1.0) {
            vec3 viewPos = GetViewPosition(texcoord, depth);
            vec3 worldPos = matrixMultiply(gbufferModelViewInverse, vec4(viewPos, 1.0));
            vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos);
            float worldDis = length(worldPos);

            vec3 insca = textureBicubic(colortex4, texcoord * 0.5, viewSize).rgb;

            if(isEyeInWater == 0) {
                #ifndef DIM_END
                    #ifdef VFOG
                        float fogTransmittance = textureBicubic(colortex4, texcoord * 0.5, viewSize).a;
                        vec3 outsca = atmosOutSca(worldDir, worldDis) * fogTransmittance;
                        outcol = outcol * outsca + insca;
                    #else
                        vec3 outsca = atmosOutSca(worldDir, worldDis);
                        outcol = outcol * outsca + insca;

                        float fog = heightFog(worldDir, worldDis).r;
                        float godray = texture(colortex4, texcoord * 0.5 + 0.5).r;

                        float fogFactorDry = remapSaturate(lightDir.y, 0.0, 0.5, 1.0, 0.0);
                        float fogFactorWet = saturate(rainStrength);
                        float isRaining = step(1e-6, rainStrength);

                        fog = saturate(fog * godray * mix(fogFactorDry, fogFactorWet, isRaining));
                        if(fog > 0.0) {
                            vec3 skylight = upskylight;
                            float cosTheta = dot(lightDir, worldDir);
                            float forwardPhase = getPhase(cosTheta, 0.75);
                            float rearPhase = getPhase(cosTheta, -0.2);
                            float phase = mix(forwardPhase, rearPhase, 0.2);

                            float oneMinusRain = 1.0 - rainStrength;
                            vec3 fogColor = lightcol * (oneMinusRain * phase) + skylight * (1.0 + rainStrength);
                            fogColor *= remapSaturate(lightDir.y, 0.0, 0.25, 0.0, 1.0);
                            outcol = mix(outcol, fogColor, fog);
                        }
                    #endif
                #else
                    _vcRender(outcol, worldDir, blueNoise, worldDis);
                #endif
            } else {
                vec3 outsca = waterOutScatter(linearDepth(depth));
                outcol = outcol * outsca + insca;
            }
        }

        color0 = vec4(outcol, 1.0);
    }

#endif