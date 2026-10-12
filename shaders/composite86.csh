#version 430 compatibility
#extension GL_KHR_shader_subgroup_arithmetic : enable

#include "/lib/settings.glsl"


#define SIZE 32
const vec2 workGroupsRender = vec2(1.2,1.2);
layout (local_size_x = SIZE, local_size_y = 8, local_size_z = 1) in;

layout (rgba32I) uniform writeonly restrict iimage2D dofImg;


uniform sampler2D colortex0;

ivec2 texSize;

void samplePath(inout ivec3 value, ivec2 startPos, ivec2 delta){
    for(int i = 0;i<DOF_RADIUS;i++){
        vec4 colorAndRad = texelFetch(colortex0,startPos+i*delta,0);

        colorAndRad.a = clamp(colorAndRad.a*DOF_RADIUS,0.5,DOF_RADIUS-0.501);

        int radPx = int(floor(colorAndRad.a+0.5)); //radius (0.5,1.5] -> radpx==1 -> 3x3 square -> full weight on i=0; edge weight on i=1
        if(radPx==i || radPx==(i+1)){

            float centerWeight = 0.25/(colorAndRad.a*colorAndRad.a);

            float fullWeightArea = max(2*radPx-1,0);
                fullWeightArea*=fullWeightArea;

            float edgeWeight = (1.0-centerWeight*fullWeightArea)/max(8*radPx,1);
            centerWeight-=edgeWeight;

            value+=ivec3(colorAndRad.rgb*(DOF_STORAGE_SCALE*(radPx==i?edgeWeight:centerWeight)));
        }
    }
}

void main(){
    uvec2 groupPos = uvec2(gl_SubgroupInvocationID+gl_SubgroupID*gl_SubgroupSize,0);
    groupPos=uvec2(groupPos.x%SIZE,groupPos.x/SIZE);

    ivec2 samplePos = ivec2(gl_WorkGroupID.xy*gl_WorkGroupSize.xy-DOF_RADIUS);
    texSize = textureSize(colortex0,0);
    if(samplePos.x>=texSize.x+DOF_RADIUS || samplePos.y>=texSize.y+DOF_RADIUS)
        return;

    samplePos+=ivec2(groupPos);

    ivec3 value = ivec3(0);
    samplePath(value,samplePos+ivec2(0,-1),ivec2(1,-1));
    samplePath(value,samplePos+ivec2(-1,0),ivec2(-1,1));
    value=-value;
    samplePath(value,samplePos,ivec2(1));
    samplePath(value,samplePos-1,ivec2(-1));

    value = subgroupInclusiveAdd(value);

    if(gl_SubgroupSize>SIZE){
        ivec3 extraValue = (gl_SubgroupInvocationID%SIZE)==(SIZE-1)?value:ivec3(0);
        value-=subgroupExclusiveAdd(extraValue);
    }

    imageStore(dofImg,ivec2(groupPos.xy+gl_WorkGroupID.xy*gl_WorkGroupSize.xy),ivec4(value,0));
}