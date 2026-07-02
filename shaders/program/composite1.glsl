

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
    #include "/lib/volumetricfog.glsl"

    /* RENDERTARGETS: 4 */
    layout(location = 0) out vec4 color4;

    void main() {
        vec4 outcol4 = vec4(0.0, 0.0, 0.0, 1.0);

        vec2 texcoord4 = texcoord * 2.0;
        if(inScreen(texcoord4)) {
            float depth = texture(depthtex0, texcoord4).r;
            if(depth < 1.0) {
                vec3 viewPos = GetViewPosition(texcoord4, depth);
                vec3 worldPos = matrixMultiply(gbufferModelViewInverse, vec4(viewPos, 1.0));
                vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos);
                float worldDis = length(worldPos);

                float godray = texture(colortex4, texcoord4 * 0.5 + 0.5).a;
                if(isEyeInWater == 0) {
                    #ifdef VFOG
                        vec4 fog = RenderVFog(worldDir, worldDis, lightDir, lightcol, upskylight, godray);
                        vec3 sky = atmosFog(worldDir, worldDis);

                        outcol4.rgb = (sky * fog.a + fog.rgb) * godray;
                        outcol4.a = fog.a;
                    #else
                        outcol4.rgb = atmosFog(worldDir, worldDis) * godray;
                        outcol4.a = 1.0;
                    #endif
                } else {
                    vec3 skylight = upskylight;
                    outcol4.rgb = waterFog(worldPos, worldDir, worldDis, lightcol, skylight, godray);
                }
            }
        }

        vec2 texcoord41 = (texcoord - vec2(0.5, 0.5)) * 2.0;
        if(inScreen(texcoord41)) {
            float depth = texture(depthtex0, texcoord41).r;
            float godray = texture(colortex4, texcoord41 * 0.5 + 0.5).a;
            outcol4.rgb = vec3(godray);
        }

        color4 = outcol4;
    }

#endif