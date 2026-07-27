#version 430 compatibility
#include "lib/settings.glsl"
#include "lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;


#ifdef SHADOWMAP_SHADOWS
#include "/lib/shadowmap/distortion.glsl"

out vec2 texcoord;
out vec4 glcolor;
#endif

void main() {
    if((gl_VertexID%3)==0){
        vec3 centerPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
        writeVoxelMap(centerPos, int(mc_Entity.x), at_midBlock.xyz/64.0, gl_Normal, int(at_midBlock.w));
    }
    #ifdef SHADOWMAP_SHADOWS
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    gl_Position = ftransform();
    gl_Position.xy = distort(gl_Position.xy);

    #endif
}