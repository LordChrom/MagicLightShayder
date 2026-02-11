#version 430 compatibility
#include "lib/voxel/voxelMapper.glsl"
uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;

in vec4 at_midBlock;

//out vec2 texcoord;
//out vec4 glcolor;

void main() {
    int emission = int(at_midBlock.w);
//    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
//    gl_Position = gl_ProjectionMatrix * vec4(viewPos,1.0);
//    vec3 worldPos = (shadowModelViewInverse * vec4(viewPos,1.0)).xyz+cameraPosition;

    int metadata = (emission<<4) + 0xa+1;
    vec3 worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
    worldPos+= at_midBlock.xyz/64.0;
    writeVoxelMap(worldPos,uvec4(100,0,100,metadata));

//    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
//    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
//    glcolor = gl_Color;
}