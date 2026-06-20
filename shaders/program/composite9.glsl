

#include "/lib/basefiles.glsl"

varying vec2 texcoord;

#ifdef VSH

    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }

#endif

#ifdef FSH

    #include "/lib/motionblur.glsl"

    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 color0;

    void main() {
        vec3 outcol = texelFetch(colortex0, texelUV, 0).rgb;

        #ifdef MOTION_BLUR
            outcol = motionBlur(texcoord);
        #endif

        color0 = vec4(outcol, 1.0);
    }

#endif