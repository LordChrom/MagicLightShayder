uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform int frameCounter;
#include "/lib/util/conversions.glsl"
#include "/lib/util/dither.glsl"


in vec2 texcoord;
in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform usampler2D colortex8;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

vec3 reflect(vec3 dir, vec3 norm){
    return normalize(dir-norm*(2*dot(norm,dir)));
}

vec3 worldPosToScreen(vec3 worldPos){
    vec4 pos = vec4(mat3(gbufferModelView)*worldPos,1);
    pos=gbufferProjection*pos;
    return (pos.xyz*(0.5/pos.w))+0.5;
}

vec3 screenPosToWorld(vec3 screenPos){
    vec4 pos = vec4(screenPos*2-1,1);
    pos=gbufferProjectionInverse*pos;
    pos/=pos.w;
    return mat3(gbufferModelViewInverse)*pos.xyz;
}

//TODO gotta be a better way to do this
vec3 worldDirToScreen(vec3 worldNormal, vec3 screenPos){
    float dif = 0.1;
    vec3 worldPos = screenPosToWorld(screenPos);
    vec3 offsetScreenPos = worldPosToScreen(worldPos+dif*worldNormal);
    return normalize(offsetScreenPos-screenPos);
}

const int stepsPerBounce=REFLECTION_QUALITY/REFLECTION_BOUNCES;
#define REFLECTION_THRESHOLD 0.05

vec3 doMarch(vec3 initialPos, vec3 viewDir, float ditherValue, out uint hitReason){
    hitReason=2;
    viewDir*=1/(REFLECTION_QUALITY*length(viewDir.xy));
    #if REFLECTION_BOUNCES>1
    viewDir*=min(2,1+0.3*REFLECTION_BOUNCES);
    #endif
    vec3 newPos;
    float texDepth;

    for(int i=0;i<stepsPerBounce;i++){
        newPos = initialPos+(i+ditherValue)*viewDir;
        float distFromEdge =min(min(newPos.x,newPos.y),1-max(newPos.x,newPos.y));
        if(distFromEdge<ditherValue*0.0 || newPos.z>=0.9999){
            hitReason=1;
            break;
        }

        //TODO check both depthtexes, for reflections of terrain visible thru glass
        texDepth = texture(depthtex0,newPos.xy).x;
        if(texDepth<=newPos.z){
            hitReason=0;
            break;

        }
    }

    if(hitReason==0){
        texDepth=depthToLinear(texDepth);
        if(texDepth<0.5)
            hitReason=1;
    }

    return newPos;
}




void main() {
    vec3 screenPos;
    screenPos.xy=texcoord;
    screenPos.z = texture(depthtex0,texcoord).x;
    vec3 worldDir = normalize(worldDirNormalizeMe);

    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    outputColor = texture(colortex0,texcoord,0).rgb;
    vec3 reflectionMult = vec3(1);

    bool continuing = false;
    vec3 viewDir;
    #if REFLECTION_BOUNCES!=1
    for(int i=0;i<REFLECTION_BOUNCES;i++)
    #endif
    {
        if(!continuing){
            float transAlpha = texture(colortex3,screenPos.xy).a;
            uint reflectance = texture(colortex8,screenPos.xy).g;
            vec3 albedo = texture(colortex1,screenPos.xy).rgb;
            vec4 normal = texture(colortex2,screenPos.xy);
            #ifndef PERFECT_MIRRORS
            if(transAlpha>0.05){
                reflectance=229;
            }
            if(abs(normal.a-0.5)<0.1 || transAlpha==1)
                return;
            if(reflectance<=229){
                reflectionMult*=(reflectance/255.0);
            }else{
                //TODO hardcoded metals
                reflectionMult*=albedo;
            }
            #endif
            if(reflectionMult.r+reflectionMult.g+reflectionMult.b<REFLECTION_THRESHOLD)
                return;
            normal.xyz=normalize(normal.rgb*2-1);
            worldDir = reflect(worldDir, normal.xyz);
            viewDir=worldDirToScreen(worldDir, screenPos);
        }

        uint rayHitReason;

        screenPos = doMarch(screenPos,viewDir,ditherValue,rayHitReason);

        continuing=rayHitReason==2;
        if(rayHitReason==1)
            return;
        vec3 normal = normalize(texture(colortex2,screenPos.xy).xyz*2-1);

        if(rayHitReason==0 && dot(worldDir,normal)<0){
            outputColor+= texture(colortex0,screenPos.xy).rgb*reflectionMult;
        }
    }
}