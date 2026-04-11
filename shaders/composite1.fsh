#version 430 compatibility
#include "/lib/renderComponents/voxelLightingComposite.glsl"

in vec2 texcoord;

#if DEBUG_SPECIAL_VIEW >= 0
/* RENDERTARGETS: 6,7,15 */
#else
/* RENDERTARGETS: 6,7 */
#endif

layout(location = 0) out vec3 lighting;
layout(location = 1) out vec4 fog;

void main() {
	doVoxelLighting(vec2(texcoord),vec2(viewWidth,viewHeight));
	lighting = voxelLighting;
	fog = voxelFog;
}