#define READS_CHANGE_VOX
#define WRITES_CHANGE_VOX
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/vsAccess.glsl"

#ifndef CHANGE_TRACKING
const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
void main(){}
#else
const ivec3 workGroups = ivec3(VOXELSIZE_SIXTNTH,1,VOXELSIZE_SIXTNTH);
layout (local_size_x = 1, local_size_y = VOXELSIZE_SIXTNTH, local_size_z = 1) in;



void main(){

    ivec3 pos = ivec3(gl_WorkGroupID.x,gl_LocalInvocationID.y,gl_WorkGroupID.z);
    uint time = getChangeTime(pos);
    time = min(time+1,0xffu);
    setChangeTime(time,pos);
}
#endif