#version 430
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"


#define SIZE 16

const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;


layout (rgba16f) uniform writeonly restrict image2D colorimg6;


uniform sampler2D depthtex2;
uniform sampler2D colortex2;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"

vec4 swrtSampleSpecial(vec3 worldPos, vec3 normal, float subsurface, float ditherValue, uint maxSteps){
    worldPos+=0.02*normal;
    ivec3 unitShift = getUnitShift();
    ivec3 swrtPos = worldPosToSWRT(worldPos);

    if(swrtPos.x<0||swrtPos.y<0||swrtPos.z<0||
        swrtPos.x>=SWRT_SIZE||swrtPos.y>=SWRT_SIZE||swrtPos.z>=SWRT_SIZE
    ){
        return vec4(0);
    }

    uvec4 list= getLightList(swrtPos,unitShift);
    uint numLights = countLights(list);

//    numLights=min(numLights,4);
    ivec3 areaPos = swrtPos+offsetToVox;

    vec4 color = vec4(0);


    for(uint rayNum=0;rayNum<3;rayNum++){
        uint baseIndex = rayNum+(rayNum>>1); //0,1,3
        if(baseIndex>numLights)
            break;

        int numLightsToChooseFrom = 1<<rayNum;//1,2,4
        uint lightIndex = clamp(uint(ditherValue*numLightsToChooseFrom),0u,uint(numLightsToChooseFrom-1))+baseIndex;

        ivec3 sourceRel = uncheckedUnpackListedLight(getNthLight(list,lightIndex));
        vec4 traceColor = traceToLight(worldPos,areaPos,unitShift,sourceRel,ditherValue,maxSteps);

        traceColor.rgb*=traceColor.a*numLightsToChooseFrom/4.0;

        color.rgb+=traceColor.rgb;
        color.a++;
    }

    return color;
}

void main(){
    ivec2 pos = ivec2(gl_LocalInvocationID.xy+gl_WorkGroupID.xy*gl_WorkGroupSize.xy);
    vec2 texcoord = (pos+0.5)/imageSize(colorimg6);

    float solidDepth = texture(depthtex2,texcoord).x;
    vec4 normal = texture(colortex2,texcoord);
    vec4 worldPosRelative = vec4(texcoord,solidDepth,1);


    worldPosRelative.xyz=worldPosRelative.xyz*2-1;
    worldPosRelative = gbufferProjectionInverse*worldPosRelative;
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;

    float ditherValue = bayer128(pos);

    #ifdef SWRT_NOISY_PENUMBRAS
    ditherValue = temporalNoise(ditherValue);
    #endif

    vec4 light = swrtSampleSpecial(worldPosRelative.xyz+cameraPosition, normalize(normal.xyz*2-1), 0f, ditherValue,15u);

    imageStore(colorimg6,pos,light);
}