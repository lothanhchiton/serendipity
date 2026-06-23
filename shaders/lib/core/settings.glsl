#define MAT_ICE 10.0

/*
const int colortex0Format = RGB16F;
const int colortex1Format = RGB16;
const int colortex2Format = RGBA8;
const int colortex3Format = RGBA8;
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
const int shadowcolor0Format = RGBA16F;
*/

const bool      colortex6Clear = false;
const bool      colortex7Clear = false;

const int 		noiseTextureResolution  = 128;

const int 		shadowMapResolution 	= 2048;		// [1024 2048 4096 6144 8192 16384 32768]
const float     sunPathRotation         =-40.0f;
const float 	shadowDistance 			= 192.0;	// [64.0 96.0 128.0 192.0 256.0 384.0 512.0 768.0 1024.0]
const float 	shadowIntervalSize 		= 4.0f;
const float     shadowDistanceRenderMul = 1.0f;		// [-1.0f 1.0f]

const float HALF_PI = 1.5707963267948966;
const float PI      = 3.14159265359;
const float _2PI    = 6.28318530718;
const float _4PI    = 12.5663706144;

const float GOLDEN_RATIO = 0.61803398875;
const float GOLDEN_ANGLE = 2.39996323;

const float goldenSin = sin(GOLDEN_ANGLE);
const float goldenCos = cos(GOLDEN_ANGLE);
const mat2  goldenRot = mat2(goldenCos, -goldenSin, goldenSin, goldenCos);

const float EarthRadius             = 6378.137;
const float EarthRadiusSquared      = EarthRadius * EarthRadius;
const float AtmosphereThickness     = 100.0;
const float AtmosphereRadius        = EarthRadius + AtmosphereThickness;
const float AtmosphereRadiusSquared = AtmosphereRadius * AtmosphereRadius;
const float RayleighScalarAltitude  = 8.5;
const float MieScalarAltitude       = 1.2;

#define TransmittanceLut colortex5
#define UseTransmittanceLut

#define AtmosphereType 2

#if AtmosphereType == 0
    const vec3  RayleighScatteringCoefficient = vec3(0.00559495220371, 0.0117551946648, 0.02767445204);
    const vec3  MieScatteringCoefficient      = vec3(0.0170860716184, 0.0240702118158, 0.0356570844484);
    const vec3  OzoneAbsorptionCoefficient    = vec3(4.9799463143e-10, 3.0842607592e-10, -9.1714404502e-12) * 100000.0;
    const vec3  MieAbsorptionCoefficient      = MieScatteringCoefficient * 0.1;
#elif AtmosphereType == 1
    const vec3  RayleighScatteringCoefficient = vec3(5.802, 13.558, 33.1) * 1e-3;
    const vec3  MieScatteringCoefficient      = vec3(3.996) * 1e-3;
    const vec3  OzoneAbsorptionCoefficient    = vec3(0.65, 1.881, 0.085) * 1e-3;
    const vec3  MieAbsorptionCoefficient      = vec3(4.4) * 1e-3;
#elif AtmosphereType == 2
    const vec3  RayleighScatteringCoefficient = vec3(5.802, 13.558, 33.1) * 1e-3 * vec3(1.2, 0.9, 0.9);
    const vec3  MieScatteringCoefficient      = vec3(3.996) * 1e-3 * 5.0;
    const vec3  OzoneAbsorptionCoefficient    = vec3(0.65, 1.881, 0.085) * 1e-3;
    const vec3  MieAbsorptionCoefficient      = vec3(4.4) * 1e-3;
#endif

#define ReferenceHeight 1.0
float cameraAltitude = ReferenceHeight + max(cameraPosition.y + 64.0, 0.0) * 0.001;
float cameraHeight = cameraAltitude + EarthRadius;
vec3  cameraLocation = vec3(0.0, cameraHeight, 0.0);

vec3 sunViewDir   = normalize(sunPosition);
vec3 moonViewDir  = normalize(moonPosition);
vec3 lightViewDir = normalize(shadowLightPosition);

vec3 sunDir   = mat3(gbufferModelViewInverse) * sunViewDir;
vec3 moonDir  = mat3(gbufferModelViewInverse) * moonViewDir;
vec3 lightDir = mat3(gbufferModelViewInverse) * lightViewDir;

vec3 sunLuminance   = vec3(10.0) * mix(1.0, 0.02, sqrt(sqrt(rainStrength)));
vec3 moonLuminance  = vec3(0.05);
bool isDay = sunDir.y > 0.0;
vec3 lightLuminance = isDay ? sunLuminance : moonLuminance;

vec3 handPosition = vec3(0.9, -0.65, -near - 0.1);
vec3 handPosition2 = vec3(-0.9, -0.65, -near - 0.1);

#define SHADOW_BIAS 0.925
#define TAA
#define TAA_Intensity 0.25

#define GTAO_ON
//#define VanillaAO
#define WaterCaustics_ON
#define REFLECTED_CLOUD

// #define PARALLAX
#define POM_STEPS 64 // [8 12 16 20 24 28 32 36 40 44 48 52 56 60 64 78 82 86 90 94 98 102 106 120 124 160 164]
#define POM_REFINEMENT_STEPS 20 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
#define POM_DEPTH_SCALE 5.5 // [0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0]

// #define PARALLAX_SHADOW
#define POM_SHADOW_STEPS 32 // [8 16 32 64]
#define POM_SHADOW_SOFTNESS 7.0 // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0]

// #define ITEM_PARALLAX
// #define ENTITY_PARALLAX

#define INFOMATION A // [A]

#define RAIN_PUDDLES

#define LIGHT_MODE 1 // [1 2]
#define SSPT_INTENSITY 1.0 // [0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5 1.55 1.6 1.65 1.7 1.75 1.8 1.85 1.9 1.95 2.0 2.05 2.1 2.15 2.2 2.25 2.3 2.35 2.4 2.45 2.5 2.55 2.6 2.65 2.7 2.75 2.8 2.85 2.9 2.95 3.0 3.05 3.1 3.15 3.2 3.25 3.3 3.35 3.4 3.45 3.5 3.55 3.6 3.65 3.7 3.75 3.8 3.85 3.9 3.95 4.0 4.05 4.1 4.15 4.2 4.25 4.3 4.35 4.4 4.45 4.5 4.55 4.6 4.65 4.7 4.75 4.8 4.85 4.9 4.95 5.0]
#define SSPT_MAX_FRAMES 16.0 // [8.0 16.0 24.0 32.0 40.0 48.0 56.0 64.0 72.0 80.0 88.0 96.0 104.0 112.0 120.0 128.0]

#if LIGHT_MODE == 2
#undef RSM_ON
#else
#define RSM_ON
#endif

// #define SPECULAR_REFLECTION

#define CLOUD_QUALITY 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0]

#define CLOUD_CLEAR_ALTITUDE 2.5 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 60.0 70.0 80.0 90.0 100.0]
#define CLOUD_CLEAR_THICKNESS 1.5 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define CLOUD_CLEAR_COVERAGE 0.5 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define CLOUD_CLEAR_DENSITY 1.0 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define CLOUD_CLEAR_SCALE 0.28 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

#define CLOUD_RAIN_ALTITUDE 1.5 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 60.0 70.0 80.0 90.0 100.0]
#define CLOUD_RAIN_THICKNESS 2.0 // [0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0]
#define CLOUD_RAIN_COVERAGE 0.9 // [0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define CLOUD_RAIN_DENSITY 1.5 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
#define CLOUD_RAIN_SCALE 0.2 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]

// #define DOF
#define DOF_FOCUS_MODE 0 // [0 1]
#define DOF_MANUAL_DIST 10.0 // [5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 11.0 11.5 12.0 12.5 13.0 13.5 14.0 14.5 15.0 15.5 16.0 16.5 17.0 17.5 18.0 18.5 19.0 19.5 20.0]

#define DOF_FOCAL_LENGTH 50.0
#define DOF_FSTOP 1.4
#define DOF_COC_SCALE 3500.0
#define DOF_MAX_COC_PX 28.0

#define DOF_SAMPLES 48 // [12 24 36 48 64]
#define DOF_BOKEH_SHAPE 0 // [0 5 6 8]

#define DOF_BLUR_SKY

#define MOTION_BLUR
#define MOTION_BLUR_STRENGTH 1.0 // [0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0 4.2 4.4 4.6 4.8 5.0 5.2 5.4 5.6 5.8 6.0 6.2 6.4 6.6 6.8 7.0]
#define MOTION_BLUR_MAX_PX 32.0 // [16.0 32.0 64.0]
#define MOTION_BLUR_SAMPLES 16 // [8 16 24 32 40 48 52 60 68 72]
#define MOTION_BLUR_SKY