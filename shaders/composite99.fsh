#version 430 compatibility
#include "/lib/settings.glsl"

in vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform usampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform sampler2D colortex15;
uniform sampler2D colortex16;
uniform sampler2D colortex17;
uniform sampler2D colortex18;
uniform sampler2D colortex19;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outColor;


void main() {
#if DEBUG_SPECIAL_VIEW == 1
    outColor=texture(colortex1,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 2
    outColor=texture(colortex2,texcoord).rgb*2-1;
#elif DEBUG_SPECIAL_VIEW == 3
    outColor=texture(colortex3,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 4
    outColor= texture(colortex4,texcoord).rgb*2-1;
#elif DEBUG_SPECIAL_VIEW == 5
    outColor=texture(colortex5,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 6
    outColor=texture(colortex6,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 7
    outColor=texture(colortex6,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 8
    uvec4 mat = texture(colortex8,texcoord);
    float funnyEmissive = (mat.a==255)?0.0:(mat.a/254.0);
    outColor=funnyEmissive+mat.rgb*((1.0-funnyEmissive)/255.0);
    //        outColor=funnyEmissive*mat.rgb*(1.0/255.0);
#elif (DEBUG_SPECIAL_VIEW == 10) || (DEBUG_SPECIAL_VIEW == 200)
    outColor = texture(colortex10,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 11
    outColor = texture(colortex11,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 100
    outColor = vec3(clamp(0.05*sqrt(length(worldPosRelative)),0,1),float(isHand)*0.1,float(depth==1)*0.5);
#elif DEBUG_SPECIAL_VIEW == 101
    outColor = vec3(ditherValue);
#elif DEBUG_SPECIAL_VIEW == 102
    ivec2 texpos = ivec2(gl_FragCoord.xy);
    outColor = vec3((texpos.x^texpos.y)&4,(texpos.x^texpos.y)&2,(texpos.x^texpos.y)&1);
#elif (DEBUG_SPECIAL_VIEW == 105)
    outColor = vec3(depthToLinear(depth)/4);
#endif


    ivec2 texpos = ivec2(gl_FragCoord.xy);
    float debugCheckerScale = 7;
    bool checker = bool((int(texpos.x/debugCheckerScale)^int(texpos.y/debugCheckerScale))&1);
    vec3 mult = checker?vec3(1):sign(outColor.xyz)*0.2+0.8;
    outColor=mult*abs(outColor);
}