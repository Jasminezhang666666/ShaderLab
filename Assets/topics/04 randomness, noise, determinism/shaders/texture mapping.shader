Shader "shader lab/week 4/texture mapping" {
    Properties {
       _tex ("texture", 2D) = "white" {}
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _tex_ST;
            CBUFFER_END

            TEXTURE2D(_tex);
            SAMPLER(sampler_tex);

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
                // mesh uv
                float2 uv = i.uv;
                float3 color = 0;


                color = _tex.Sample(sampler_tex, uv); // generic hlsl texture sample
                color = SAMPLE_TEXTURE2D(_tex, sampler_tex, TRANSFORM_TEX(uv, _tex)); // unity specific texture sample
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}