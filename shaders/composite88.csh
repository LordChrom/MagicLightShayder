#version 430 compatibility
#extension GL_KHR_shader_subgroup_clustered : enable

#include "/lib/settings.glsl"


#define SIZE 32
const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

uniform isampler2D dofSampler2;
layout (rgba8) uniform writeonly restrict image2D colorimg0;


void main(){
    uvec2 groupPos = uvec2(gl_SubgroupInvocationID+gl_SubgroupID*gl_SubgroupSize,0);
    groupPos=uvec2(groupPos.x/SIZE,groupPos.x%SIZE); //aligned vertically

    int samplePosX = int(groupPos.x+gl_WorkGroupSize.x*gl_WorkGroupID.x);
    ivec3 bottomEdge = ivec3(0);

    for(uint y=groupPos.y;y<gl_WorkGroupID.y;y+=gl_WorkGroupSize.y){
        bottomEdge+=texelFetch(dofSampler2,ivec2(samplePosX,int((y+1)*gl_WorkGroupSize.y-1)),0).rgb;
    }
    bottomEdge = subgroupClusteredAdd(bottomEdge, 32);
    ivec3 value = texelFetch(dofSampler2,ivec2(groupPos+gl_WorkGroupID.xy*gl_WorkGroupSize.xy),0).rgb+bottomEdge;

    imageStore(colorimg0,ivec2(groupPos+gl_WorkGroupID.xy*gl_WorkGroupSize.xy),vec4(vec3(value)/DOF_STORAGE_SCALE,0));
}