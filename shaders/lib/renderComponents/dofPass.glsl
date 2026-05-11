#version 430 compatibility
#include "/lib/util/dofHelper.glsl"
const int d = dFromLevel(PASS);

in vec2 texcoord;

uniform float viewWidth, viewHeight;

uniform sampler2D colortex0;
uniform sampler2D colortex6;
#if DOF_LEVEL>1
    uniform sampler2D colortex7;
#endif

/* RENDERTARGETS: 0 */
out vec3 colorOut;

const bool colortex0MipmapEnabled=true;


void main() {
    colorOut=vec3(0);

    vec2 offsetTexCoord;
    const int iterEdge = d*DOF_SIZE;
    for(int x=-iterEdge; x<=iterEdge; x+=d){
        offsetTexCoord.x=texcoord.x+x/viewWidth;
        for(int y=-iterEdge; y<=iterEdge; y+=d){
            offsetTexCoord.y=texcoord.y+y/viewHeight;

            vec3 sampleCoC = texture(colortex6,offsetTexCoord,0).xyz;
            float rad = sampleCoC.x;
            float weight = weightAtOffset(rad,x,y,d);

            if(weight<=1e-3)continue;

          #if PASS==0
            int sampleMip=0;
          #else
            int sampleMip = int(floor(log2(rad)));
            sampleMip = clamp(sampleMip,0,PASS);
          #endif

          #if DOF_LEVEL>1
            float totalWeight = texture(colortex7,offsetTexCoord,0)[PASS];
          #else
            float totalWeight = sampleCoC.z;
          #endif


            weight/=totalWeight;

            vec3 color = texture(colortex0,offsetTexCoord,sampleMip).rgb;
            colorOut += weight*color;
        }
    }
}