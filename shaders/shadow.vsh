#version 430 compatibility
#include "lib/settings.glsl"
#include "lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;


#ifdef SHADOWMAP_SHADOWS
#include "/lib/shadowmap/distortion.glsl"

out vec2 texcoordVert;
out vec4 glcolorVert;
#endif

void main() {
    if((gl_VertexID%3)==0){
        vec3 centerPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
        writeVoxelMap(centerPos, int(mc_Entity.x), at_midBlock.xyz/64.0, gl_Normal, int(at_midBlock.w));
    }
    #ifdef SHADOWMAP_SHADOWS
    texcoordVert = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolorVert = gl_Color;
    gl_Position = ftransform();
    #ifdef CASCADED_SHADOWS
    gl_Position.z = distortZ(gl_Position.z);
    #else
    gl_Position.xyz = distort(gl_Position.xyz);
    #endif

    #endif
}