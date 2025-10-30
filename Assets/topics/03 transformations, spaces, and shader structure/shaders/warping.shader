Shader "shader lab/week 3/warping" {
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
            
            float circle (float2 uv, float size) {
                return smoothstep(0.0, 0.005, 1 - length(uv) / size);
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv * 2 - 1;
                float time = _Time.y;

                float3 color = 0;

                float warpStrength = 0.33;
                uv += cos(uv.yx + float2(time, 1.5)) * warpStrength;
                uv += sin(uv.yx + float2(0, time * 3)) * warpStrength;
                
                float circ = circle(uv, 0.5);

                color = circ;
                color += float3(uv.x, 0, uv.y);
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}