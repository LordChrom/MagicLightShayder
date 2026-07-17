#version 430 compatibility

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 fog;

uniform sampler2D colortex7;
uniform usampler2D colortex13;

const int levels = 3;

void main() {
    vec4 total = vec4(0);
    ivec2 pos = ivec2(gl_FragCoord.xy);
    total.a=texelFetch(colortex7,pos,0).a;
    ivec2 texsize = textureSize(colortex7,0);

    for(int stage=0; stage<levels; stage++){
        vec2 mipBase = vec2(texsize-(texsize>>stage))/texsize;
        vec2 thePos = mipBase+(texcoord/(1<<(stage+1)));

        total.rgb+=texture(colortex13,thePos,0).rgb*(1.0/1024f);
    }
    total.rgb/=levels;
    fog = total;
}