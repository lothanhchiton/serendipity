

#include "/lib/basefiles.glsl"

varying vec2 texcoord;

#ifdef VSH

    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }

#endif

#ifdef FSH

    #include "/lib/sky.glsl"
    #include "/lib/cloud.glsl"
    #include "/lib/bloom.glsl"
    #include "/lib/lensflare.glsl"

    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 color0;

    void main() {
        vec3 outcol = texelFetch(colortex0, texelUV, 0).rgb;

        vec3 bloom = vec3(0.0);
        for(int i = 0; i < 6; i++) {
            float lod = float(i + 2);
            vec2 newUV = texcoord / exp2(lod) + samplingOffset[i];
            if(inScreen(newUV)) {
                bloom += textureBicubic(colortex4, newUV, viewSize).rgb;
            }
        }
        float mixFactor = 0.02;
        if(isEyeInWater == 1) {
            mixFactor = mix(0.05, 0.1, remapSaturate(cameraPosition.y, 64.0, 50.0, 0.0, 1.0));
        }
        outcol = mix(outcol, bloom, mixFactor);

        #ifdef LENS_FLARE
            outcol += lensFlare(texcoord);
        #endif

        color0 = vec4(outcol, 1.0);
    }

#endif