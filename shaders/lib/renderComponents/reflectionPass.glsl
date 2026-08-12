uniform mat4 gbufferModelView, gbufferProjection;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform int frameCounter;
#include "/lib/util/conversions.glsl"
#include "/lib/util/dither.glsl"


in vec2 texcoord;
in vec3 worldDirNormalizeMe;

uniform sampler2D depthtex0;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform usampler2D colortex8;

#include "/lib/util/reflect.glsl"


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;



void main() {
    vec3 screenPos;
    screenPos.xy=texcoord;
    screenPos.z = texture(depthtex0,texcoord).x;
    vec3 worldDir = normalize(worldDirNormalizeMe);

    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    outputColor = texture(colortex0,texcoord,0).rgb;
    vec3 reflectionMult = vec3(1);

    bool continuing = false;
    #if REFLECTION_BOUNCES!=1
    for(int i=0;i<REFLECTION_BOUNCES;i++)
    #endif
    {
        float transAlpha = texture(colortex3,screenPos.xy).a;
        uint reflectance = texture(colortex8,screenPos.xy).g;
        vec3 albedo = texture(colortex1,screenPos.xy).rgb;
        vec4 normal = texture(colortex2,screenPos.xy);
        normal.xyz=normalize(normal.rgb*2-1);
        #ifndef PERFECT_MIRRORS
        if(transAlpha>0.05 && transAlpha<1){
            reflectance=229;
        }
        if(abs(normal.a-0.5)<0.1)
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

        float surfacedot = dot(worldDir,normal.xyz);
        if(!continuing)
            worldDir = reflect(worldDir, normal.xyz);
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