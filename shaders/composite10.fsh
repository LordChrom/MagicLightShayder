#version 430 compatibility
#include "/lib/util/conversions.glsl"
#include "/lib/settings.glsl"

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 fog;

uniform sampler2D colortex7;
uniform sampler2D colortex13;
uniform sampler2D depthtex1;

const int levels = 3;

const float[] weights = {1,4,8,8};

void main() {
    ivec2 texsize = textureSize(colortex7,0);

    fog=texelFetch(colortex7,ivec2(gl_FragCoord.xy),0);
    float depth = depthToLinear(texture(depthtex1,texcoord).x);
    float totalWeight = 0;
    fog.rgb*=totalWeight;

    for(int stage=0; stage<levels; stage++){
        float mipBase = (float(texsize.x-(texsize.x>>stage)))/texsize.x;
        vec2 thePos = vec2(mipBase,0)+(texcoord/(1<<(stage+1)));

        vec4 texSample = texture(colortex13,thePos,0);

        float depthDif = (max(depth,texSample.a)>1000)?0:texSample.a-depth;
        float weight = weights[stage];
        weight*=clamp(1-0.1*abs(depthDif), 0.00001, 1);

        totalWeight+=weight;
        fog.rgb+=texSample.rgb*weight;
    }
    fog.rgb/=totalWeight;
//    fog=vec4(texture(colortex13,texcoord).rgb,0);
}