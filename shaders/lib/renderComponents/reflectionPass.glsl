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

//reasons
//0: no hits
//1: hit edge of screen
//2: hit something, but depth too different
//4: hit solid terrain
vec3 doMarch(vec3 initialPos, vec3 viewDir, float ditherValue, out uint hitReason){
    hitReason=0;
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
        if(distFromEdge<ditherValue*0.1 || newPos.z<=0.4 || newPos.z>=1){
            hitReason=1;
            break;
        }

        //TODO check both depthtexes, for reflections of terrain visible thru glass
        texDepth = texture(depthtex2,newPos.xy).x;
        if(texDepth<=newPos.z){
            hitReason=4;
            break;
        }
    }

    if(hitReason==4){
        viewDir*=0.5;
        newPos-=viewDir;

        for(int i=0;i<min(stepsPerBounce,8);i++){
            texDepth = texture(depthtex2,newPos.xy).x;
            viewDir*=0.5;
            newPos+=(texDepth>=newPos.z)?viewDir:-viewDir;
        }
    }

    if((hitReason==4) && (abs(depthToLinear(texDepth)/depthToLinear(newPos.z)-1)>0.1)){
        hitReason=2;
    }

    return newPos;
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

        screenPos = doMarch(screenPos,worldDirToScreen(worldDir, screenPos),ditherValue,rayHitReason);

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