#version 430 compatibility
#include "/lib/util/dofHelper.glsl"
const int d = dFromLevel(PASS);

in vec2 texcoord;

uniform float viewWidth, viewHeight;

uniform sampler2D colortex0;
    uniform sampler2D colortex7;

/* RENDERTARGETS: 0 */
out vec3 colorOut;

const bool colortex0MipmapEnabled=true;


void main() {
    colorOut=vec3(0);

    vec2 offsetTexCoord;
    const int iterEdge = d*DOF_SIZE;
    const int maxMip = int(floor(0.6*log2(d*DOF_SIZE)));
    for(int i=-DOF_SIZE; i<=DOF_SIZE; i++){
        int x = distort(i,d);
        offsetTexCoord.x=texcoord.x+x/viewWidth;
        for(int j=-DOF_SIZE; j<=DOF_SIZE; j++){
            int y = distort(j,d);
            offsetTexCoord.y=texcoord.y+y/viewHeight;


            vec4 sampleCoC = texture(colortex7,offsetTexCoord,0);
            float rad = sampleCoC.w;
            float weight = weightAtOffset(rad,x,y,d);

            if(weight<=1e-3)continue;

          #if PASS==0
            int sampleMip=0;
          #else
            int sampleMip = int(floor(log2(rad)));
            sampleMip = clamp(sampleMip,0,2);
          #endif

            float totalWeight = sampleCoC[PASS];


            weight/=totalWeight;

            vec3 color = texture(colortex0,offsetTexCoord,sampleMip).rgb;
            colorOut += weight*color;
        }
    }
}