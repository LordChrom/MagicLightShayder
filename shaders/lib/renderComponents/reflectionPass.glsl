uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform int frameCounter;
#include "/lib/util/conversions.glsl"
#include "/lib/util/dither.glsl"


in vec2 texcoord;
in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex2;
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform usampler2D colortex3;
uniform sampler2D colortex4;

#include "/lib/util/reflect.glsl"


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;



void main() {
    vec3 screenPos;
    screenPos.xy=texcoord;
    screenPos.z = texture(depthtex2,texcoord).x;
    vec3 worldDir = normalize(worldDirNormalizeMe);

    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    outputColor = texture(colortex0,texcoord,0).rgb;
    vec3 reflectionMult = vec3(1);

    bool continuing = false;
    #if REFLECTION_BOUNCES!=1
    for(int i=0;i<REFLECTION_BOUNCES;i++)
    #endif
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
        if(viewDir.z<=0)
            return;

        uint rayHitReason;
        screenPos = doMarch(screenPos,viewDir,ditherValue,rayHitReason);
        continuing=rayHitReason==2;
        if(rayHitReason==1)
            return;
        if(rayHitReason==0){
            outputColor+= texture(colortex0,screenPos.xy).rgb*reflectionMult;
        }
    }
}