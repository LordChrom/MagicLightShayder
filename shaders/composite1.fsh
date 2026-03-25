#version 430 compatibility
#include "/lib/renderComponents/voxelLightingComposite.glsl"

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;


/* RENDERTARGETS: 6,7 */
layout(location = 0) out vec4 lighting;
layout(location = 1) out vec4 fog;

void main() {
	vec2 newTexCoord = texcoord/LIGHTING_RENDERSCALE;
	if(newTexCoord.x>1 || newTexCoord.y>1) return;
	ivec2 texpos = ivec2(newTexCoord*vec2(viewWidth,viewHeight));
	doVoxelLighting(newTexCoord,texpos);
	lighting = voxelLighting;
	fog = voxelFog;
}