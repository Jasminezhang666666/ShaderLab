Shader "shader lab/week 5/vertex animation jitter" {
    Properties {
        _displacement ("displacement", Range(0, 0.1)) = 0.05
        _timeScale ("time scale", Float) = 1
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float _scale;
            float _displacement;
            float _timeScale;
            CBUFFER_END

            float rand (float2 uv) {
                return frac(sin(dot(uv.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            float3 rand_vec (float3 pos) {
                return float3(rand(pos.xz), rand(pos.yx), rand(pos.zy)) * 2 - 1;
            }

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float disp : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;

                v.vertex.xyz += normalize(rand_vec(v.vertex.xyz + round(_Time.y * _timeScale))) * _displacement;
                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                return float4(i.uv.x, 0, i.uv.y, 1.0);
            }
            ENDHLSL
        }
    }
}