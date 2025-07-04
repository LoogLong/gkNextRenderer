import Common;

[[vk::binding(0, 0)]]
RWTexture2D<float4> InImage;

[[vk::binding(1, 0)]]
RWTexture2D<float4> OutImage;

[[vk::binding(2, 0)]]
ConstantBuffer<UniformBufferObject> Camera;

// use for jbf
[[vk::binding(3, 0)]]
RWTexture2D<float4> InAlbedo;

[[vk::binding(4, 0)]]
RWTexture2D<float4> InNormal;

[[vk::binding(5, 0)]]
RWTexture2D<uint> InVisibility0;

[[vk::binding(6, 0)]]
RWTexture2D<uint> InVisibility1;

struct PushConsts
{
    uint offset_x;
    uint offset_y;
};

[[vk::push_constant]]
ConstantBuffer<PushConsts> pushConsts;

static const int WORK_GROUP_AXIS_SIZE = 8;
static const int WINDOW_R = 3; // HALF SIZE, must be even, 8 is a 17 x 17 sobel
static const int WINDOW_LEN = WORK_GROUP_AXIS_SIZE + 2 * WINDOW_R;

// Shared memory arrays
groupshared float3 window[WINDOW_LEN][WINDOW_LEN];
groupshared float3 albedo[WINDOW_LEN][WINDOW_LEN];
groupshared float3 normal[WINDOW_LEN][WINDOW_LEN];
groupshared uint visibility[WINDOW_LEN][WINDOW_LEN];

float3 FetchColor(int2 ipos)
{
    return window[ipos.x][ipos.y] + float3(0.001, 0.001, 0.001);
}

float3 FetchAlbedo(int2 ipos)
{
    return albedo[ipos.x][ipos.y] + float3(0.001, 0.001, 0.001);
}

float3 FetchNormal(int2 ipos)
{
    return normal[ipos.x][ipos.y];
}

uint FetchVisibility(int2 ipos)
{
    return visibility[ipos.x][ipos.y];
}

void JBF(int2 coord, int2 localCoord, inout float3 Total, inout float Weight, float CenterLum, float3 CenterNormal, uint CenterVisibility)
{
    const float sigma = Camera.BFSigma; // spatial sigma
    const float sigmaL = Camera.BFSigmaLum * 100.0; // 
    const float sigmaN = Camera.BFSigmaNormal;
    const int N = int(WINDOW_R); // filter size
    
    const float3 FinalCol = FetchColor(coord);
    const float3 Ci = FinalCol / FetchAlbedo(coord);
    const float3 Ni = FetchNormal(coord);
    const uint Pi = FetchVisibility(coord);
    const float lumi = dot(Ci, float3(0.212671f, 0.715160f, 0.072169f));

    const float dist = clamp(float(localCoord.x * localCoord.x + localCoord.y * localCoord.y) / float(N * N), 0.0, 1.0);
    const float normaldist = 1.0 - dot(Ni, CenterNormal);
    const float dlum = (CenterLum - lumi) * (CenterLum - lumi);

    const float Fi = exp(-dist * dist / (2.0 * sigma * sigma));
    const float Ai = exp(-normaldist * normaldist / (2.0 * sigmaN * sigmaN));
    const float Li = exp(-dlum * dlum / (2.0 * sigmaL * sigmaL));
    const float Oi = float(CenterVisibility == Pi);
    
    Total += Ci * Fi * Li * Ai * Oi;
    Weight += Fi * Li * Ai * Oi;
}

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 dispatchThreadId: SV_DispatchThreadID, 
                 uint3 groupThreadId: SV_GroupThreadID,
                 uint3 groupId: SV_GroupID,
                 uint groupIndex: SV_GroupIndex)
{
    const int2 globalOffset = int2(Camera.ViewportRect.xy);
    const int2 ipos = int2(dispatchThreadId.xy) + globalOffset;
    bool isEvenFrame = false; // Camera.TotalFrames % 2 == 0 ? true : false;

    float3 Total = float3(0, 0, 0);
    
    if(Camera.BFSize > 0)
    {
        // share memory
        int row = int(groupIndex / WINDOW_LEN);
        int col = int(groupIndex % WINDOW_LEN);
        int2 coord = int2(groupId.xy) * WORK_GROUP_AXIS_SIZE + int2(col - WINDOW_R, row - WINDOW_R) + globalOffset;
        window[row][col] = InImage[coord].rgb;
        albedo[row][col] = InAlbedo[coord].rgb;
        normal[row][col] = InNormal[coord].rgb;
        visibility[row][col] = isEvenFrame ? InVisibility1[coord].r : InVisibility0[coord].r;
        
        int idx = int(groupIndex + WORK_GROUP_AXIS_SIZE * WORK_GROUP_AXIS_SIZE);
        while (idx < WINDOW_LEN * WINDOW_LEN)
        {
            row = idx / WINDOW_LEN;
            col = idx % WINDOW_LEN;
            coord = int2(groupId.xy) * WORK_GROUP_AXIS_SIZE + int2(col - WINDOW_R, row - WINDOW_R) + globalOffset;
            window[row][col] = InImage[coord].rgb;
            albedo[row][col] = InAlbedo[coord].rgb;
            normal[row][col] = InNormal[coord].rgb;
            visibility[row][col] = isEvenFrame ? InVisibility1[coord].r : InVisibility0[coord].r;

            idx += WORK_GROUP_AXIS_SIZE * WORK_GROUP_AXIS_SIZE;
        }
        GroupMemoryBarrierWithGroupSync();
        // now, the WINDOW_R + WINDOW_R range pixel is in the shared memory
        // free to access

        coord = int2(groupThreadId.yx) + WINDOW_R;
        
        const float3 CenterColor = FetchColor(coord.xy).rgb;
        const float3 CenterAlbedo = FetchAlbedo(coord.xy).rgb;
        const float3 DemodulateColor = CenterColor / CenterAlbedo;

        const float3 Normal = FetchNormal(coord.xy).rgb;
        uint current_primitive_index = FetchVisibility(coord.xy);

        const float CenterLum = dot(DemodulateColor, float3(0.212671f, 0.715160f, 0.072169f));

        float Weight = 0;
        for (int i = -WINDOW_R; i <= WINDOW_R; i += 3)
        {
            for (int j = -WINDOW_R; j <= WINDOW_R; j += 3)
            {
                JBF(coord.xy + int2(i, j), int2(i, j), Total, Weight, CenterLum, Normal, current_primitive_index);
            }
        }
        Total /= Weight;
        Total = Total * CenterAlbedo;
    }
    else
    {
        Total = InImage[ipos].rgb;
    }

    if(Camera.DebugDraw_Lighting)
    {
        float3 albedoValue = InAlbedo[ipos].rgb;
        Total = Total / (albedoValue + float3(0.001));
    }
    
    if(Camera.HDR)
    {
        OutImage[ipos + int2(pushConsts.offset_x, pushConsts.offset_y)] = float4(LinearToST2084UE(Total * Camera.PaperWhiteNit / 230.0), 1.0);
    }
    else
    {
        OutImage[ipos + int2(pushConsts.offset_x, pushConsts.offset_y)] = float4(Uncharted2_Tonemapping(Total * Camera.PaperWhiteNit / 20000.0), 1.0);
    }
}