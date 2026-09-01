#define SAMPLES_FLOOD
#include "/lib/lighting/voxel/voxelHelper.glsl"

vec4 sampleFloodData(vec3 worldPos){
    vec3 distFromCenter = worldPos-globalOrigin;
    distFromCenter=abs(distFromCenter);
    if(max(max(distFromCenter.x,distFromCenter.y),distFromCenter.z)>0.5*(FLOODFILL_SIZE-1))
    return vec4(0);

    vec3 texPosition = fract((worldPos/FLOODFILL_SIZE)+0.5);
    const float edgeMargin = 0.5/FLOODFILL_SIZE;
    const float topEdgeMargin = 1-edgeMargin;

    if(!(texPosition.x<edgeMargin || texPosition.y<edgeMargin || texPosition.z<edgeMargin ||
    texPosition.x>topEdgeMargin || texPosition.y>topEdgeMargin || texPosition.z>topEdgeMargin)
    ){
        return vec4(texture(floodfillSampler,texPosition));
    }

    ivec3 lowerPos = ivec3(floor(worldPos-0.5))+FLOODFILL_SIZE/2;
    ivec3 upperPos = modFloodfillSize(lowerPos+1);
    lowerPos = modFloodfillSize(lowerPos);
    worldPos=fract(worldPos+0.5);
    vec4 ret;
    for(int x=0;x<=1;x++){
        for(int y=0;y<=1;y++){
            for(int z=0;z<=1;z++){
                ivec3 pos = ivec3(x,y,z);
                vec3 weight = pos+worldPos*(1-2*pos);
                pos = pos*lowerPos+(1-pos)*upperPos;
                ret+=texelFetch(floodfillSampler,pos,0)*(weight.x*weight.y*weight.z);
            }
        }
    }
    return ret;
}