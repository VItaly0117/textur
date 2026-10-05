#ifndef VORONOI_INCLUDED
#define VORONOI_INCLUDED

static const float VORONOI_TWO_PI = 6.28318530718;

// Sin-free hash based on Dave Hoskins hash22, offset by seed.
// Returns a pseudorandom float2 in the range [0, 1).
float2 VoronoiHash22(float2 p, float seed)
{
    p += float2(seed, seed * 1.61803398);
    float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}

// Calculates distance based on selected metric.
// 0 = Euclidean, 1 = Manhattan, 2 = Chebyshev.
float VoronoiDistance(float2 d, int metric)
{
    if (metric == 1)
    {
        return abs(d.x) + abs(d.y);
    }
    if (metric == 2)
    {
        return max(abs(d.x), abs(d.y));
    }
    return length(d);
}

// 3x3 neighborhood search for closest (f1) and second closest (f2) feature points.
// Tracks the integer cell coordinates of the closest point.
void VoronoiF1F2(float2 uv, float jitter, float seed, float time, int metric, out float f1, out float f2, out float2 cellId)
{
    float2 n = floor(uv);
    float2 f = frac(uv);
    
    f1 = 8.0;
    f2 = 8.0;
    cellId = float2(0.0, 0.0);
    
    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            float2 g = float2(float(x), float(y));
            float2 h = VoronoiHash22(n + g, seed);
            
            float2 animatedOffset = 0.5 + 0.5 * sin(time + VORONOI_TWO_PI * h);
            float2 o = lerp(float2(0.5, 0.5), animatedOffset, jitter);
            
            float2 r = g + o - f;
            float d = VoronoiDistance(r, metric);
            
            if (d < f1)
            {
                f2 = f1;
                f1 = d;
                cellId = n + g;
            }
            else if (d < f2)
            {
                f2 = d;
            }
        }
    }
}

// Exact border distance based on Inigo Quilez's algorithm (Euclidean metric only).
// Uses a 3x3 search for nearest point, then 5x5 around it for exact edge distance.
float VoronoiEdgeDist(float2 uv, float jitter, float seed, float time)
{
    float2 n = floor(uv);
    float2 f = frac(uv);
    
    float2 mg = float2(0.0, 0.0);
    float2 mr = float2(0.0, 0.0);
    float md = 8.0;
    
    for (int j = -1; j <= 1; j++)
    {
        for (int i = -1; i <= 1; i++)
        {
            float2 g = float2(float(i), float(j));
            float2 h = VoronoiHash22(n + g, seed);
            
            float2 animatedOffset = 0.5 + 0.5 * sin(time + VORONOI_TWO_PI * h);
            float2 o = lerp(float2(0.5, 0.5), animatedOffset, jitter);
            
            float2 r = g + o - f;
            float d = dot(r, r);
            
            if (d < md)
            {
                md = d;
                mr = r;
                mg = g;
            }
        }
    }
    
    md = 8.0;
    for (int jj = -2; jj <= 2; jj++)
    {
        for (int ii = -2; ii <= 2; ii++)
        {
            float2 g = mg + float2(float(ii), float(jj));
            float2 h = VoronoiHash22(n + g, seed);
            
            float2 animatedOffset = 0.5 + 0.5 * sin(time + VORONOI_TWO_PI * h);
            float2 o = lerp(float2(0.5, 0.5), animatedOffset, jitter);
            
            float2 r = g + o - f;
            
            if (dot(mr - r, mr - r) > 0.00001)
            {
                float dist = dot(0.5 * (mr + r), normalize(r - mr));
                md = min(md, dist);
            }
        }
    }
    return md;
}

// Combines F1, F2, and edge distance into a final scalar value.
// Mode 0: F1, Mode 1: F2, Mode 2: F2-F1, Mode 3: Edge cracks.
float CombineVoronoi(float f1, float f2, float edge, int mode, float edgeWidth)
{
    if (mode == 0)
    {
        return saturate(f1);
    }
    if (mode == 1)
    {
        return saturate(f2);
    }
    if (mode == 2)
    {
        return saturate(f2 - f1);
    }
    if (mode == 3)
    {
        return saturate(1.0 - smoothstep(0.0, max(edgeWidth, 1e-4), edge));
    }
    return 0.0;
}

#endif
