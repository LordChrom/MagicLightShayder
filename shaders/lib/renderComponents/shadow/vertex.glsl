#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

#ifdef CAN_VOXELIZE
//#include "/lib/voxel/voxelMapper.glsl"
//uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;

out flat int mc_Entity_x;
out flat int midblockW;
out vec3 worldPosRel;
out vec3 toMidblock;
out vec3 normal;
#endif

#ifdef SHADOWMAP_SHADOWS
#include "/lib/shadowmap/distortion.glsl"

#ifdef TEXTURED
out vec2 texcoordVert;
#endif

#ifdef COLORED
out vec4 glcolorVert;
#elif defined CUTOUT
out float glcolorAlphaVert;
#endif

#endif

void main() {
    #ifdef CAN_VOXELIZE
    worldPosRel = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz;
    toMidblock = at_midBlock.xyz/64.0;
    mc_Entity_x = int(mc_Entity.x);
    midblockW = int(at_midBlock.w);
    normal = gl_Normal;
    #endif

    #ifdef SHADOWMAP_SHADOWS
        #ifdef TEXTURED
        texcoordVert = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        #endif
        #ifdef COLORED
        glcolorVert = gl_Color;
        #elif defined CUTOUT
        glcolorAlphaVert = gl_Color.a;
        #endif
    gl_Position = ftransform();
    #ifdef CASCADED_SHADOWS
    gl_Position.z = distortZ(gl_Position.z);
    #else
    gl_Position.xyz = distort(gl_Position.xyz);
    #endif

    #endif
}