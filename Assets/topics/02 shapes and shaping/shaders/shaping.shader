Shader "shader lab/week 2/shaping" {
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

                uv = uv * 2 - 1;
                uv *= 5;
                
                
                float x = uv.x;
                float y = uv.y;

                float c = x;
                c = sin(x);
                c = cos(x);
                c = abs(x);
                c = ceil(x);
                c = floor(x);
                c = frac(x);
                c = min(x,y);
                c = max(x,y);
                c = sign(x);
                c = step(x,y);
                c = smoothstep(-2, 2, x);
                
                return float4(c.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}