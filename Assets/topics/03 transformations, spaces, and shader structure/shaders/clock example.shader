Shader "shader lab/week 3/clock example" {
    Properties {
        _hour   ("hour",   Float) = 0
        _minute ("minute", Float) = 0
        _second ("second", Float) = 0
    }

    SubShader {
        Tags { "RenderPipelien" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.283185307

            CBUFFER_START(UnityPerMaterial)
            float _hour;
            float _minute;
            float _second;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv * 2 - 1;
                float time = _Time.z;

                float2 hUV = uv;
                float hA = (atan2(hUV.y, hUV.x) / TAU) + 0.5;
                hA = frac(hA + (_hour / 12) + 0.25);

                float2 mUV = uv;
                float mA = (atan2(mUV.y, mUV.x) / TAU) + 0.5;
                mA = frac(mA + (_minute / 60) + 0.25);

                float2 sUV = uv;
                float sA = (atan2(sUV.y, sUV.x) / TAU) + 0.5;
                sA = frac(sA + (_second / 60) + 0.25);
                
                float3 color = (hA * 0.433) + (mA * 0.333) + (sA * 0.233);
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}