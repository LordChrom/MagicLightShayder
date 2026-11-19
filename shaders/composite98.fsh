#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"
uniform vec2 scaledScreenDim;
#include "/lib/util/taaJitter.glsl"

const uint maxSteps = SWRT_SIZE;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"
in vec3 worldDirNormalizeMe;



/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outColor;


//this could probably be a debugSpecialView but i cant be bothered rn
void main(){
    uint translucency;
    vec4 h;
    vec3 dir = normalize(worldDirNormalizeMe);
    dir/=max(max(abs(dir.x),abs(dir.y)),abs(dir.z));
    dir*=VOXELSIZE_HALF;
    float depth = traceRay(cameraPosition,dir,maxSteps,translucency,h);

    outColor = vec3(log2(depth)*0.1);
    if(depth<0)
        outColor=vec3(0.1,0,0);

    #if SWRT_TRANSLUCENCY>0
    for(int i=0;(i<SWRT_TRANSLUCENCY)&&bool(translucency);i++){
        outColor.rgb*= getLightIDColor(translucency&0x3fu);
        translucency>>=6;
    }
    #endif
}