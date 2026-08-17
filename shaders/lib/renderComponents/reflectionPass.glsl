#version 430 compatibility
uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform int frameCounter;
#define SIZE 16
#include "/lib/settings.glsl"
#include "/lib/util/conversions.glsl"
#define TEMPORAL_DITHER

#include "/lib/util/dither.glsl"
#include "/lib/util/blend.glsl"


//in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform usampler2D colortex8;


const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba16f) uniform writeonly restrict image2D colorimg7;

vec3 vectorReflect(vec3 dir, vec3 norm){
    return normalize(dir-norm*(2*dot(norm,dir)));
}

vec3 worldDirToScreen(vec3 worldDirection, vec3 screenPos){
    vec4 pos = mat3x4(gbufferProjection)*(mat3(gbufferModelView)*worldDirection);

    return normalize(pos.xyz-pos.w*(2*screenPos-1));
}

vec3 doMarch(vec3 initialPos, vec3 viewDir, float ditherValue, out uint hitReason){
    hitReason=2;
    viewDir*=1/(REFLECTION_QUALITY*length(viewDir.xy));
    #if REFLECTION_BOUNCES>1
    viewDir*=min(2,1+0.3*REFLECTION_BOUNCES);
    #endif
    vec3 newPos;
    float texDepth;

    const int stepsPerBounce=REFLECTION_QUALITY/REFLECTION_BOUNCES;
    for(int i=0;i<stepsPerBounce;i++){
        newPos = initialPos+(i+ditherValue)*viewDir;
        float distFromEdge =min(min(newPos.x,newPos.y),1-max(newPos.x,newPos.y));
        if(distFromEdge<ditherValue*0.05 || newPos.z<=0.4 || newPos.z>=1){
            hitReason=1;
            break;
        }

        //TODO check both depthtexes, for reflections of terrain visible thru glass
        texDepth = texture(depthtex2,newPos.xy).x;
        if(texDepth<=newPos.z){
            hitReason=0;
            break;
        }
    }

    const float depthLeniency = 4.0/REFLECTION_QUALITY;

    if(hitReason==0){
        texDepth=depthToLinear(texDepth);
        float targetDepth = depthToLinear(newPos.z);
        float depthDif = (texDepth-targetDepth);
        depthDif*=depthDif/targetDepth;
        if(depthDif>depthLeniency){
            hitReason=1;
        }
    }

    return newPos;
}



#define REFLECTION_THRESHOLD 0.05*3

void main() {
    vec3 screenPos;
    ivec2 texpos = ivec2(gl_LocalInvocationID.xy+gl_WorkGroupID.xy*SIZE);
    screenPos.xy=(texpos+0.5)/textureSize(colortex7,0);
    if(screenPos.x>1 || screenPos.y>1)
        return;

    vec4 normal = texture(colortex2,screenPos.xy);
    vec3 outputColor = vec3(0);
    vec3 worldDir = normalize(gbufferModelViewInverse[3].xyz+mat3(gbufferModelViewInverse)*(
    gbufferProjectionInverse[3].xyz+(mat2x3(gbufferProjectionInverse)*(screenPos.xy*2-1))
    ));
    screenPos.z = texture(depthtex0,screenPos.xy).x;


    float ditherValue = dither(texpos);
    #ifdef DENOISE_REFLECTIONS
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
                if(!dirty) return;
                break;
            }else if(transColor.a>0.05){
                reflectionMult*=1-dot(worldDir,normal.xyz);
            }else if(reflectance<=229){
                reflectionMult*=(reflectance/255.0);
            }else{
                //TODO hardcoded metals
                reflectionMult*=albedo*0.9;
            }

            if(reflectionMult.r+reflectionMult.g+reflectionMult.b<REFLECTION_THRESHOLD){
                if(!dirty) return;
                break;
            }
            #endif
        }

        uint rayHitReason;

        screenPos = doMarch(screenPos,worldDirToScreen(worldDir, screenPos),ditherValue,rayHitReason);

        #if REFLECTION_BOUNCES>1
        continuing=rayHitReason==2;
        if(continuing)
            continue;
        #endif

        if(rayHitReason==1){
            if(!dirty) return;
            break;
        }
        if(rayHitReason==0){
            normal = texture(colortex2,screenPos.xy);
            vec3 lightColor = texture(colortex6,screenPos.xy).rgb;
            albedo = texture(colortex1, screenPos.xy).rgb;
            transColor = texture(colortex3,screenPos.xy);
            reflectance = texture(colortex8,screenPos.xy).g;

            if(abs(normal.a-0.5)<0.1){
                if(!dirty) return;
                break;
            }
            normal.xyz=normalize(normal.xyz*2-1);

            if(dot(worldDir,normal.xyz)<0){
                dirty=true;
                outputColor.rgb+= blend(vec4(lightColor*albedo,1),transColor)*reflectionMult;
            }
        }
    }




    vec4 fogColor = texelFetch(colortex7,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupID.xy*SIZE),0);
    fogColor.rgb+=outputColor;

    if(isnan(fogColor.x)||isnan(fogColor.y)||isnan(fogColor.z)||isnan(fogColor.a))
    return;

    imageStore(colorimg7,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupID.xy*SIZE),fogColor);
}