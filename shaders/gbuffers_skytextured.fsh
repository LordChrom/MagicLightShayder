uniform int biome_category;
#define SKYTEXTURED
#define BONUS_STUFF

#include "/gbuffers_textured.fsh"

void doBonusStuff(){
    if(biome_category==CAT_THE_END){
        color.rgb*=0.4;
    }
}