#ifndef BLOCK_PACKING_GLSL
#define BLOCK_PACKING_GLSL

uint blockLightID(uint blockID){
    return uint(blockID)&0x3fu;
}

uint blockShape(uint blockID){
    return (blockID>>6)&0xffu;
}

//block shape is 4 bits category, 4 bits subcategory
//Cat 0: hardcoded
//      0: air
//      1: Full
//Cat 1-2: stairs and slabs
//      1 is top, 2 is bottom
//      subcat is, in order, occupancy of the -- +- -+ ++ xz corners of the free half of the slab/stair
//Cat 3 is trapdoors:
//      subcat is covered face axis num
uint directedBlockages(uint block){
    uint shape = blockShape(block);
    uint ret = 0u;
    if(shape<16u)
        return bool(shape)?0x3fu:0u;
    if(shape<48u){
        //the sides. There is likely a more efficient way to do this
        ret= (uint((shape&3u)==3u)<<5)|(uint((shape&5u)==5u)<<1)
           | (uint((shape&12u)==12u)<<4)|uint((shape&10u)==10u);

        ret|=bool(shape&0x10u)?8u:4u; //top vs bottom
        return ret;
    }
    if(shape<64u){
        return (1u<<(shape&0xfu))&0x3fu;
    }
    return 0u;
}

bool blockBlocksFace(uint block, uint axis){
    return bool(directedBlockages(block)&(1u<<axis));
}

bool worldVoxBlocksFace(uint worldvox, uint axis){
    return bool(worldvox&(1u<<(axis+WORLDVOX_BLOCKAGES_SHIFT)));
}

bool blockIsTranslucent(uint blockID){
    return blockLightID(blockID)>=48u;
}

bool blockIsTransparent(uint blockID){
    return blockShape(blockID)==0u;
}

bool blockIsFullCube(uint blockID){
    return blockShape(blockID)==1u;
}

uint blockLightAnimationType(uint blockID){
    blockID = blockLightID(blockID);
    if(blockID>=48) return 0;

    return blockID>=32u
        ?(((blockID&0x38u)==0x28u)?3u:4u)
        :2u;
}

vec3 getLightIDColor(uint lightID){
    uint packedColor = 0u;

    //TODO: this could also be in an SSBO or custom image, and would cache very nicely test performance thereof
    switch (lightID){
        //no animation
        case  1: packedColor=0x984u; break;//glowstone,redstone lamps, copper bulbs, brewing stands
        case  2: packedColor=0x985u; break;//enclosed normal fire
        case  3: packedColor=0x838u; break;//crying obby and similar
        case  4: packedColor=0x079u; break;//ominous trial vault
        case  5: packedColor=0x922u; break;//On redstone
        case  6: packedColor=0x941u; break;//Lava
        case  7: packedColor=0x589u; break;//Sea lights
        case  8: packedColor=0x498u; break;//end portal
        case  9: packedColor=0x221u; break;//light block
        case 10: packedColor=0x741u; break;//shroomlight
        case 11: packedColor=0x777u; break;//white
        case 12: packedColor=0x498u; break;//ender chest & portal frame
        case 13: packedColor=0x709u; break;//nether portal
        case 14: packedColor=0x297u; break;//sea pickle
        case 15: packedColor=0x687u; break;//enchanting table
        case 16: packedColor=0x798u; break;//firefly bush
        case 17: packedColor=0x886u; break;//froglight ochre
        case 18: packedColor=0x686u; break;//froglight verdant
        case 19: packedColor=0x757u; break;//froglight pearlescent

        //flickering
        case 32: packedColor=0x985u; break;//enclosed normal fire
        case 33: packedColor=0x079u; break;//ominous trial spawner
        case 34: packedColor=0x851u; break;//Open flame
        case 35: packedColor=0x399u; break;//Soul fire
        case 36: packedColor=0x495u; break;//Copper fire

        //pulsating
        case 40: packedColor=0x035u; break;//Inactive sculk
        case 41: packedColor=0x069u; break;//Active sculk
        case 42: packedColor=0x729u; break;//Amethyst

        //subsurface
        case 46: packedColor=0x552u; break;//Cave berries
        case 47: packedColor=0x332u; break;//Cave plants

        //translucent colors, stained glasses
        case 48: packedColor=0x777u; break;//white
        case 49: packedColor=0x864u; break;//orange
        case 50: packedColor=0x747u; break;//magenta
        case 51: packedColor=0x668u; break;//light_blue
        case 52: packedColor=0x873u; break;//yellow
        case 53: packedColor=0x584u; break;//lime
        case 54: packedColor=0x867u; break;//pink
        case 55: packedColor=0x333u; break;//gray
        case 56: packedColor=0x555u; break;//light_gray
        case 57: packedColor=0x467u; break;//cyan
        case 58: packedColor=0x648u; break;//purple
        case 59: packedColor=0x337u; break;//blue
        case 60: packedColor=0x752u; break;//brown
        case 61: packedColor=0x262u; break;//green
        case 62: packedColor=0x722u; break;//red
        case 63: packedColor=0x222u; break;//black
    }
    return vec3(uvec3(
            packedColor>>8,
            packedColor>>4,
            packedColor
    )&0xfu)/9.0;
}

vec3 getMaterialColor(uint materialID){
    return getLightIDColor(blockLightID(materialID));
}

bool isMaterialHardcodedSubsurface(uint materialID){
    return (materialID&=0x3eu)==46u;
}

uvec4 getHardcodedMaterial(uint materialID, uint blockEmission){
    uint meta = ((materialID>>6)%10u);

    float subsurface = float(isMaterialHardcodedSubsurface(materialID));
    uint emissive = 0u;
    float porosity = 0;
    if(materialID>=0){
        emissive = bool(meta&4u)?int(floor(16.93*blockEmission)):0;
    }

    return clamp(uvec4(
        0,
        0,
        (porosity>0.01)?porosity*64:64+subsurface*190.0,
        emissive
    ),0u,255u);
}

uvec4 getHardcodedMaterial(uint materialID){
    return getHardcodedMaterial(materialID,15);
}

uint packVoxelForStorage(uint blockID, uint emission){

    blockID = blockID&0xffffu;
    if(blockID==0xffff){
        blockID = bool(emission)?
            65: //default emissive is like brewing stand
            64; //solid cube
    }

    uint ret = 0u;
    if(blockIsTranslucent(blockID)){
        ret=WORLDVOX_TRANSLUCENT;
    }else if(blockIsFullCube(blockID)){
        ret=WORLDVOX_OPAQUE;
    }

    return ret
    | (WORLDVOX_INITIAL_TIME<<WORLDVOX_AGE_SHIFT)
    | (directedBlockages(blockID)<<WORLDVOX_BLOCKAGES_SHIFT)
    | (emission<<WORLDVOX_EMISSION_SHIFT)
    | uint(blockID)
    ;
}


vec3 worldVoxColor(uint packedData){
    vec3 color = getLightIDColor(blockLightID(packedData));
    if(!bool(packedData&WORLDVOX_TRANSLUCENT)){
        uint emissive = (packedData>>WORLDVOX_EMISSION_SHIFT)&0xfu;
        color*=(emissive*0.06666); // 1/15
    }
    return color;
}

vec3 worldVoxColor(uint lightID, uint emission){
    return getLightIDColor(blockLightID(lightID))*(emission*0.06666);
}
#endif