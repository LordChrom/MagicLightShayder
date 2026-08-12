uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform float near,far;
uniform int frameCounter;
#include "/lib/util/conversions.glsl"
#include "/lib/util/dither.glsl"


in vec2 texcoord;
in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex2;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform usampler2D colortex3;

float noise;

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
    float dif = 0.01;
    vec3 worldPos = screenPosToWorld(screenPos);
    vec3 viewPosDif = worldPosToScreen(worldPos+dif*worldNormal)-screenPos;
    return normalize(viewPosDif);
}

vec3 debugChecker(vec3 value){
    ivec2 awa = ivec2(gl_FragCoord.xy)>>3;
    vec3 checker = sign(value);
    if(bool(1&(awa.x^awa.y)))
        checker=vec3(1);
    return vec3(abs(value)*vec3(checker.x>=0,checker.y>=0,checker.z>=0));
}

const int stepsPerBounce=REFLECTION_QUALITY/REFLECTION_BOUNCES;

vec3 doMarch(vec3 initialPos, vec3 viewDir, out uint hitReason){
    vec2 differential = viewDir.xy/viewDir.z;
    vec2 remainingScreen = vec2(differential.x>0?1-initialPos.x:initialPos.x,differential.y>0?1-initialPos.y:initialPos.y);
    float stepSize=min(remainingScreen.x/abs(differential.x),remainingScreen.y/abs(differential.y))/REFLECTION_QUALITY;
    #if REFLECTION_BOUNCES>1
    stepSize*=min(2,1+0.3*REFLECTION_BOUNCES);
    #endif
    bool seenAir = false;
    for(int i=0;i<=stepsPerBounce;i++){
        float depthDist = stepSize*(i+noise)+0.001;
        vec3 newPos = initialPos+vec3(depthDist*differential,depthDist);
        float distFromEdge =min(min(newPos.x,newPos.y),1-max(newPos.x,newPos.y));
        if(distFromEdge<noise*0.1){
            hitReason=1;
            return newPos;
        }
        float texDepth = texture(depthtex2,newPos.xy).x;
        if(texDepth<=newPos.z){
            hitReason=0;
            float linearTargetDepth = depthToLinear(newPos.z);
            float depthDif = (linearTargetDepth-depthToLinear(texDepth))/linearTargetDepth;
            if(depthDif>0.1)
                hitReason=1;
            if(seenAir){
                return newPos;
            }
        }else{
            seenAir=true;
        }
    }

    hitReason=2;
    return initialPos+stepSize*stepsPerBounce*vec3(differential,1);
}

#define REFLECTION_THRESHOLD 0.05
void main() {
    vec3 screenPos;
    screenPos.xy=texcoord;
    screenPos.z = texture(depthtex2,texcoord).x;
    vec3 worldDir = normalize(worldDirNormalizeMe);

    noise = dither(ivec2(gl_FragCoord.xy));
    outputColor = texture(colortex0,texcoord,0).rgb;
    vec3 reflectionMult = vec3(1);

    bool continuing = false;
    for(int i=0;i<REFLECTION_BOUNCES;i++)
    {
        uint reflectance = texture(colortex3,screenPos.xy).g;
        vec3 albedo = texture(colortex4,screenPos.xy).rgb;
        vec3 normal = normalize(texture(colortex2,screenPos.xy).rgb*2-1);
        #ifndef PERFECT_MIRRORS
        if(reflectance<=229){
            reflectionMult*=(reflectance/255.0);
        }else{
            //TODO hardcoded metals
            reflectionMult*=albedo;
        }
        #endif
        if(reflectionMult.r+reflectionMult.g+reflectionMult.b<REFLECTION_THRESHOLD)
            return;

        if(!continuing)
        worldDir = reflect(worldDir,normal);
        vec3 viewDir=worldDirToScreen(worldDir,screenPos);
        if(viewDir.z<0)
            return;

        uint rayHitReason;
        screenPos = doMarch(screenPos,viewDir,rayHitReason);
        continuing=rayHitReason==2;
        if(rayHitReason==1)
            return;
        if(rayHitReason==0){
            outputColor+= texture(colortex0,screenPos.xy).rgb*reflectionMult;
        }
    }
}