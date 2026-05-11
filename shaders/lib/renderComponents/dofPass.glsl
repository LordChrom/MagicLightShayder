#version 430 compatibility
const int d = int(round(exp2(PASS)));
const float sqrt2d = sqrt(2)*float(d);

in vec2 texcoord;

uniform float viewWidth, viewHeight;


#define PI 3.1419526535897932

uniform sampler2D colortex0;
uniform sampler2D colortex6;

/* RENDERTARGETS: 0 */
out vec3 colorOut;


float centerRad, centerEdgeness, centerDepth;

uniform float frameTimeCounter;
//TODO displaced texcoord with fixed ridges & hand
float getBlurWeight(vec2 displacedTexcoord, bool isCenter, bool isCorner, out int sampleMip){
    vec3 sampleCoC = texture(colortex6,displacedTexcoord,0).xyz;
    float rad = sampleCoC.x;

  #if PASS==0
    sampleMip=0;
  #else
    sampleMip = int(floor(log2(rad)));
    sampleMip = clamp(sampleMip,0,PASS);
  #endif

    float steepness=0.6/d;
    float edgeWeight = clamp(0.5+(steepness)*(rad-d),0,1);
    float cornerWeight = clamp(0.5+(steepness)*(rad-sqrt2d),0,1);


    float weight = isCenter?1:(isCorner?cornerWeight:edgeWeight);
    weight/=(1+4*edgeWeight+4*cornerWeight);

    if(rad>1.25*centerRad){
        if (sampleCoC.z<0.5*centerDepth) //just prettier
            weight*=clamp(centerDepth/sampleCoC.z,1,1.25);
        else if (sampleCoC.z>1.1*centerDepth) //mimics part of circle being occluded
            weight*=0.8;
    }
    return weight;
}

const bool colortex0MipmapEnabled=true;
const bool colortex6MipmapEnabled=true;


void main() {

    vec3 centerCoC = texture(colortex6,texcoord,0).xyz;
    centerRad = centerCoC.x;
    centerEdgeness = centerCoC.y;
    centerDepth = centerCoC.z;



    vec3 ret=vec3(0);

    vec2 offsetTexCoord;
    for(int x=-d; x<=d; x+=d){
        offsetTexCoord.x=texcoord.x+x/viewWidth;
        for(int y=-d; y<=d; y+=d){
            bool isCenter = !bool(x|y);
            bool isCorner = bool(x)&&bool(y);

//            if(isCenter) continue;
            offsetTexCoord.y=texcoord.y+y/viewHeight;

            int sampleMip;
            float w = getBlurWeight(offsetTexCoord, isCenter,isCorner, sampleMip);
            if(w<=1e-9)
                continue;

            vec3 color = texture(colortex0,offsetTexCoord,sampleMip).rgb;
            ret += w*color;
        }
    }
    colorOut = ret;
}