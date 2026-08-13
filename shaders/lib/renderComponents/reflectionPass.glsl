uniform mat4 gbufferModelView, gbufferProjection;
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
        if(distFromEdge<ditherValue*0.05){
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
    screenPos.xy=texcoord;

    vec4 normal = texture(colortex2,texcoord);
    outputColor = texture(colortex0,texcoord,0).rgb;

    screenPos.z = texture(depthtex0,texcoord).x;
    vec3 worldDir = normalize(worldDirNormalizeMe);

    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    vec3 reflectionMult = vec3(1);


    if(abs(normal.a-0.5)<0.1)
        return;
    normal.xyz=normalize(normal.xyz*2-1);

    vec3 viewDir;

    #if REFLECTION_BOUNCES>1
    bool continuing = false;
    for(int i=0;i<REFLECTION_BOUNCES;i++)
    #endif
    {
        #if REFLECTION_BOUNCES>1
        if(!continuing)
        #endif
        {

            float transAlpha = texture(colortex3,screenPos.xy).a;
            uint reflectance = texture(colortex8,screenPos.xy).g;
            vec3 albedo = texture(colortex1,screenPos.xy).rgb;

            worldDir = vectorReflect(worldDir, normal.xyz);
            viewDir=worldDirToScreen(worldDir, screenPos);

            #ifndef PERFECT_MIRRORS
            if(transAlpha==1){
                return;
            }else if(transAlpha>0.05){
                reflectionMult*=1-dot(worldDir,normal.xyz);
            }else if(reflectance<=229){
                reflectionMult*=(reflectance/255.0);
            }else{
                //TODO hardcoded metals
                reflectionMult*=albedo;
            }

            if(reflectionMult.r+reflectionMult.g+reflectionMult.b<REFLECTION_THRESHOLD)
                return;
            #endif
        }

        uint rayHitReason;

        screenPos = doMarch(screenPos,viewDir,ditherValue,rayHitReason);

        #if REFLECTION_BOUNCES>1
        continuing=rayHitReason==2;
        #endif
        if(rayHitReason==1)
            return;
        if(rayHitReason==0){
            normal = texture(colortex2,screenPos.xy);
            normal.xyz=normalize(normal.xyz*2-1);

            if(abs(normal.a-0.5)<0.1)
                return;

            if(dot(worldDir,normal.xyz)<0)
                outputColor+= texture(colortex0,screenPos.xy).rgb*reflectionMult;
        }
    }
}