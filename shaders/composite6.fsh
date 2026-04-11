#version 430 compatibility
uniform vec2 scaledScreenDim;
uniform float viewWidth, viewHeight;

#include "/lib/renderComponents/blur.glsl"

#if BLOOM_LEVEL>=2
uniform sampler2D colortex6;
#endif

#if FOG_BLUR>=2
uniform sampler2D colortex7;
#endif

#if FOG_BLUR>=2 && BLOOM_LEVEL>=2
/* RENDERTARGETS: 6,7 */
layout(location = 0) out vec4 lighting;
layout(location = 1) out vec4 fog;
#elif BLOOM_LEVEL>=2
/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 lighting;

#elif FOG_BLUR>=2
/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 fog;
#endif

in vec2 texcoord;


void main() {
#if BLOOM_LEVEL>=2
    lighting = doBloom(colortex6,texcoord,2);
#endif

#if FOG_BLUR>=2
    fog = doFogBlur(colortex7,texcoord,2);
#endif
}