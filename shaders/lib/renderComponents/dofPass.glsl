#version 430 compatibility
#include "/lib/util/dofHelper.glsl"
int d = dFromLevel(PASS);

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
    for(int i=-DOF_SIZE; i<=DOF_SIZE; i++){
        int x = distort(i,d);
        offsetTexCoord.x=texcoord.x+x/viewWidth;
        for(int j=-DOF_SIZE; j<=DOF_SIZE; j++){
            int y = distort(j,d);
            offsetTexCoord.y=texcoord.y+y/viewHeight;

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