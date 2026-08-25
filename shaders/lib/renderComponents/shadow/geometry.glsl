#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/renderComponents/shadow/shadowProgramFeatures.glsl"

layout(triangles) in;
#ifdef CAN_VOXELIZE
#include "/lib/voxel/voxelMapper.glsl"
uniform vec3 cameraPosition;

in flat int[] blockID;
in flat int[] blockEmission;
in vec3[] worldPosRel;
in vec3[] normal;
void voxelize(){
    vec3 minWorldPos = cameraPosition+min(min(worldPosRel[0],worldPosRel[1]),worldPosRel[2]);
    vec3 maxWorldPos = cameraPosition+max(max(worldPosRel[0],worldPosRel[1]),worldPosRel[2]);
    writeVoxelMap(minWorldPos, maxWorldPos, blockID[0], normal[0], blockEmission[0]);
}
#endif


#ifndef SHADOWMAP_SHADOWS
layout(triangle_strip, max_vertices = 0) out;
void main(){
    #ifdef CAN_VOXELIZE
    voxelize();
    #endif
}
#else


#ifdef TEXTURED
in vec2[] texcoordVert;
out vec2 texcoord;
#endif

#ifdef COLORED
in vec4[] glcolorVert;
out vec4 glcolor;
#endif


#ifndef CASCADED_SHADOWS
uniform bool hasCeiling;

//no cascades, just passthru
layout(triangle_strip, max_vertices = 3) out;

void main(){
    #ifdef CAN_VOXELIZE
    voxelize();
    #endif
    if(hasCeiling) return;
    for(int i=0;i<3;i++){
        gl_Position = gl_in[i].gl_Position;

        #ifdef TEXTURED
        texcoord = texcoordVert[i];
        #endif

        #ifdef COLORED
        glcolor = glcolorVert[i];
        #endif
        EmitVertex();
    }
    EndPrimitive();
}

#else
uniform bool hasCeiling;
//yes cascasdes
layout(triangle_strip, max_vertices = 6) out;
#ifndef CAN_VOXELIZE
uniform int frameCounter;
#endif

#include "/lib/shadowmap/distortion.glsl"

void main(){
    #ifdef CAN_VOXELIZE
    voxelize();
    #endif
    if(hasCeiling) return;

    float maxDist = 0;
    for(int i=0;i<3;i++){
        vec2 absPos = abs(gl_in[i].gl_Position.xy);
        maxDist=max(maxDist,max(absPos.x,absPos.y));
    }

    float floatLevel = getFloatMaxLevel(maxDist);

    int minLevel=clamp(int(floatLevel-0.15),0,MAX_SHADOW_CASCADE);
    int maxLevel=clamp(int(floatLevel+0.5),0,MAX_SHADOW_CASCADE);

    #ifdef TAA
        vec2 posJitter = INDIVIDUAL_CASCADE_SCALE*shadowJitter();
    #endif
    for(int level=minLevel;level<=maxLevel;level++){
        vec2[3] positions;

        float scale = getLevelScale(level);
        vec2 center = getLevelCenter(level);
        for(int i=0;i<3;i++){
            positions[i]=gl_in[i].gl_Position.xy*scale;
            #ifdef TAA
            positions[i]+=posJitter;
            #endif

            positions[i] = clamp(positions[i],-1,1);
            positions[i] = positions[i]/INDIVIDUAL_CASCADE_SCALE+center;
        }

        for (int i=0;i<3;i++){
            gl_Position.zw = gl_in[i].gl_Position.zw;
            gl_Position.xy=positions[i].xy;
            #ifdef TEXTURED
            texcoord = texcoordVert[i];
            #endif

            #ifdef COLORED
            glcolor = glcolorVert[i];
            #endif
            EmitVertex();
        }
        EndPrimitive();
    }
}
#endif
#endif