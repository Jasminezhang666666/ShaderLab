Shader "shader lab/week 3/compound transformations" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.283185307

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

                // translation
                float x = sin(time) * 0.5;
                float y = cos(time) * 0.5;
                float3x3 translate2D = float3x3(
                    1, 0, x,
                    0, 1, y,
                    0, 0, 1
                );


                // scale
                float scaleMagnitude = sin(time * 2) + 2;
                float2 sc = scaleMagnitude;
                float3x3 scale2D = float3x3 (
                    sc.x, 0, 0,
                    0, sc.y, 0,
                    0,    0, 1
                );

                // rotation
                float angle = frac(time * 0.5) * TAU;
                float s = sin(angle);
                float c = cos(angle);
                float3x3 rotation2D = float3x3 (
                    c, -s, 0,
                    s,  c, 0,
                    0,  0, 1
                );

                float3x3 composite = mul(mul(rotation2D, scale2D), translate2D);
                uv = mul(composite, float3(uv, 1));

                
                color = rectangle(uv, float2(0.25, 0.5));
                color += float3(uv.x, 0, uv.y);

                // color = mul(composite, color);
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}