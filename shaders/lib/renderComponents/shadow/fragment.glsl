#version 430 compatibility

#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

#ifndef SHADOWMAP_SHADOWS
const int shadowMapResolution = 1;
void main(){}
#else

const int shadowMapResolution = SHADOW_RESOLUTION;

#ifdef TEXTURED
uniform sampler2D gtexture;
in vec2 texcoord;
#endif

#ifdef COLORED
layout(location = 0) out vec4 color;
in vec4 glcolor;
#elif defined CUTOUT
in float glcolorAlpha;
#endif


void main(){
    #ifdef COLORED
    color = texture(gtexture, texcoord) * glcolor;
    if(color.a < 0.1){
        discard;
    }
    #elif defined CUTOUT
    float alpha = texture(gtexture, texcoord).a * glcolorAlpha;
    if(alpha < 0.1){
        discard;
    }
    #endif
}
#endif