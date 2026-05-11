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


void main() {
    colorOut=vec3(0);

    vec2 offsetTexCoord;
    const int iterEdge = d*DOF_SIZE;
    for(int y=-iterEdge; y<=iterEdge; y+=d){
        offsetTexCoord.y=texcoord.y+y/viewHeight;
        if(offsetTexCoord.y<0 || offsetTexCoord.y>1) continue;

        for(int x=-iterEdge; x<=iterEdge; x+=d){
            offsetTexCoord.x=texcoord.x+x/viewWidth;
//            if(offsetTexCoord.x<0 || offsetTexCoord.x>1) continue;


            vec4 blurMeta = texture(colortex7,offsetTexCoord);
            float weight = weightAtOffset(blurMeta.w,x,y,d);

            if(weight<=1e-3)continue;

            float totalWeight = blurMeta[PASS];


            weight/=totalWeight;

            vec3 color = texture(colortex0,offsetTexCoord).rgb;
            colorOut += weight*color;
        }
    }
}