Shader "shader lab/week 3/translate" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass{
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float rectangle (float2 uv, float2 scale) {
                float2 s = scale * 0.5;
                float2 shaper = float2(step(-s.x, uv.x), step(-s.y, uv.y));
                shaper *= float2(1-step(s.x, uv.x), 1-step(s.y, uv.y));
                return shaper.x * shaper.y;
            }

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
                float time = _Time.x * 15;

                float3 color = 0;

                // translate
                float2 translate = float2(0, 0);
                translate.x += sin(time);
                translate.y += cos(time);
                translate *= 0.5;

                uv += translate;
                
                color = rectangle(uv, float2(0.25, 0.5));
                color += float3(uv.x, 0, uv.y);
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
