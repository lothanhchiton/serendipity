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

#define RSM_ON
#define GTAO_ON
//#define VanillaAO
#define WaterCaustics_ON
//#define REFLECTED_CLOUD

// #define PARALLAX
#define POM_STEPS 32 // [8 12 16 20 24 28 32 36 40 44 48 52 56 60 64]
#define POM_REFINEMENT_STEPS 8 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]
#define POM_DEPTH_SCALE 3.0 // [0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0]

// #define PARALLAX_SHADOW
#define POM_SHADOW_STEPS 16 // [8 16 32 64]
#define POM_SHADOW_SOFTNESS 12.0 // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0]

#define INFOMATION A // [A B]