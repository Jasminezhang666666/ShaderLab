Shader "shader lab/week 1/gradient exercise" {
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
                float3 color = 0;

                // add your code here
                float3 colorA = float3(1,0,0);
                float3 colorB = float3(0,1,0);
                float3 colorC = float3(0,0,1);
                float3 colorD = float3(0.5,0.3,0.2);

                /*
                L1 = LERP (A,B, uv.x)
                L2 = LERP (C,D, uv.x)
                LERP(L1, L2, uv.y)

                */

                //color = float3(uv.x*uv.y, uv.y-0.4, 0.15);
                
                //color = float3(uv.x-0.1, 0.3*uv.y, 1/uv.y);
                
                //color = float3(0,0,0) + 0.3;
                
                //color = float3(1-uv.x, 0, 0);
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
