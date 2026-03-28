
#define WRITES_VOX
#include "/lib/voxel/voxelHelper.glsl"

//block info, RGB are color,
//A is, from MSB to LSB,
// 4 bits emission type
// 2 bits free
// a bit that's 1 for translucent blocks like stained glass
// a bit that's 1 for surfaces that block light

//TODO redo this so the layout can be rearranged with defines, to change the priority of blocks in low detail regions


void writeVoxelMap(vec3 worldPos, int blockID, vec3 toMidblock, uint emission){
//    if(max(max(abs(toMidblock.x),abs(toMidblock.y)),abs(toMidblock.z))>0.5)
//        return; //for blocks that dont fit in the box, altho not best solution

    vec3 color = vec3(0.9,0.6,0.6);
    uint metadata;

    if(blockID>=0){
        color.r=(blockID/100)%10;
        color.g=(blockID/10)%10;
        color.b=(blockID)%10;
        color/=9;


        metadata = ((blockID/1000u)%10u);
        if(emission>0){
            color*=float(emission)*0.06666; //1/15
            metadata&=0xfeu;
            metadata |= ((blockID/10000u)%10u)<<4;
        }

    }else{
        color=vec3(1,0,0);
        metadata=1;
    }

#ifndef LIGHT_SOURCES_BLOCK_CENTERIC
    if(emission>0)
        worldPos+= toMidblock+vec3(0.05); //TODO account for scale
    else
#endif
        worldPos+= toMidblock*0.5; //TODO account for scale and slabs


    if(!isVoxelInBounds(worldPos)) return;

    uint cascadeLevel = getCascadeLevel(worldPos);
    for(uint i = cascadeLevel; i<NUM_CASCADES;i++){
        float scale = getScale(i);
        ivec4 areaPos = worldPosToArea(worldPos, scale);
        ivec3 areaShift = getAreaShift(scale);
        uint areaMemOffset = areaOffset(i);


        setVoxData(uvec4(255*color, metadata), areaPos.xyz, areaShift, areaMemOffset);
    }
}