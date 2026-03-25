#include "/lib/settings.glsl"

uniform sampler2D colortex6;
uniform sampler2D colortex7;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;


/* RENDERTARGETS: 6,7 */
layout(location = 0) out vec4 lighting;
layout(location = 1) out vec4 fog;


const float sampleWidth = 0.01*BLOOM_WIDTH*LIGHTING_RENDERSCALE;
const float factor = -2/sampleWidth;
const float maxSampleBrightness = 1.5;

float blurDistr(float x){
    x*=factor;
    return exp(-x*x);
}

void doBlur(vec2 blurDir){
//    vec2 newTexCoord = texcoord/LIGHTING_RENDERSCALE;
    if(texcoord.x>LIGHTING_RENDERSCALE || texcoord.y>LIGHTING_RENDERSCALE) return;
    vec2 pxStep = blurDir*vec2(1.0/viewWidth,1.0/viewHeight);
    int stepCount = int(0.5*sampleWidth/length(pxStep));

    float totalWeight = 1;
    lighting = texture(colortex6,texcoord);

    for(int i=1;i<stepCount;i++){
        vec2 offset = pxStep*i;
        vec4 color1 = texture(colortex6,texcoord+offset);
        vec4 color2 = texture(colortex6,texcoord-offset);
        float col1len = length(color1.xyz);
        float col2len = length(color2.xyz);
        if(col1len>maxSampleBrightness) color1.xyz*=(maxSampleBrightness/col1len);
        if(col2len>maxSampleBrightness) color2.xyz*=(maxSampleBrightness/col2len);
        float mult = BLOOM_INTENSITY*blurDistr(length(offset));
        float weight1 = mult*(length(color1.xyz)*0.5+0.5);
        float weight2 = mult*(length(color2.xyz)*0.5+0.5);
        lighting+=weight1*color1 + weight2*color2;
        totalWeight+=weight1+weight2;
    }
    lighting/=totalWeight;

#if VOLUMETRIC_FOG_SAMPLES > 0
    totalWeight = 1;
    fog = texture(colortex7,texcoord);

    for(int i=1;i<stepCount;i++){
        vec2 offset = pxStep*i;
        vec4 color1 = texture(colortex7,texcoord+offset);
        vec4 color2 = texture(colortex7,texcoord-offset);
        float col1len = length(color1.xyz);
        float col2len = length(color2.xyz);
        if(col1len>maxSampleBrightness) color1.xyz*=(maxSampleBrightness/col1len);
        if(col2len>maxSampleBrightness) color2.xyz*=(maxSampleBrightness/col2len);
        float mult = blurDistr(length(offset));
        float weight1 = mult*(length(color1.xyz)*0.5+0.5);
        float weight2 = mult*(length(color2.xyz)*0.5+0.5);
        fog+=weight1*color1 + weight2*color2;
        totalWeight+=weight1+weight2;
    }
    fog/=totalWeight;
#endif


}