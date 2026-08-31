#version 430 compatibility

in vec2 texcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 voxelLighting;

uniform sampler2D colortex6;

void main(){
    voxelLighting=texelFetch(colortex6,ivec2(gl_FragCoord),0);
    vec2 pixelSize = 1.0/textureSize(colortex6,0);

    float ssao;
    float value=0.0;
    for(int x=-1;x<=1;x+=2){
        for(int y=-1;y<=1;y+=2){
            vec2 sampleCoord = texcoord+pixelSize*ivec2(x,y);
            vec4 SSAOs = textureGather(colortex6,sampleCoord,3);

            for(int i=0;i<4;i++){
                value+=SSAOs[i];
            }
        }
    }
    ssao = value/16.0;
    voxelLighting.rgb*=ssao/voxelLighting.a;
}