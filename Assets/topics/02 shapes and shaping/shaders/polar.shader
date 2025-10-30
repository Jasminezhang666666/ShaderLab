Shader "shader lab/week 2/polar" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.283185
            
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

            float zigzag (float density, float height, float offset, float2 uv) {
                float shape = frac(uv.x * density); // creates vertical columns along x
                shape = min(shape, 1-shape); // converts x gradient from 0-1 to 0-0.5-0 (triangle wave)
                shape = shape * height + offset -uv.y;
                    // shape * height -> multiplication will affect the range of the triangle wave
                    // + offset -> adds lightness (shifts all values up) to the triangle wave (effects where clipping happnes)
                    // -uv.y -> uses the y gradient to create /\ shapes
                return smoothstep(0, 0.002, shape);
            }

            float4 frag (Interpolators i) : SV_Target {
                float output = 0;
                float2 uv = i.uv;
                uv = uv * 2 - 1;

                float angle = atan2(uv.y, uv.x); // angle
                float distance = length(uv);

                uv = float2(angle, distance);
                uv.x = uv.x / TAU + 0.5; // normalize angle to [0,1)
                uv.x = frac(uv.x + _Time.x); //uv.x is the angle fraction around the circle (and _Time.x rotates it)
                output = zigzag(40, 0.1, 0.4, uv);
                return float4(output.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}