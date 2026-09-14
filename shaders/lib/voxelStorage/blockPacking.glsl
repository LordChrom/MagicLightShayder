vec3 getLightIdColor(uint lightId){
    uint packedColor = 0u;

    //TODO: this could also be in an SSBO or custom image, and would cache very nicely test performance thereof
    switch (lightId){
        case  1: packedColor=0x984u; break;//glowstone,redstone lamps, copper bulbs, brewing stands
        case  2: packedColor=0x985u; break;//Enclosed fire
        case  3: packedColor=0x838u; break;//crying obby and similar
        case  4: packedColor=0x729u; break;//amethyst
        case  5: packedColor=0x079u; break;//ominous trial chamber
        case  6: packedColor=0x851u; break;//Open flame
        case  7: packedColor=0x399u; break;//Soul fire
        case  8: packedColor=0x495u; break;//opper fire
        case  9: packedColor=0x922u; break;//On redstone
        case 10: packedColor=0x552u; break;//Cave berries
        case 11: packedColor=0x941u; break;//Lava
        case 12: packedColor=0x035u; break;//Inactive sculk
        case 13: packedColor=0x069u; break;//Active sculk
        case 14: packedColor=0x589u; break;//Sea lights
        case 15: packedColor=0x565u; break;//Cave plants
        case 16: packedColor=0x498u; break;//end portal
        case 17: packedColor=0x221u; break;//light block
        case 18: packedColor=0x741u; break;//shroomlight
        case 19: packedColor=0x777u; break;//white
        case 20: packedColor=0x498u; break;//ender chest & portal frame
        case 21: packedColor=0x709u; break;//nether portal
        case 22: packedColor=0x297u; break;//sea pickle
        case 23: packedColor=0x687u; break;//enchanting table
        case 24: packedColor=0x798u; break;//firefly bush
        case 25: packedColor=0x886u; break;//froglight ochre
        case 26: packedColor=0x686u; break;//froglight verdant
        case 27: packedColor=0x757u; break;//froglight pearlescent

        //translucent colors, stained glasses
        case 32: packedColor=0x777u; break;//white
        case 33: packedColor=0x864u; break;//orange
        case 34: packedColor=0x747u; break;//magenta
        case 35: packedColor=0x668u; break;//light_blue
        case 36: packedColor=0x873u; break;//yellow
        case 37: packedColor=0x584u; break;//lime
        case 38: packedColor=0x867u; break;//pink
        case 49: packedColor=0x333u; break;//gray
        case 40: packedColor=0x555u; break;//light_gray
        case 41: packedColor=0x467u; break;//cyan
        case 42: packedColor=0x648u; break;//purple
        case 43: packedColor=0x337u; break;//blue
        case 44: packedColor=0x752u; break;//brown
        case 45: packedColor=0x262u; break;//green
        case 46: packedColor=0x722u; break;//red
        case 47: packedColor=0x222u; break;//black
    }
    return vec3(uvec3(
            packedColor>>8,
            packedColor>>4,
            packedColor
    )&0xfu)/9.0;
}

vec3 getMaterialColor(int materialId){
    return getLightIdColor(uint(materialId) % 1000);
}

bool isHardcodedSubsurface(int materialID){
    return ((materialID%10000)==15);
}

uvec4 getHardcodedMaterial(int materialID, int blockEmission){
    int meta = ((materialID/1000)%10);

    float subsurface = 0;
    uint emissive = 0;
    float porosity = 0;

    if(materialID>=0){
        subsurface = isHardcodedSubsurface(materialID) || (materialID==24565 ) || (materialID==24431)?1.0:0;
        emissive = bool(meta&4)?int(floor(16.93*blockEmission)):0;
    }

    return clamp(uvec4(
        0,
        0,
        (porosity>0.01)?porosity*64:64+subsurface*190.0,
        emissive
    ),0u,255u);
}

uvec4 getHardcodedMaterial(int materialID){
    return getHardcodedMaterial(materialID,15);
}

uint packVoxelForStorage(int blockID, uint emission){

    blockID = blockID&0xffff;
    if(blockID==0xffff){
        blockID = (emission>0)?
            10001: //default emissive is glowstone
            2000; //solid cube
    }

    uint blockIDmeta = blockID/1000u;

    uint obstructivenessType = (blockIDmeta)&3u;
    uint metadata = (8u>>obstructivenessType)&7u;
    //types: (0 is air, 1 is translucent, 2 is full opacity, 3 is shaped opacity)
    //flags: translucent, opaque, shaped

    if(emission>0){
        uint lightType = (blockIDmeta>>2u)&7u;
        metadata |= lightType<<(WORLDVOX_TYPE_SHIFT-WORLDVOX_META_SHIFT);
    }

    return (metadata<<WORLDVOX_META_SHIFT)
    | (emission<<6) | (uint(blockID)%1000u)
    | uint(WORLDVOX_INITIAL_TIME<<WORLDVOX_AGE_SHIFT);
}


vec3 worldVoxColor(uint packedData){
    uint lightID = packedData&0x3fu;
    vec3 color = getLightIdColor(lightID);
    if(!bool(packedData&WORLDVOX_TRANSLUCENT)){
        uint emissive = (packedData>>6)&0xfu;
        color*=(emissive*0.06666); // 1/15
    }
    return color;
}