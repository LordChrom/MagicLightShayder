#version 430 compatibility

const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

#define SETUP_PASS
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

void main(){
    setupLightID(gl_LocalInvocationID.x);
}