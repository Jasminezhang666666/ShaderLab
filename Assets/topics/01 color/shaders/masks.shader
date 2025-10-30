Shader "shader lab/week 1/masks" {
    Properties {
        [NoScaleOffset] _tex1 ("texture one", 2D) = "white" {}
        [NoScaleOffset] _tex2 ("texture two", 2D) = "white" {}
        [NoScaleOffset] _mask ("texture three", 2D) = "white" {}
    }
    SubShader {
        Tags {"RenderPipeline" = "UniversalPipeline"}
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_tex1);
            SAMPLER(sampler_tex1);
            
            TEXTURE2D(_tex2);
            SAMPLER(sampler_tex2);

            SAMPLER(sampler_mask);
            TEXTURE2D(_mask);
            
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
                float2 uv = i.uv;

                // sample the color data from each of the three textures and store them in float3 variables
                float3 t1 =   _tex1.Sample(sampler_tex1, uv).rgb;
                float3 t2 =   _tex2.Sample(sampler_tex2, uv).rgb;
                float3 mask = _mask.Sample(sampler_mask, uv).rgb;

                float3 color = 0;


                color = t1;

                color = t1 * (1-mask) + t2 * mask;
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
