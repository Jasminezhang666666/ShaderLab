Shader "shader lab/week 2/pattern" {
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

            float circle (float radius, float2 uv) {
                float distance = length(uv);
                distance -= radius;
                float aa = 0.005;
                return 1-smoothstep(0, aa, distance);
            }

            float4 frag (Interpolators i) : SV_Target {
                float output = 0;
                float gridSize = 40;
                float2 uv = i.uv * gridSize;
                float2 gridUV = frac(uv) * 2 - 1;
                float index = floor(uv.x) + floor(uv.y);
                
                float time = _Time.z;
                gridUV.x += sin(time + index/3) * 0.5;
                gridUV.y += cos(time + index/3) * 0.5;
                
                output = circle(0.5, gridUV);
                

                // output = frac(uv.x);
                // return float4(gridUV.xy, 0, 1);
                return float4(output.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}