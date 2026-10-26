float calcWaveHeight(vec2 posFromCenter){
    float waveX = length(worldPosXz);
    return WATER_WAVE_HEIGHT*sin(WATER_WAVE_PEAKS_PER_BLOCK*waveX-WATER_WAVE_SPEED*frameTimeCounter)*exp(waveX*-0.1);
}

vec3 calcWaveNormal(vec2 posFromCenter){
    float waveX = length(worldPosXz);
    vec2 waveDerivative=(WATER_WAVE_HEIGHT*WATER_WAVE_PEAKS_PER_BLOCK)*cos(WATER_WAVE_PEAKS_PER_BLOCK*waveX-WATER_WAVE_SPEED*frameTimeCounter)*normalize(worldPosXz);
    return normalize(vec3(waveDerivative.x,16f,waveDerivative.y));
}