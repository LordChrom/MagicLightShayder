#version 430 compatibility
#include "/lib/util/dofHelper.glsl"
//int d = dFromLevel(PASS);
const int d = int(round(exp2(PASS)));

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
    ivec2 offsetTexpos;
    const int iterEdge = d*DOF_SIZE;
    for(int y=-iterEdge; y<=iterEdge; y+=d){
        offsetTexpos.y=texpos.y+y;
        if(offsetTexpos.y<0)
            continue;
        if(offsetTexpos.y>viewHeight)
            return;

        for(int x=-iterEdge; x<=iterEdge; x+=d){
            //+(bool((y/d)&1)?d:0)

            offsetTexpos.x=texpos.x+x;

            vec4 blurMeta = texelFetch(colortex7,offsetTexpos,0);
            float weight = weightAtOffset(blurMeta.w,x,y,d);

            if(weight<=1e-3)continue;

            float totalWeight = blurMeta[PASS];


            weight/=totalWeight;
            vec3 color = texelFetch(colortex0,offsetTexpos,0).rgb;
            colorOut += weight*color;
        }
    }
}