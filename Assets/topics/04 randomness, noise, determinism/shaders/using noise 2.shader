Shader "shader lab/week 4/using noise 2" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.28318530718
            
            float rectangle (float2 uv, float2 scale) {
                float2 s = scale * 0.5;
                float2 shaper = float2(step(-s.x, uv.x), step(-s.y, uv.y));
                shaper *= float2(1-step(s.x, uv.x), 1-step(s.y, uv.y));
                return shaper.x * shaper.y;
            }

            float rand (float2 uv) {
                return frac(sin(dot(uv.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            float value_noise (float2 uv) {
                float2 ipos = floor(uv);
                float2 fpos = frac(uv); 
                
                float o  = rand(ipos);
                float x  = rand(ipos + float2(1, 0));
                float y  = rand(ipos + float2(0, 1));
                float xy = rand(ipos + float2(1, 1));

                float2 smooth = smoothstep(0, 1, fpos);
                return lerp( lerp(o,  x, smooth.x), 
                             lerp(y, xy, smooth.x), smooth.y);
            }

            float3x3 translate2D (float x, float y) {
                return float3x3 (
                    1, 0, x,
                    0, 1, y,
                    0, 0, 1
                );
            }

            float3x3 rotate2D (float angle) {
                float s = sin(angle);
                float c = cos(angle);
                return float3x3 (
                    c, -s,  0,
                    s,  c,  0,
                    0,  0,  1
                );
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
                float time = _Time.y;

                float x =   value_noise(float2( time, 1   )) - 0.5;
                float y =   value_noise(float2(-time, time)) - 0.5;
                float rot = value_noise(float2( time, time)) - 0.5;

                float2 uv = i.uv * 2 - 1;
                
                // create translation matrix with x and y values from our noise function
                float3x3 tMat = translate2D(x, y);

                // create rotation matrix using noise value
                float angle = rot * TAU;
                float3x3 rMat = rotate2D(angle);
                
                // apply transformations
                float3x3 compMat = mul(rMat, tMat);
                uv = mul(compMat, float3(uv, 1)).xy;
                
                float3 color = 0;

                // view uv
                color += float3(uv.x, 0, uv.y);
                
                // create rectangle using the transformed uv coordinates
                float rect = rectangle(uv, float2(0.2, 0.35));
                color += rect.rrr;
                
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}