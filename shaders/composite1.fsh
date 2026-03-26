#version 430 compatibility
#include "/lib/renderComponents/voxelLightingComposite.glsl"

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

#if DEBUG_SPECIAL_VIEW >= 0
/* RENDERTARGETS: 6,7,8 */
#else
/* RENDERTARGETS: 6,7 */
#endif

layout(location = 0) out vec4 lighting;
layout(location = 1) out vec4 fog;

void main() {
	ivec2 outTexpos = ivec2(round(vec2(texcoord)*vec2(viewWidth,viewHeight)-0.07));
	vec2 newTexCoord = texcoord/LIGHTING_RENDERSCALE;

#if LIGHTING_RENDERSCALE==1
	ivec2 inTexpos = outTexpos;
#else
	if(newTexCoord.x>1 || newTexCoord.y>1) return;
	ivec2 inTexpos = ivec2(round(newTexCoord*vec2(viewWidth,viewHeight)-0.07));
#endif

	doVoxelLighting(vec2(newTexCoord),inTexpos,outTexpos);
	lighting = voxelLighting;
	fog = voxelFog;
}