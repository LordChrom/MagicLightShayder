#ifndef VOXY_PATCH
#version 430 compatibility
#endif
#define GBUFFER_SHADER

#include "/lib/settings.glsl"
const float translucentPrecedenceCutoff = 0.99;

#ifdef VOXY_PATCH
    #if MATERIALS_TYPE>=1
        #define NEEDS_MATERIAL_ID
        #define HARDCODED_MATERIAL
        #define MATERIALS_TYPE 0
        #include "/lib/util/materialId.glsl"
    #endif

    #if MATERIALS_TYPE < 0
        #undef WRITE_MATERIALS
    #endif
    #ifndef TRANSLUCENT
        #undef FORWARD_TRANSLUCENTS
    #endif
    #undef POM
#else

#if ((DEBUG_SPECIAL_VIEW==104) || (DEBUG_SPECIAL_VIEW==106))
#undef TRANSLUCENT
#endif

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
    #define HARDCODED_MATERIAL
    flat in uvec4 hardcodedMaterialInfo;
    #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
        #define NEEDS_MATERIAL_ID
    #endif
#endif

#ifdef TEXTURED
in vec2 texcoord;
uniform sampler2D gtexture;
    #if MATERIALS_TYPE ==1
uniform sampler2D specular;
uniform sampler2D normals;
flat in vec4 tangent;
    #endif
#endif

#ifdef LIT
//in vec2 lmcoord;
//uniform sampler2D lightmap;
#endif

#ifdef VERTEX_NORMALS
flat in vec3 normal;
#endif

#ifdef ALPHATEST
uniform float alphaTestRef = 0.1;
#endif

#ifdef ENTITY
uniform vec4 entityColor;
#endif

#ifdef BONUS_STUFF
void doBonusStuff();
#endif

#ifdef BASIC
in flat vec4 glcolor;
#else
in vec4 glcolor;
#endif

#ifdef NEEDS_MATERIAL_ID
flat in int materialID;
#include "/lib/util/materialId.glsl"
#endif

#if !(defined FORWARD_TRANSLUCENTS && defined TRANSLUCENT && defined LIT)
    #undef FORWARD_TRANSLUCENTS
#endif

#if defined MAYBE_END_GATEWAY && defined GATEWAYS_IN_GBUFFER
    uniform float viewWidth, viewHeight;
    #include "/lib/renderComponents/endGateway.glsl"
#endif

#ifdef FORWARD_TRANSLUCENTS
    in vec3 worldPos;
    uniform vec3 cameraPosition;
    #if SUBSURFACE_MODE==2
        #define SUBSURFACE_MODE 0
    #endif
    #ifdef BASIC_FLOODFILL
    uniform sampler2D lightmap;
    #endif
    #include "/lib/lightingWrapper/lightSampler.glsl"
    #include "/lib/util/dither.glsl"

    /* RENDERTARGETS: 3,2 */
#elif defined TRANSLUCENT
    #ifdef WRITE_MATERIALS
    /* RENDERTARGETS: 3,2,8 */
    #else
    /* RENDERTARGETS: 3,2 */
    #endif
#else
    #ifdef WRITE_MATERIALS
    /* RENDERTARGETS: 1,2,8 */
    #else
    /* RENDERTARGETS: 1,2 */
    #endif
#endif

#endif


#ifdef HAND
    #define NORMAL_A 0.5
#elif defined TRANSLUCENT
    #define NORMAL_A 1
#else
    #define NORMAL_A 0
#endif

#if (!defined POM_ELLIGIBLE) || defined NORMALS_NOT_INCLUDED
    #undef POM
#endif

#if (defined ENTITY) && !(defined ENTITY_POM)
    #undef POM
#endif

#ifdef POM
    in vec2 differential;
    flat in ivec2 baseTexpos;
    flat in ivec2 texsize;
    in float worldLength;
    #ifndef ENTITY
    uniform ivec2 atlasSize;
    #else
    #define atlasSize textureSize(normals,0)
    #endif
    uniform mat4 gbufferProjectionInverse;
    float rayDepth=0;
    #include "/lib/renderComponents/pom.glsl"
    #ifdef POM_WRITE_DEPTH
    #include "/lib/util/conversions.glsl"
    #endif
#else
#undef POM_WRITE_DEPTH
#undef POM_NORMALS
#endif

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;

#ifdef FORWARD_TRANSLUCENTS
uvec4 materialInfo;
#else
#ifdef WRITE_MATERIALS
layout(location = 2) out uvec4 materialInfo;
#endif
#endif

/*
const vec4 colortex1ClearColor = vec4(0.0,0.0,0.0,0.0);
*/

#ifdef VOXY_PATCH
void handleFragment(vec4 glcolor,vec3 normal, vec2 lmcoord, vec4 voxycolor, int materialID)

#if 0
;//for my IDE :/
#endif

#else
void main()
#endif
{
#ifdef TEXTURED
    #ifdef POM
        vec2 newTexcoord=doPom(texcoord);
        #ifdef POM_WRITE_DEPTH
        float linearDepth = depthToLinear(gl_FragCoord.z);
        rayDepth = length(vec3(differential/texsize,1))*rayDepth;
        linearDepth+=rayDepth;
        gl_FragDepth=depthToBuf(linearDepth);
        #endif
    #else
//        gl_FragDepth=gl_FragCoord.z;
        #define newTexcoord texcoord
    #endif
#endif


    color=glcolor;
#ifdef MAYBE_END_GATEWAY
    bool isEndGateway = materialID==55498;

    if(isEndGateway){
        color = vec4(doEndGateway(gl_FragCoord.xy/vec2(viewWidth,viewHeight)),1);
    }else{
        color *= texture(gtexture, newTexcoord);
    }

#elif defined VOXY_PATCH
    color *= voxycolor;
#elif defined TEXTURED
    color *= texture(gtexture, newTexcoord);
#endif

#ifdef ENTITY
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef ALPHATEST
    if (color.a < alphaTestRef) {
        discard;
    }
#endif

#ifdef VERTEX_NORMALS
    #if (defined TEXTURED) && (MATERIALS_TYPE == 1)
    vec4 pbrNormalSample = texture(normals,newTexcoord);

    pbrNormalSample.xy = (pbrNormalSample.xy-0.5)*2;

    normalOut.xyz = normalize(vec3(PBR_NORMALS_STRENGTH*pbrNormalSample.xy,sqrt(1.0 - dot(pbrNormalSample.xy, pbrNormalSample.xy))));

    #ifdef POM_NORMALS
    const float pomDistFalloffMult = 4;
    pomNormal=normalize(mix(vec3(0,0,1),pomNormal+vec3(0,0,0.1),clamp(pomDistFalloffMult/(max(1e-4,worldLength)),0,1)));

    float texNormalWeight = max(1e-6,pomNormal.z);

    normalOut.xyz = normalize(pomNormal+texNormalWeight*normalOut.xyz);
    #endif


    normalOut.xyz = normalize( mat3(tangent.xyz,normalize(cross(tangent.xyz,normal)*tangent.w),normal) * normalOut.xyz );

    #ifdef POM
        #if DEBUG_SPECIAL_VIEW==104

        ivec2 checkerPos = (ivec2(floor(texcoord*atlasSize))-baseTexpos)%texsize;
        float checkerf=((bitCount(checkerPos.x^checkerPos.y)&3))/3.0;
        color.xyz=vec3(min(abs(differential.xy*0.3),1)*vec2((differential.x<=0)?1-checkerf:1,(differential.y<=0)?1-checkerf:1),0.1);
        #elif DEBUG_SPECIAL_VIEW==106
        ivec2 checkerPos = (ivec2(floor(newTexcoord*atlasSize))-baseTexpos)%texsize;
        float checkerf=((bitCount(checkerPos.x^checkerPos.y)&3))/3.0;
        color.xyz=mix(color.xyz,vec3(checkerf.x),0.5);
        if(checkerPos.x==0 || checkerPos.y==0)
            color.r=1;
        else if(checkerPos.x==(texsize.x-1) || checkerPos.y==(texsize.y-1))
            color.b=1;
        #endif
    #endif

    normalOut.xyz = (normalOut.xyz+1)*0.5;
    #else
    normalOut.xyz = (normal+1)*0.5;
    #endif

    normalOut.a=NORMAL_A;


    #ifdef TRANSLUCENT
    if(color.a<=translucentPrecedenceCutoff)
        normalOut.a=0;
    #endif
#endif


#ifdef WRITE_MATERIALS
    #if MATERIALS_TYPE == 0 //hardcoded
        #ifdef VOXY_PATCH
    materialInfo = getHardcodedMaterial(materialID);
        #else
    materialInfo = hardcodedMaterialInfo;
        #endif

        #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
    if(materialInfo.a!=255){
        vec3 lightColor = getMaterialColor(materialID);
        float brightness = dot(color.rgb/glcolor.rgb,normalize(lightColor));
        brightness*=brightness;
        brightness = brightness*HARDCODED_EMISSIVE_SELECTIVITY + (1-HARDCODED_EMISSIVE_SELECTIVITY);
        materialInfo.a=uint(clamp(brightness,0,1)*materialInfo.a);
    }
        #endif

    #elif MATERIALS_TYPE == 1 //PBR pack
    materialInfo = uvec4(round(clamp(texture(specular,newTexcoord)*255.0,0,255)));
    #endif

    #ifdef TRANSLUCENT

    if(color.a<translucentPrecedenceCutoff)
        materialInfo.a=255;
    #endif
#endif


    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif

    #ifdef FORWARD_TRANSLUCENTS
    #ifdef VOXY_PATCH
    vec3 incidentLightColor = voxyLighting(lmcoord).rgb;
    color.rgb=mix(color.rgb*min(1,(incidentLightColor.r+incidentLightColor.g+incidentLightColor.b)),color.rgb*incidentLightColor,color.a);

    #else
    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    float emissive = (materialInfo.a!=255)?materialInfo.a/254.0:0;
    float subsurface = clamp(float(int(materialInfo.b)-64)/190.0, 0.0,1.0);
    #ifdef NEEDS_MATERIAL_ID
    if(materialID==24709)
        emissive=1;
    #endif
    #ifdef MAYBE_END_GATEWAY
    if(!isEndGateway)
    #endif
    {
        if(emissive>0)
            color.rgb*=(EMISSIVE_BRIGHTNESS*emissive);
        else{
            vec3 incidentLightColor=lightingSample(vec3(worldPos.xy,worldPos.z-0.1), normalize(normalOut.xyz*2-1), subsurface, ditherValue)+(EMISSIVE_BRIGHTNESS*emissive);
            color.rgb=mix(color.rgb*min(1,(incidentLightColor.r+incidentLightColor.g+incidentLightColor.b)),color.rgb*incidentLightColor,color.a);
        }
            //I cannot explain the 0.1 z
    }
    #endif
    #endif

#ifndef TRANSLUCENT
    #ifdef MAYBE_END_GATEWAY
    color.a=float(isEndGateway);
    #elif defined LIT
    color.a=0;
    #elif defined BASIC
    bool isLeash = length(glcolor.xyz-vec3(0.425,0.34,0.25))<0.5;
    color.a=float(!isLeash);
    #else
    color.a=1;
    #endif
#endif
}