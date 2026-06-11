

#include "/lib/basefiles.glsl"

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;
varying float blockID;
varying mat3 tbnMatrix;
varying vec3 viewDirTS;
varying vec4 tileBounds;

#ifdef VSH

    #if MC_VERSION >= 11500
        layout(location = 11) in vec4 mc_Entity;
    #else
        layout(location = 10) in vec4 mc_Entity;
    #endif

    in vec4 at_tangent;
    in vec2 mc_midTexCoord;

    void main() {
        vec3 model_pos = gl_Vertex.xyz;
        vec4 view_pos = gl_ModelViewMatrix * vec4(model_pos, 1.0);
        vec4 clip_pos = gl_ProjectionMatrix * view_pos;
        #ifdef TAA
            clip_pos.xy += taaJitter * TAA_Intensity * clip_pos.w;
        #endif
        gl_Position = clip_pos;

        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        lmcoord = clamp(lmcoord, 0.5 / 16.0, 15.5 / 16.0);
        glcolor = gl_Color;
        normal = gl_NormalMatrix * gl_Normal;
        normal = normalize(mat3(gbufferModelViewInverse) * normal);
        blockID = mc_Entity.x;

        vec3 tangent = gl_NormalMatrix * normalize(at_tangent.xyz);
        tangent = normalize(mat3(gbufferModelViewInverse) * tangent);
        tbnMatrix = mat3(tangent, normalize(cross(tangent, normal) * at_tangent.w), normal);

        vec3 vsPos = (gl_ModelViewMatrix * vec4(gl_Vertex.xyz, 1.0)).xyz;
        vec3 wvDir = normalize(mat3(gbufferModelViewInverse) * vsPos);
        viewDirTS = vec3(dot(wvDir, tbnMatrix[0]),
                         dot(wvDir, tbnMatrix[1]),
                         dot(wvDir, tbnMatrix[2]));

        vec2 midUV = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).xy;
        vec2 halfExt = abs(texcoord - midUV);
        tileBounds = vec4(midUV - halfExt, midUV + halfExt);
    }

#endif

#ifdef FSH

     #include "/lib/parallax.glsl"

    /* RENDERTARGETS: 0,1,2,3 */
    layout(location = 0) out vec4 color0;
    layout(location = 1) out vec4 color1;
    layout(location = 2) out vec4 color2;
    layout(location = 3) out vec4 color3;

    void main() {
        #ifdef PARALLAX
            float pomRayDepth, pomShadow;
            vec3 lDirTS = vec3(dot(lightDir, tbnMatrix[0]),
                               dot(lightDir, tbnMatrix[1]),
                               dot(lightDir, tbnMatrix[2]));
            vec2 pomUV = parallaxOcculusionMappingShadow(texcoord, viewDirTS, lDirTS, tileBounds, pomRayDepth, pomShadow);
        #else
            vec2 pomUV = texcoord;
            float pomShadow = 1.0;
        #endif

        vec4 texcolor = texture(gtexture, pomUV);
        if (texcolor.a < alphaTestRef) {
            discard;
        }

        texcolor.rgb *= glcolor.rgb;

        #ifdef VanillaAO
            texcolor.rgb *= glcolor.a;
        #else
            if (abs(blockID - 18.0) < 0.5) {
                texcolor.rgb *= glcolor.a;
            }
        #endif

        vec4 normalData = texture(normals, pomUV);
        normalData.xyz = normalize(normalData.xyz * 2.0 - 1.0);
        vec3 mappedNormal = normalize(tbnMatrix * normalData.xyz);
        vec4 specularData = texture(specular, pomUV);

        color0 = vec4(texcolor.rgb, 1.0);
        color1 = vec4(lmcoord, blockID / 10000.0, pomShadow);
        color2 = vec4(normalEncode(normal), normalEncode(mappedNormal));
        color3 = vec4(specularData);
    }

#endif