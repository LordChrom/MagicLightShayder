#version 430 compatibility

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 fog;

uniform sampler2D colortex7;
uniform sampler2D colortex13;

const int levels = 3;

const float[] weights = {0.125,0.5,1.5,2,1,1};

void main() {
    int texsize = textureSize(colortex7,0).x;

    vec4 total = vec4(0);
    total=texelFetch(colortex7,ivec2(gl_FragCoord.xy),0);
    total.rgb*=weights[0];
    float totalWeight = weights[0];

    for(int stage=0; stage<levels; stage++){
        float mipBase = (float(texsize-(texsize>>stage)))/texsize;
        vec2 thePos = vec2(mipBase,0)+(texcoord/(1<<(stage+1)));

        float weight = weights[stage+1];
        totalWeight+=weight;
        total.rgb+=texture(colortex13,thePos,0).rgb*weight;
    }
    total.rgb/=totalWeight;
    fog = total;
//    fog = texelFetch(colortex13,ivec2(gl_FragCoord.xy),0)*vec4(1,1,1,0);
}