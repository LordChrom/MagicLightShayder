#version 430 compatibility
#include "/lib/renderComponents/blur.glsl"


uniform sampler2D colortex7;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

uniform int frameCounter;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 lighting;

void main() {
    if(texcoord.x>LIGHTING_RENDERSCALE || texcoord.y>LIGHTING_RENDERSCALE) return;
    vec2 pxStep = 3/vec2(viewWidth,viewHeight);

    lighting = doBlur(colortex7, texcoord,pxStep,1,1,1);
//    if(texcoord.x<LIGHTING_RENDERSCALE*0.5){
//        lighting = texture(colortex7, texcoord);
//    }
}