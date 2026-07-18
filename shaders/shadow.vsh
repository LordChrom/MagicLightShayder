#version 430 compatibility
#include "lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;
flat out int emission;
flat out int blockId;
out vec3 toMidblock;
out vec3 worldPos;
out vec3 normal;

void main() {
    emission = int(at_midBlock.w);

    worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
    toMidblock = at_midBlock.xyz/64.0;
    blockId = int(mc_Entity.x);
    normal = gl_Normal;
//    writeVoxelMap(worldPos,blockId,toMidblock,gl_Normal,emission);
}