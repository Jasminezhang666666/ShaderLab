Shader "shader lab/week 12/distance field" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                float3 color = 0;
                float2 uv = i.uv * 2 - 1;

                float d = length(uv);
                // sdf - signed distance field
                float radius = 0.66;
                d = length(uv) - radius;

                d = step(0, d);
                
                color = d;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}