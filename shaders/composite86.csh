#version 430 compatibility
#extension GL_KHR_shader_subgroup_arithmetic : enable

#include "/lib/settings.glsl"


#define SIZE 32
const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba32I) uniform writeonly restrict iimage2D dofImg;


uniform sampler2D colortex0;
uniform sampler2D colortex12;

vec3 color;
ivec2 samplePos;
float radius;



void main(){
    uvec2 groupPos = uvec2(gl_SubgroupInvocationID+gl_SubgroupID*gl_SubgroupSize,0);
    groupPos=uvec2(groupPos.x%SIZE,groupPos.x/SIZE);

    ivec2 samplePos = ivec2(gl_WorkGroupID.xy*gl_WorkGroupSize.xy-DOF_RADIUS);
    ivec2 texSize = textureSize(colortex0,0);
    if(samplePos.x>=texSize.x+DOF_RADIUS || samplePos.y>=texSize.y+DOF_RADIUS)
        return;

    samplePos+=ivec2(groupPos);

    ivec3 value = ivec3(0);

    for(int i = -DOF_RADIUS;i<=DOF_RADIUS;i++){
        if(i==0) continue;
        ivec2 pos = samplePos+i;
        if(pos.x<0 || pos.y<0 || pos.x>=texSize.x || pos.y>=texSize.y)
            continue;
        float radius=texelFetch(colortex12,pos,0).y;
        radius = max(radius,0.5);

        if(abs(radius-abs(i))<0.5){
            vec3 color = texelFetch(colortex0,pos,0).rgb;

            color/=4*radius*radius;
            value+=ivec3(color*DOF_STORAGE_SCALE);
        }
    }

    for(int i = -DOF_RADIUS;i<=DOF_RADIUS;i++){
        if(i==0) continue;
        ivec2 pos = samplePos+ivec2(i,-i);
        if(pos.x<0 || pos.y<0 || pos.x>=texSize.x || pos.y>=texSize.y)
            continue;
        float radius=texelFetch(colortex12,pos,0).y;
        radius = max(radius,0.5);

        if(abs(radius-abs(i))<0.5){
            vec3 color = texelFetch(colortex0,pos,0).rgb;

            color/=4*radius*radius;
            value-=ivec3(color*DOF_STORAGE_SCALE);
        }
    }

    value = subgroupInclusiveAdd(value);

    if(gl_SubgroupSize>SIZE){
        ivec3 extraValue = (gl_SubgroupInvocationID%SIZE)==(SIZE-1)?value:ivec3(0);
        value-=subgroupExclusiveAdd(extraValue);
    }

    imageStore(dofImg,ivec2(groupPos.xy+gl_WorkGroupID.xy*gl_WorkGroupSize.xy),ivec4(value,0));
}