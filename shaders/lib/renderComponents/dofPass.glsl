#version 430 compatibility
#include "/lib/util/dofHelper.glsl"
#define LEVEL (DOF_PASSES-PASS-1)
const int d = 1<<LEVEL;

in vec2 texcoord;

uniform float viewWidth, viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex7;

/* RENDERTARGETS: 0 */
out vec3 colorOut;

void takeSample(ivec2 pos){

}

void main() {
    colorOut=vec3(0);

    ivec2 texpos = ivec2(floor(texcoord*vec2(viewWidth,viewHeight)));
#if DOF_ANTIBLEED != -1
    float centerRad = max(0.1,texelFetch(colortex7,texpos,0).w);
    float centerRadInv = 1.0/(centerRad*DOF_ANTIBLEED);
    const float antibleedBias = 1+1.0/DOF_ANTIBLEED;

#endif

    ivec2 offsetTexpos;
    for(int y=-DOF_SAMPLE_RAD; y<=DOF_SAMPLE_RAD; y++){
        offsetTexpos.y=texpos.y+(y<<LEVEL);
        if(offsetTexpos.y<0)
            continue;
        if(offsetTexpos.y>viewHeight)
            return;

        float a = DOF_SAMPLE_RAD*DOF_SAMPLE_RAD-y*y;
        if(a<0)
            continue;
        int xrange =  int(floor(sqrt(a)));
        for(int x=-xrange; x<=xrange; x++){
            offsetTexpos.x=texpos.x+(x<<LEVEL);

            vec4 blurMeta = texelFetch(colortex7,offsetTexpos,0);
            float len = length(ivec2(x,y)<<LEVEL);

            float weight = weightAtOffset(blurMeta.w,len,d);
        #if DOF_ANTIBLEED != -1
            weight*=clamp(antibleedBias-blurMeta.w*centerRadInv,0,1);
        #endif
            if(weight<=1e-3)continue;

            float totalWeight = blurMeta[LEVEL];


            weight/=totalWeight;
            vec3 color = texelFetch(colortex0,offsetTexpos,0).rgb;
            colorOut += weight*color;
        }
    }
}