#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

#ifdef CAN_VOXELIZE
//#include "/lib/lighting/voxel/voxelMapper.glsl"
//uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;

out flat int blockID;
out flat int blockEmission;
out vec3 worldPosRel;
out vec3 normal;
#endif

#ifdef SHADOWMAP_SHADOWS
uniform int frameCounter;

#include "/lib/lighting/shadowmap/distortion.glsl"

#ifdef TEXTURED
out vec2 texcoordVert;
#endif

#ifdef COLORED
out vec4 glcolorVert;
#endif

#endif

void main() {
    #ifdef CAN_VOXELIZE
    worldPosRel = gl_Vertex.xyz;
    blockID = int(mc_Entity.x);
    blockEmission = int(at_midBlock.w);
    normal = gl_Normal;
    #endif

    #ifdef SHADOWMAP_SHADOWS
        #ifdef TEXTURED
        texcoordVert = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        #endif
        #ifdef COLORED
        glcolorVert = gl_Color;
        #endif
    gl_Position = ftransform();
    #ifdef CASCADED_SHADOWS
    gl_Position.z = distortZ(gl_Position.z);
    #else
    gl_Position.xyz = distort(gl_Position.xyz);
    #endif

    #endif
}