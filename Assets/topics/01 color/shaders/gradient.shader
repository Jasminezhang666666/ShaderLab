Shader "shader lab/week 1/gradient" {
    SubShader {
        Tags {"RenderPipeline" = "UniversalPipeline"}
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
                float2 uv = i.uv;

                float3 color = float3(uv.x, 0.0, uv.y);
                color = float3(uv.x * 5, uv.y, 0.0);
                //color = uv.yxx; //uv.x 也就是 uv.xxx, uv.xyx 也就是 float3(uv.x, uv.y, uv.x)
                
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
