#ifndef CONST_FUNC_H

#define to_world(v, t, b, n) (mat3((t), (b), (n)) * (v))
#define to_local(v, T, B, N) ( (v) * mat3((T), (B), (N)) )

#define M_PI			3.14159265358979323846	// pi
#define M_TWO_PI		6.283185307179586476925	// 2*pi
#define M_PI_2			1.57079632679489661923	// pi/2
#define M_PI_4			0.785398163397448309616	// pi/4
#define M_1_PI			0.318309886183790671538	// 1/pi
#define M_2_PI			0.636619772367581343076	// 2/pi
#define M_1_OVER_TWO_PI	0.159154943091895335768	// 1/ (2*pi)

#define INF 1e32f
#define EPS 1e-3f
#define EPS2 2e-3f

#define NEARzero 1e-35f
#define isZERO(x) ((x)>-NEARzero && (x)<NEARzero)
#define allLessThanZERO(a)	( (a).x + (a).y + (a).z < NEARzero )
#define allGreaterZERO(a)	( (a).x + (a).y + (a).z >= NEARzero )
#define sum_is_empty_abs(a) (abs((a).x) + abs((a).y) + abs((a).z) < NEARzero)
#define sum_is_not_empty_abs(a) (abs((a).x) + abs((a).y) + abs((a).z) >= NEARzero)

#define Mix(a, b, c, bary) ( (a) + ((b) - (a)) * (bary).y + ((c) - (a)) * (bary).z )
#define luminance(rgb) (dot((rgb), vec3(0.212671F, 0.715160F, 0.072169F)))

#define saturate(x) ( clamp((x), 0.0F, 1.0F) )

float pow5(float x) { return x*x*x*x*x; }
float pow4(float x) { return x*x*x*x; }

// Polynomial approximation by Christophe Schlick
float Schlick(const float cosine, const float refractionIndex)
{
	float r0 = (1 - refractionIndex) / (1 + refractionIndex);
	r0 *= r0;
	// taken from https://www.photometric.io/blog/improving-schlicks-approximation/
	return r0 + (1 - cosine - r0) * pow4(1 - cosine);
}

//onb revisited by Disney
void ONB(vec3 n, out vec3 b1, out vec3 b2) {
    float signZ = n.z < 0.f ? -1.f : 1.f;
    float a = -1.0f / (signZ + n.z);
    b2 = vec3(n.x * n.y * a, signZ + n.y * n.y * a, -n.y);
    b1 = vec3(1.0f + signZ * n.x * n.x * a, signZ * b2.x, -signZ * n.x);
}

void ONBAlignWithNormal(vec3 up, out vec3 right, out vec3 forward)
{
    right = normalize(cross(up, vec3(0.0072f, 1.0f, 0.0034f)));
    forward = cross(right, up);
}

void orthonormalBasis(vec3 normal, out vec3 tangent, out vec3 bitangent)
{
  if(normal.z < -0.99998796F)  // Handle the singularity
  {
    tangent   = vec3(0.0F, -1.0F, 0.0F);
    bitangent = vec3(-1.0F, 0.0F, 0.0F);
    return;
  }
  float a   = 1.0F / (1.0F + normal.z);
  float b   = -normal.x * normal.y * a;
  tangent   = vec3(1.0F - normal.x * normal.x * a, b, -normal.x);
  bitangent = vec3(b, 1.0f - normal.y * normal.y * a, -normal.y);
}

vec3 AlignWithNormal(vec3 ray, vec3 normal)
{
    vec3 T, B;
    ONB(normal, T, B);
    return to_world(ray, T, B, normal);
}

vec3 LinearToST2084UE(vec3 lin)
{
    const float m1 = 0.1593017578125; // = 2610. / 4096. * .25;
    const float m2 = 78.84375; // = 2523. / 4096. *  128;
    const float c1 = 0.8359375; // = 2392. / 4096. * 32 - 2413./4096.*32 + 1;
    const float c2 = 18.8515625; // = 2413. / 4096. * 32;
    const float c3 = 18.6875; // = 2392. / 4096. * 32;
    const float C = 10000.;

    vec3 L = lin/C;
    vec3 Lm = pow(L, vec3(m1));
    vec3 N1 = ( c1 + c2 * Lm );
    vec3 N2 = ( 1.0 + c3 * Lm );
    vec3 N = N1 * (1.0 / N2);
    vec3 P = pow( N, vec3(m2) );

    return P;
}

vec3 ACES_Tonemapping(vec3 color){
    mat3 m1 = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
    );
    mat3 m2 = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108,  1.10813, -0.07276,
    -0.07367, -0.00605,  1.07602
    );
    vec3 v = m1 * color;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return pow(clamp(m2 * (a / b), 0.0, 1.0), vec3(1.0 / 2.2));
}

vec3 uncharted2Tonemap(vec3 x) {
    float A = 0.15;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20;
    float E = 0.02;
    float F = 0.30;
    float W = 11.2;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 Uncharted2_Tonemapping(vec3 color) {
    const float W = 11.2;
    float exposureBias = 2.0;
    vec3 curr = uncharted2Tonemap(exposureBias * color);
    vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
    return curr * whiteScale;
}

// hsv to rgb
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2yuv(vec3 rgb) {
    float Y = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
    float U = -0.14713 * rgb.r - 0.28886 * rgb.g + 0.436 * rgb.b;
    float V = 0.615 * rgb.r - 0.51499 * rgb.g - 0.10001 * rgb.b;
    return vec3(Y, U, V);
}

vec3 yuv2rgb(vec3 yuv) {
    float Y = yuv.x;
    float U = yuv.y;
    float V = yuv.z;
    float R = Y + 1.13983 * V;
    float G = Y - 0.39465 * U - 0.58060 * V;
    float B = Y + 2.03211 * U;
    return vec3(R, G, B);
}

vec3 rgb2ycocg(vec3 rgb) {
    float Y  =  0.25 * rgb.r + 0.5 * rgb.g + 0.25 * rgb.b;
    float Co =  0.5 * rgb.r - 0.5 * rgb.b;
    float Cg = -0.25 * rgb.r + 0.5 * rgb.g - 0.25 * rgb.b;
    return vec3(Y, Co, Cg);
}

vec3 ycocg2rgb(vec3 ycocg) {
    float Y  = ycocg.r;
    float Co = ycocg.g;
    float Cg = ycocg.b;
    float R = Y + Co - Cg;
    float G = Y + Cg;
    float B = Y - Co - Cg;
    return vec3(R, G, B);
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec3 uintToColor(uint id) {
    // 将 id 转换为 float 并应用散列
    float h = hash(float(id) * 0.0001);
    float hue = fract(h * 0.95); // 取 [0, 1) 范围内的色相
    float saturation = 0.6 + hash(float(id + 1)) * 0.3; // 保持较高的饱和度 [0.6, 0.9)
    float value = 0.8 + hash(float(id + 2)) * 0.2; // 保持较高的亮度 [0.8, 1.0)

    return hsv2rgb(vec3(hue, saturation, value));
}

// sRGB to linear approximation, see http://chilliant.blogspot.com/2012/08/srgb-approximations-for-hlsl.html
vec4 srgbToLinear(in vec4 sRgb)
{
    //return vec4(pow(sRgb.xyz, vec3(1.0f / 2.2f)), sRgb.w);
    //vec3 rgb = sRgb.xyz * (sRgb.xyz * (sRgb.xyz * 0.305306011F + 0.682171111F) + 0.012522878F);
    return vec4(sRgb.rgb, sRgb.a);
}

#define CONST_FUNC_H
#endif