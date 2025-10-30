Shader "shader lab/week 3/multiple spaces" {
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define PI  3.141592654
            #define TAU 6.283185307
        
            //  function from iñigo quiles
            //  https://www.shadertoy.com/view/MsS3Wc
            float3 hsb2rgb( in float3 c ) {
                float3 rgb = saturate(abs((c.x*6.0+float3(0.0,4.0,2.0) %
                                        6.0)-3.0)-1.0);
                rgb = rgb*rgb*(3.0-2.0*rgb);
                return c.z * lerp(float3(1, 1, 1), rgb, c.y);
            }

            float rectangle (float2 uv, float2 scale) {
                float2 s = scale * 0.5;
                float2 shaper = float2(step(-s.x, uv.x), step(-s.y, uv.y));
                shaper *= float2(1-step(s.x, uv.x), 1-step(s.y, uv.y));
                return shaper.x * shaper.y;
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
                float2 uv = i.uv * 2 - 1;
                float time = _Time.z;
            
                int count = 15;   // number of shapes
                float3 color = 0; // initialize a color that we will add to as we create rectangles

                for(int j = 0; j < count; j++) {
                    float2 iUV = uv; // make a copy of the uv coordinates to modify in our for loop
                    float offset = pow(smoothstep(0, 1, frac((time + j * 0.085) * 0.1)), 4); // create an offset driven by time and the iteration we're currently drawing. 
                    
                    // get translation matrix
                    float2 t = float2(sin(offset * TAU), cos(offset * TAU)) * 0.5;
                    float3x3 tMat = translate2D(t.x, t.y);
                
                    // get rotation matrix
                    float angle = -offset * PI; // our offset goes between 0 - 1. multiplying by PI gives us a 180 degree angle rotation
                    float3x3 rMat = rotate2D(angle);

                    float3x3 compMat = mul(rMat, tMat);
                    iUV = mul(compMat, float3(iUV, 1)).xy;
                    
                    float newRect = rectangle(iUV, float2(0.4, 0.4 * 1.618)); // creating a rectangle with our uniquely transformed uv space

                    float colorOffset = sin(offset * TAU) * 0.1; // again using offset to drive change in color of our rectangle
                    float3 col = hsb2rgb(float3(colorOffset, 0.8, 0.15)); // create our color using HSB color space (hue, saturation, brightness)
                    col *= newRect; // multiply our shape (white in rectangle, black outside) by our color so that the color is only present inside the rectangle

                    color = saturate(color + col); // add our color for this iteration of a rectangle to the total color we'll output from the shader. saturate() makes sure the value is clamped between 0 - 1
                }

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}