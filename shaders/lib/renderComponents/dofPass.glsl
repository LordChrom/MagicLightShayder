#version 430 compatibility
const int d = int(round(exp2(PASS)));

in vec2 texcoord;

uniform float viewWidth, viewHeight;


#define PI 3.1419526535897932

uniform sampler2D colortex0;
uniform sampler2D colortex6;

/* RENDERTARGETS: 0 */
out vec3 colorOut;


float dE,dC;

//TODO displaced texcoord with fixed ridges & hand
float getBlurWeight(vec2 displacedTexcoord, bool isCorner){
    float rad = (texture(colortex6,texcoord,min(PASS,3)).x);

    if(rad<=d)
        return 0;
    else if(rad<=sqrt(2)*d)
        return isCorner?0:0.2;
    else
        return 0.11111111;
}

const bool colortex0MipmapEnabled=true;
const bool colortex6MipmapEnabled=true;


void main() {
    dE = d;
    vec3 ret = texture(colortex0,texcoord,0).rgb;

    float centerRad = texture(colortex6,texcoord,0).x;
    if(centerRad>d){
        ret*=centerRad>sqrt(2)*d?0.11111111:0.2;
    }

    dC = dE*sqrt(2);


    vec2 offsetTexCoord;
    for(int x=-d; x<=d; x+=d){
        offsetTexCoord.x=texcoord.x+x/viewWidth;
        for(int y=-d; y<=d; y+=d){
            if(!bool(x|y)) continue;
            offsetTexCoord.y=texcoord.y+y/viewHeight;

            bool isCorner = bool(x)&&bool(y);

            vec3 color = texture(colortex0,offsetTexCoord,PASS).rgb;
            float w = getBlurWeight(offsetTexCoord, isCorner);
            ret += w*color;
        }
    }
    colorOut = ret;
}