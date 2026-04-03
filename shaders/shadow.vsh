#version 430 compatibility
#include "lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;

void main() {
    int emission = int(at_midBlock.w);

    vec3 worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
    vec3 toMidblock = at_midBlock.xyz/64.0;
    int blockId = int(mc_Entity.x);
    writeVoxelMap(worldPos,blockId,toMidblock,gl_Normal,emission);
}