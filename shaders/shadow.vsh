#version 430 compatibility
#include "lib/voxel/voxelMapper.glsl"
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;

in vec4 at_midBlock;

void main() {
    int emission = int(at_midBlock.w);

    vec3 worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
    worldPos+= at_midBlock.xyz/64.0;
    writeVoxelMap(worldPos,vec3(0.5,0,0.5),emission, false, emission==0);
}