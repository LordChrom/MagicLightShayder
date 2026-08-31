#version 430 compatibility
uniform mat4 gbufferModelView, gbufferProjection;
#include "/lib/settings.glsl"

#if (defined TAA) || (defined DENOISE_REFLECTIONS)
#define REFLECTIONS_TEMPORAL_NOISE
#endif

#ifdef REFLECTIONS_TEMPORAL_NOISE
uniform int frameCounter;
#define TEMPORAL_DITHER
#endif

#include "/lib/util/dither.glsl"
#include "/lib/util/blend.glsl"
#include "/lib/util/conversions.glsl"
#include "/lib/util/raycast.glsl"


in vec2 texcoord;
in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform usampler2D colortex8;


/* RENDERTARGETS: 7 */
layout (location=0) out vec4 fogColorOut;

vec3 vectorReflect(vec3 dir, vec3 norm){
    return normalize(dir-norm*(2*dot(norm,dir)));
}

vec3 worldDirToScreen(vec3 worldDirection, vec3 screenPos){
    vec4 pos = mat3x4(gbufferProjection)*(mat3(gbufferModelView)*worldDirection);

    return normalize(pos.xyz-pos.w*(2*screenPos-1));
}




#define REFLECTION_THRESHOLD 0.05*3

void main() {

    fogColorOut = texelFetch(colortex7,ivec2(gl_FragCoord.xy),0);

    vec4 normal = texture(colortex2,texcoord);
    vec3 worldDir = normalize(worldDirNormalizeMe);
    vec3 screenPos;
    screenPos.z = texture(depthtex0,texcoord).x;
    screenPos.xy=texcoord;


    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    #ifdef REFLECTIONS_TEMPORAL_NOISE
    ditherValue = temporalNoise(ditherValue);
    #endif

    ditherValue = 0.9*ditherValue+0.05;
    vec3 reflectionMult = vec3(1);


    if(abs(normal.a-0.5)<0.1)
        return;
    normal.xyz=normalize(normal.xyz*2-1);

    bool dirty = false;

    vec3 albedo = texture(colortex1,screenPos.xy).rgb;
    vec4 transColor = texture(colortex3,screenPos.xy);
    uint reflectance = texture(colortex8,screenPos.xy).g;

    #if REFLECTION_BOUNCES>1
    bool continuing = false;
    #endif

    for(int i=0;i<REFLECTION_BOUNCES;i++)
    {
        #if REFLECTION_BOUNCES>1
        if(!continuing)
        #endif
        {
            worldDir = vectorReflect(worldDir, normal.xyz);
            #ifndef PERFECT_MIRRORS
            if(transColor.a==1){
                return;
            }else if(transColor.a>0.05){
                reflectionMult*=1-dot(worldDir,normal.xyz);
            }else if(reflectance<=229){
                reflectionMult*=(reflectance/255.0);
            }else{
                //TODO hardcoded metals
                reflectionMult*=albedo*0.9;
            }

            if(reflectionMult.r+reflectionMult.g+reflectionMult.b<REFLECTION_THRESHOLD){
                return;
            }
            #endif
        }

        uint rayHitReason;
        const int stepsPerBounce=REFLECTION_QUALITY/REFLECTION_BOUNCES;
        #if REFLECTION_BOUNCES>1
        const float maxCastLen=min(2,1+0.3*REFLECTION_BOUNCES);
        #else
        const float maxCastLen = 1.0;
        #endif
        screenPos = screenspaceRaycast(
            depthtex2,stepsPerBounce,maxCastLen,
            screenPos,worldDirToScreen(worldDir, screenPos),ditherValue,
            rayHitReason
        );

        #if REFLECTION_BOUNCES>1
        continuing=rayHitReason==0;
        if(continuing)
            continue;
        #endif

        if(rayHitReason<4){
            return;
        }

        normal = texture(colortex2,screenPos.xy);
        vec3 lightColor = texture(colortex6,screenPos.xy).rgb;
        albedo = texture(colortex1, screenPos.xy).rgb;
        transColor = texture(colortex3,screenPos.xy);
        reflectance = texture(colortex8,screenPos.xy).g;

        if(abs(normal.a-0.5)<0.1){
            return;
        }
        normal.xyz=normalize(normal.xyz*2-1);

        if(dot(worldDir,normal.xyz)<0){
            fogColorOut.rgb+= blend(vec4(lightColor*albedo,1),transColor)*reflectionMult;
        }
    }
}