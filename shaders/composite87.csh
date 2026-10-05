#version 430 compatibility
#extension GL_KHR_shader_subgroup_clustered : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable

#include "/lib/settings.glsl"


#define SIZE 32
const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

uniform isampler2D dofSampler;
layout (rgba32I) uniform writeonly restrict iimage2D dofImg2;


shared int[SIZE][SIZE] thebufferrrR;
shared int[SIZE][SIZE] thebufferrrG;
shared int[SIZE][SIZE] thebufferrrB;

void main(){
    uvec2 groupPos = uvec2(gl_SubgroupInvocationID+gl_SubgroupID*gl_SubgroupSize,0);
    groupPos=uvec2(groupPos.x%SIZE,groupPos.x/SIZE);

    int samplePosY = int(groupPos.y+gl_WorkGroupSize.y*gl_WorkGroupID.y);
    ivec3 leftEdge = ivec3(0);

    for(uint x=groupPos.x;x<gl_WorkGroupID.x;x+=gl_WorkGroupSize.x){
        leftEdge+=texelFetch(dofSampler,ivec2(int((x+1)*gl_WorkGroupSize.x-1),samplePosY),0).rgb;
    }
    leftEdge = subgroupClusteredAdd(leftEdge, 32);
    ivec3 value = texelFetch(dofSampler,ivec2(groupPos+gl_WorkGroupID.xy*gl_WorkGroupSize.xy),0).rgb+leftEdge;
    thebufferrrR[groupPos.x][groupPos.y]=value.r;
    thebufferrrG[groupPos.x][groupPos.y]=value.g;
    thebufferrrB[groupPos.x][groupPos.y]=value.b;
    barrier();

    groupPos = groupPos.yx;

    value=ivec3(
        thebufferrrR[groupPos.x][groupPos.y],
        thebufferrrG[groupPos.x][groupPos.y],
        thebufferrrB[groupPos.x][groupPos.y]
    );

    value = subgroupInclusiveAdd(value);

    if(gl_SubgroupSize>SIZE){
        ivec3 extraValue = (gl_SubgroupInvocationID%SIZE)==(SIZE-1)?value:ivec3(0);
        value-=subgroupExclusiveAdd(extraValue);
    }

    imageStore(dofImg2,ivec2(groupPos+gl_WorkGroupID.xy*gl_WorkGroupSize.xy),ivec4(value,0));
}