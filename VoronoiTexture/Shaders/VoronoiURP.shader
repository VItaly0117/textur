Shader "Custom/VoronoiURP"
{
    Properties
    {
        _Scale("Scale", Float) = 8
        _Jitter("Jitter", Range(0, 1)) = 1
        _Seed("Seed", Float) = 0
        _AnimSpeed("Anim Speed", Float) = 0.5
        [KeywordEnum(F1, F2, F2MinusF1, Edges)] _Mode("Mode", Float) = 3
        [Enum(Euclidean, 0, Manhattan, 1, Chebyshev, 2)] _Metric("Metric", Float) = 0
        _EdgeWidth("Edge Width", Range(0.001, 0.5)) = 0.05
        _Contrast("Contrast", Range(0.1, 4)) = 1
        _ColorA("Color A", Color) = (0.05, 0.05, 0.08, 1)
        _ColorB("Color B", Color) = (0.9, 0.6, 0.3, 1)
        _EdgeColor("Edge Color", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _MODE_F1 _MODE_F2 _MODE_F2MINUSF1 _MODE_EDGES

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Voronoi.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Scale;
                float _Jitter;
                float _Seed;
                float _AnimSpeed;
                float _Mode;
                float _Metric;
                float _EdgeWidth;
                float _Contrast;
                half4 _ColorA;
                half4 _ColorB;
                half4 _EdgeColor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 p = input.uv * _Scale;
                float t = _Time.y * _AnimSpeed;
                
                int metric = (int)_Metric;
                
                float f1, f2;
                float2 cellId;
                VoronoiF1F2(p, _Jitter, _Seed, t, metric, f1, f2, cellId);
                
                float edge = 1.0;
                #if defined(_MODE_EDGES)
                    edge = VoronoiEdgeDist(p, _Jitter, _Seed, t);
                #endif
                
                int mode = 0;
                #if defined(_MODE_F1)
                    mode = 0;
                #elif defined(_MODE_F2)
                    mode = 1;
                #elif defined(_MODE_F2MINUSF1)
                    mode = 2;
                #elif defined(_MODE_EDGES)
                    mode = 3;
                #endif
                
                float v = CombineVoronoi(f1, f2, edge, mode, _EdgeWidth);
                v = saturate(pow(saturate(v), _Contrast));
                
                half4 finalColor;
                
                #if defined(_MODE_EDGES)
                    float2 hash = VoronoiHash22(cellId, _Seed);
                    half4 cellBaseColor = lerp(_ColorA, _ColorB, hash.x);
                    finalColor = lerp(cellBaseColor, _EdgeColor, v);
                #else
                    finalColor = lerp(_ColorA, _ColorB, v);
                #endif
                
                finalColor.a = 1.0;
                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
