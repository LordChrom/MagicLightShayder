#version 430 compatibility
uniform vec2 scaledScreenDim;
uniform float viewWidth, viewHeight;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D depthtex1;

#include "/lib/renderComponents/blur.glsl"

#if BLOOM_LEVEL>=BLUR_PASS
uniform sampler2D colortex6;
#endif

#if FOG_BLUR>=BLUR_PASS
uniform sampler2D colortex7;
#endif

#if FOG_BLUR>=BLUR_PASS && BLOOM_LEVEL>=BLUR_PASS
/* RENDERTARGETS: 6,7 */
layout(location = 0) out vec4 lighting;
layout(location = 1) out vec4 fog;
#elif BLOOM_LEVEL>=BLUR_PASS
/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 lighting;

#elif FOG_BLUR>=BLUR_PASS
/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 fog;
#endif

in vec2 texcoord;

const int dist = int(round(exp2(BLUR_PASS-1)));

void main() {
    #if BLOOM_LEVEL>=BLUR_PASS
    lighting = doBloom(colortex6,texcoord,dist);
    #endif

    #if FOG_BLUR>=BLUR_PASS
    fog = doFogBlur(colortex7,texcoord,dist);
    #endif
}