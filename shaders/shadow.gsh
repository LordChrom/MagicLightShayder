#version 430 compatibility
#include "lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;


flat in int[3] emission;
flat in int[3] blockId;
in vec3[3] toMidblock;
in vec3[3] worldPos;
in vec3[3] normal;

layout(triangles) in;
layout (triangle_strip, max_vertices = 0) out;

void main() {
    if((frameCounter&0x7)!=0)
    return;
    vec3 centerPos = (worldPos[0]+worldPos[1]+worldPos[2])/3;
    vec3 centerToMidblloock = (toMidblock[0]+toMidblock[1]+toMidblock[2])/3;
    writeVoxelMap(centerPos,blockId[0],centerToMidblloock,normal[0],emission[0]);
}