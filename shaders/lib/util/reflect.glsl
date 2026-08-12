vec3 reflect(vec3 dir, vec3 norm){
    return normalize(dir-norm*(2*dot(norm,dir)));
}

vec3 worldPosToScreen(vec3 worldPos){
    vec4 pos = vec4(mat3(gbufferModelView)*worldPos,1);
    pos=gbufferProjection*pos;
    return (pos.xyz*(0.5/pos.w))+0.5;
}

vec3 screenPosToWorld(vec3 screenPos){
    vec4 pos = vec4(screenPos*2-1,1);
    pos=gbufferProjectionInverse*pos;
    pos/=pos.w;
    return mat3(gbufferModelViewInverse)*pos.xyz;
}

//TODO gotta be a better way to do this
vec3 worldDirToScreen(vec3 worldNormal, vec3 screenPos){
    float dif = 0.01;
    vec3 worldPos = screenPosToWorld(screenPos);
    vec3 offsetScreenPos = worldPosToScreen(worldPos+dif*worldNormal);
    return normalize(offsetScreenPos-screenPos);
}

const int stepsPerBounce=REFLECTION_QUALITY/REFLECTION_BOUNCES;
#define REFLECTION_THRESHOLD 0.05

vec3 doMarch(vec3 initialPos, vec3 viewDir, float ditherValue, out uint hitReason){
    vec2 differential = viewDir.xy/viewDir.z;
    vec2 remainingScreen = vec2(differential.x>0?1-initialPos.x:initialPos.x,differential.y>0?1-initialPos.y:initialPos.y);
    float stepSize=min(remainingScreen.x/abs(differential.x),remainingScreen.y/abs(differential.y))/REFLECTION_QUALITY;
    #if REFLECTION_BOUNCES>1
    stepSize*=min(2,1+0.3*REFLECTION_BOUNCES);
    #endif
    bool seenAir = false;
    for(int i=0;i<=stepsPerBounce;i++){
        float depthDist = stepSize*(i+ditherValue)+0.001;
        vec3 newPos = initialPos+vec3(depthDist*differential,depthDist);
        float distFromEdge =min(min(newPos.x,newPos.y),1-max(newPos.x,newPos.y));
        if(distFromEdge<ditherValue*0.1){
            hitReason=1;
            return newPos;
        }
        float texDepth = texture(depthtex2,newPos.xy).x;
        if(texDepth<=newPos.z){
            hitReason=0;
            float linearTargetDepth = depthToLinear(newPos.z);
            float depthDif = (linearTargetDepth-depthToLinear(texDepth))/linearTargetDepth;
            if(depthDif>0.1)
            hitReason=1;
            if(seenAir){
                return newPos;
            }
        }else{
            seenAir=true;
        }
    }

    hitReason=2;
    return initialPos+stepSize*stepsPerBounce*vec3(differential,1);
}