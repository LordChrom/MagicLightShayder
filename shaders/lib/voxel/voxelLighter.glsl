
layout (rgba32ui) uniform restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;


const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;



lightVoxData determineBestLightSource( float scale,
    lightVoxData[3][3] inputSamples, uvec4 [3][3] frontVoxels, uvec4 [3][3] rearVoxels, bool [3][3] obstructions
){
    lightVoxData bestLight = noLight;
    float bestStrength = 0;

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            lightVoxData lightSrc = inputSamples[a+1][b+1];

            if(lightSrc.emission==0)
                continue;

            bool isCenter = (a|b)==0;

            bool selfOccluded = obstructions[a+1][b+1];

            //if corner, its neighbors. If edge, itself and center. If center, itself twice
            //in any case, these both being blocked means no light from this input voxel
            bool helpersOccluded = (obstructions[a+1][1]) && (obstructions[1][b+1]);


            vec3 displ = lightSrc.lightTravel;
            float lenSquared = dot(displ, displ);
            float strength = float(lightSrc.emission)/max(0.1, lenSquared);
            displ.xy+=vec2(a,b)*scale;

            bool srcBlocked = (helpersOccluded && !isCenter) || selfOccluded;

            srcBlocked = srcBlocked || (displ.x*a>0) || (displ.y*b>0); //will be unnecessary soon

            //occlusion stuff goes here, maybe

            if(srcBlocked)
                inputSamples[a+1][b+1].emission=0;

            if (strength>bestStrength && !srcBlocked){
                bestLight=lightSrc;
                bestStrength=strength;
            }
        }
    }

    return bestLight;
}



//out of 9 input samples, only up to 4 can have any light flowing between the source and the output
//corner closest to source at [0][0], output at [1][1]
//newObstructions is flipped to match this, with [2][2] being the firthest corner from source
void pickRelevantInputSamples(lightVoxData bestSource, lightVoxData[3][3] inputSamples, bool[3][3] obstructions, float scale,
    out lightVoxData[2][2] samples, out bool[2][2] relevance, out bool[3][3] newObstructions){

    vec3 lightTravel = bestSource.lightTravel;
    int aSignSrc = int(sign(lightTravel.x));
    int bSignSrc = int(sign(lightTravel.y));

    for(int i=-1; i<=1; i++){
        for(int j=-1; j<=1; j++){
            newObstructions[1+i][1+j]=obstructions[1+aSignSrc*i][1+bSignSrc*i];
        }
    }

    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            int a = i*aSignSrc;
            int b = j*bSignSrc;
            lightVoxData relevantSample = inputSamples[1+a][1+b];
            bool sameSource = relevantSample.lightTravel==bestSource.lightTravel;

            relevance[i][j] = sameSource;
            samples[i][j] = relevantSample;
        }
    }
}



//separating these out just for more readability
void occludeOuterEdge(float edge, inout float rayPart, inout bvec2 mapParts){
    rayPart=min(rayPart,edge);
    mapParts=bvec2(false);
}
void occludeInnerEdge(float edge, inout float rayPart, inout bvec2 mapParts){
    rayPart=max(rayPart,edge);
    mapParts=bvec2(false);
}
void occludeOuterEdgeA(float edge, inout vec2 ray, inout bvec4 map){occludeOuterEdge(edge,ray.x,map.xz);}
void occludeOuterEdgeB(float edge, inout vec2 ray, inout bvec4 map){occludeOuterEdge(edge,ray.y,map.xy);}
void occludeInnerEdgeA(float edge, inout vec2 ray, inout bvec4 map){occludeInnerEdge(edge,ray.x,map.yw);}
void occludeInnerEdgeB(float edge, inout vec2 ray, inout bvec4 map){occludeInnerEdge(edge,ray.y,map.zw);}

vec4 getBoundingSlopes(vec3 lightTravel, float scale){
    float slopeScale = scale/(lightTravel.z-0.5);
    return (abs(lightTravel.xy).xyxy + vec4(0.5,0.5,-0.5,-0.5))*slopeScale;
}


//okay so i'll be calling the +b direction "top" and the +a direction "left"
//as though you're looking along the +z direction and the light is going +x+y
void determineOcclusion(lightVoxData[2][2] samples, bool[2][2] relevance, bool[3][3] obstructions, vec4 occludeSlopes,
    out vec2 outRay, out bvec4 outMap
){

}



//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    float scale = 1;

    lightVoxData [3][3] inputSamples;
    uvec4 [3][3] frontVoxels;
    uvec4 [3][3] rearVoxels;
    bool [3][3] obstructions;

    //all the relevant memory accesses
    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 localOffset = ivec3(a,b,-1);
            uvec4 frontVoxel = imageLoad(worldVox,sectionPos+ivec3(localOffset.xy,0));
            uvec4 rearVoxel = imageLoad(worldVox,sectionPos+localOffset);
            lightVoxData inputSample = unpackLightData(imageLoad(lightVox, sectionPos+localOffset));
            inputSample.lightTravel-=vec3(localOffset)*scale;

            bool rearObstructed = (rearVoxel.w&1u)==1;
            bool frontObstructed = (frontVoxel.w&1u)==1;
//            frontObstructed = frontObstructed && !(a==0&&b==0);

            if(rearVoxel.w==0x01){ //non emissive
                inputSample=noLight;
            }


            obstructions[a+1][b+1]= rearObstructed || frontObstructed;
            frontVoxels[a+1][b+1] = frontVoxel;
            rearVoxels[a+1][b+1] = rearVoxel;
            inputSamples[a+1][b+1] = inputSample;
        }
    }


    //determine best light source first
    lightVoxData bestLight = determineBestLightSource(
        scale, inputSamples, frontVoxels, rearVoxels, obstructions
    );


    // then pick the 4 relevant input samples
    // (the voxels further from the center of the light source do not contribute)
    lightVoxData[2][2] relevantSamples;
    bool[2][2] relevance;
    bool[3][3] newObstructions;
    pickRelevantInputSamples(bestLight, inputSamples, obstructions, scale,
        relevantSamples,relevance, newObstructions);

    determineOcclusion(relevantSamples, relevance, newObstructions, getBoundingSlopes(bestLight.lightTravel,scale),
        bestLight.occlusionRay, bestLight.occlusionMap);


    if (frontVoxels[1][1].w>0xf){
        bestLight.lightTravel = vec3(0);
        bestLight.color = frontVoxels[1][1].rgb*(1.0/255.0);
        bestLight.emission = frontVoxels[1][1].w>>4;
        bestLight.occlusionMap=bvec4(true);
    }

//    bestLight.occlusionRay = abs(bestLight.lightTravel.xy/(bestLight.lightTravel.z-0.5));
//    bestLight.occlusionMap = bvec4(false,true,false,true);

    imageStore(lightVox,sectionPos,packLightData(bestLight));
}

void lightVoxelFaces(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId)+ivec3(1);
    ivec3 progress = axisNumToVec(debugAxisNum);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_STRIDE){
        lightVoxelFace(sectionPos+progress*i,section,progress,debugAxisNum);
    }
}

