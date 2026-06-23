

#include "/lib/basefiles.glsl"

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec3 normal;
varying vec4 glcolor;
varying float blockID;
varying vec4 view_pos;
varying vec4 clip_pos;
varying mat3 tbnMatrix;
varying vec3 lightcol;
varying vec3 upskylight;

#ifdef VSH

    #if MC_VERSION >= 11500
    layout(location = 11) in vec4 mc_Entity;
    #else
    layout(location = 10) in vec4 mc_Entity;
    #endif

    in vec4 at_tangent;

    void main() {
        vec3 model_pos = gl_Vertex.xyz;
        view_pos = gl_ModelViewMatrix * vec4(model_pos, 1.0);
        clip_pos = gl_ProjectionMatrix * view_pos;
        #ifdef TAA
	        clip_pos.xy += taaJitter * TAA_Intensity * clip_pos.w;
        #endif
        gl_Position = clip_pos;

        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
        lmcoord = clamp(lmcoord, 0.5 / 16.0, 15.5 / 16.0);
        normal = gl_NormalMatrix * gl_Normal;
        normal = normalize(mat3(gbufferModelViewInverse) * normal);
        glcolor = gl_Color;
        blockID = mc_Entity.x;

        vec3 tangent = gl_NormalMatrix * normalize(at_tangent.xyz);
        tangent = normalize(mat3(gbufferModelViewInverse) * tangent);
        tbnMatrix = mat3(tangent, normalize(cross(tangent, normal) * at_tangent.w), normal);

        lightcol = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(2, 0), 0).rgb;
        upskylight = texelFetch(colortex5, ivec2(viewSize - 1.0) - ivec2(6, 0), 0).rgb;
    }

#endif

#ifdef FSH

    #include "/lib/water.glsl"

    /* RENDERTARGETS: 0 */
    layout(location = 0) out vec4 color0;

    void main() {
        vec4 texcolor = texture(gtexture, texcoord);
        if(texcolor.a < alphaTestRef) {
            discard;
        }
        texcolor.rgb *= glcolor.rgb;
        texcolor.rgb = GammaToLinear(texcolor.rgb);

        vec3 screenPos = (clip_pos.xyz / clip_pos.w) * 0.5 + 0.5;
        vec3 outcol = vec3(0.0);
        if(abs(blockID - 8.0) < 0.5 || abs(blockID - 9.0) < 0.5) {
            vec3 viewPos = view_pos.xyz;
            vec3 worldPos = matrixMultiply(gbufferModelViewInverse, vec4(viewPos, 1.0));
            vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos);
            vec3 mcPos = worldPos + cameraPosition;

            float currHeight;
            vec2 waterUV = waveParallaxMapping(mcPos.xz, transpose(tbnMatrix) * worldDir, currHeight);
            vec3 waterNormal = getWaterNormal(mcPos.xz);
            vec3 worldNormal = tbnMatrix * waterNormal;
            vec3 worldOriNormal = normal;

            vec2 distortCoord = screenPos.xy + waterNormal.xy * 0.05;
            outcol = texture(colortex4, distortCoord).rgb;

            float viewdepth = abs(
                linearDepth(texture(depthtex1, screenPos.xy).r) * float(isEyeInWater == 0) - 
                linearDepth(screenPos.z)
            );
            vec3 skylight = upskylight;
            outcol = waterScatter(outcol, worldDir, viewdepth, lightcol, skylight);

            vec3 worldReflectDir = reflect(worldDir, worldNormal);
            if(dot(worldReflectDir, worldOriNormal) < 0.0) {
                worldReflectDir = reflect(worldReflectDir, worldOriNormal);
            }
            vec3 rayTracingCol = sampleSkybox(worldReflectDir);
            vec3 trans = TransToAtmos(cameraLocation, worldReflectDir);
            rayTracingCol = drawSun(rayTracingCol, worldReflectDir, trans);
            #ifdef REFLECTED_CLOUD
                vec4 cloud2D = RenderCloud2D(cameraLocation, worldReflectDir, lightDir, lightLuminance);
                rayTracingCol = rayTracingCol * cloud2D.a + cloud2D.rgb;
                vec4 cloud3D = RenderCloud(cameraLocation, worldReflectDir, lightDir, lightLuminance, skylight);
                rayTracingCol = rayTracingCol * cloud3D.a + cloud3D.rgb;
            #endif
            rayTracingCol *= lmcoord.y;

            vec2 rayTracingPos = vec2(0.0);
            bool rayTracingIsHit = false;
            vec3 viewReflectDir = normalize(mat3(gbufferModelView) * worldReflectDir);
            screenRayTracingDDA(viewPos, viewReflectDir, rayTracingPos, rayTracingIsHit);
            if(rayTracingIsHit) {
                vec2 prevUV = getPreCoord(rayTracingPos.xy);
                rayTracingCol = texture(colortex7, outScreen(prevUV) ? rayTracingPos.xy : prevUV).rgb;
            }

            float fresnel = fresnelSchlick(max0(dot(worldNormal, -worldDir)), 0.02);
            outcol = mix(outcol, rayTracingCol, fresnel);
        } else if(abs(blockID - 79.0) < 0.5) {
            vec3 viewPos = view_pos.xyz;
            vec3 worldPos = matrixMultiply(gbufferModelViewInverse, vec4(viewPos, 1.0));
            vec3 worldDir = normalize(mat3(gbufferModelViewInverse) * viewPos);
            vec3 worldNormal = normal;

            outcol = vec3(0.02, 0.025, 0.03) * lightcol * lmcoord.y;

            vec3 worldReflectDir = reflect(worldDir, worldNormal);
            if(dot(worldReflectDir, worldNormal) < 0.0) {
                worldReflectDir = reflect(worldReflectDir, worldNormal);
            }

            vec2 rayTracingPos = vec2(0.0);
            bool rayTracingIsHit = false;
            vec3 viewReflectDir = normalize(mat3(gbufferModelView) * worldReflectDir);
            screenRayTracingDDA(viewPos, viewReflectDir, rayTracingPos, rayTracingIsHit);

            if(rayTracingIsHit) {
                float hitBlockID = texture(colortex1, rayTracingPos).b * 10000.0;
                if(abs(hitBlockID - 9999.0) < 0.5) rayTracingIsHit = false;
            }

            vec3 rayTracingCol;
            if(rayTracingIsHit) {
                vec2 prevUV = getPreCoord(rayTracingPos.xy);
                rayTracingCol = texture(colortex7, outScreen(prevUV) ? rayTracingPos.xy : prevUV).rgb;
            } else {
                rayTracingCol = sampleSkybox(worldReflectDir);
                vec3 trans = TransToAtmos(cameraLocation, worldReflectDir);
                rayTracingCol = drawSun(rayTracingCol, worldReflectDir, trans);
                #ifdef REFLECTED_CLOUD
                    vec4 cloud3D = RenderCloud(cameraLocation, worldReflectDir, lightDir, lightLuminance, upskylight);
                    rayTracingCol = rayTracingCol * cloud3D.a + cloud3D.rgb;
                #endif
                rayTracingCol *= lmcoord.y;
            }

            float fresnel = fresnelSchlick(max0(dot(worldNormal, -worldDir)), 0.04);
            outcol = mix(outcol, rayTracingCol, max(fresnel, 0.97));
        } else {
            outcol = texture(colortex4, screenPos.xy).rgb;
            outcol = mix(outcol, GammaToLinear(texcolor.rgb) * lightcol * 0.5, texcolor.a * 0.2);
        }

        color0 = vec4(outcol, 1.0);
    }

#endif