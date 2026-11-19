#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

#ifdef CAN_VOXELIZE
uniform vec3 cameraPosition;

in vec4 at_midBlock;
in vec2 mc_Entity;
    #ifdef TEXTURED_VOXELIZATION
    in vec2 mc_midTexCoord;
    in vec4 at_tangent;
    #endif
#include "/lib/voxelStorage/vsMapper.glsl"

#endif

#ifdef SHADOWMAP_SHADOWS
#ifndef CAN_VOXELIZE
#include "/lib/util/uniforms/frameCounter"
#endif

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
        #ifdef TEXTURED_VOXELIZATION
        writeVoxelMapTextured(cameraPosition+gl_Vertex.xyz +at_midBlock.xyz*0.015625, int(mc_Entity.x), int(at_midBlock.w)
        );
        #else
        writeVoxelMap(cameraPosition+gl_Vertex.xyz +at_midBlock.xyz*0.015625, int(mc_Entity.x), int(at_midBlock.w));
        #endif
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