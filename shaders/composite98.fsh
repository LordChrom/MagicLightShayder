#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"
uniform vec2 scaledScreenDim;
#include "/lib/util/taaJitter.glsl"

uniform vec3 cameraPosition;

const uint swrtMaxSteps = SWRT_SIZE;
#define SWRT_INCLUDE_TRACE
#include "/lib/lighting/swrt/swrtSampler.glsl"
in vec3 worldDirNormalizeMe;



/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outColor;


//this could probably be a debugSpecialView but i cant be bothered rn
void main(){
    vec3 dir = normalize(worldDirNormalizeMe);
    dir/=max(max(abs(dir.x),abs(dir.y)),abs(dir.z));
    dir*=VOXELSIZE_HALF;
    float depth = traceRay(cameraPosition,dir);



    if(depth<0)
        outColor=vec3(0.1,0.1,0.8);
    else{
        ivec3 areaPos = ivec3(floor(swrt_hitpos.xyz));
        outColor = vec3((log2(depth)+0.7f)*0.7/log2(SWRT_SIZE));

        #ifdef SWRT_TEXTURED
        vec4 texResult = swrtTextureSample();
        if(texResult.a<0.875){
            outColor.r=1;
        }else{
            outColor = texResult.rgb;
        }
        #endif


    }

    #if SWRT_TRANSLUCENCY>0
    outColor.rgb*=unpackSwrtTranslucency();
    #endif
}