Shader "shader lab/homework/assignment 1" {
    Properties {
        _colorSun ("color Sun", Color) = (0.972549, 0.937255, 0.823529, 1)
        _colorSky1 ("color Sky 1", Color) = (1, 0, 0, 1)
        _colorSky2 ("color Sky 2", Color) = (0.5, 0, 0, 1)
        _colorSky3 ("color Sky 3", Color) = (0.25, 0, 0, 1)
        _colorSea1 ("color Sea 1", Color) = (0, 0, 1, 1)
        _colorSea2 ("color Sea 2", Color) = (0, 0, 1, 1)
        _colorSea3 ("color Sea 3", Color) = (0, 0, 1, 1)
    }
    SubShader {
        Tags {"RenderPipeline" = "UniversalPipeline"}
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float3 _colorSun;
            float3 _colorSky1;
            float3 _colorSky2;
            float3 _colorSky3;
            float3 _colorSea1;
            float3 _colorSea2;
            float3 _colorSea3;
            CBUFFER_END

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
                // you only need to work inside of this function
                
                float2 uv = i.uv; // values between 0 - 1 that you can think of as a percent of the way across either dimension on our quad.

                // here are some example colors defined to get started with. you should modify these and add more of your own.
                // the standard value range for colors is 0 - 1, below i've defined colors using values between 0-255, but then divide the whole color by 255, making them 0-1 range
                // i do this to more easily define colors that i can create and preview in applications like photoshop which displays color values 0 - 255 (because they are natively 8 bits per channel)
                //float3 color1 = float3(134, 173, 207)/255;

                float horizon = 0.5;
                float horizonMask = step(horizon, uv.y); // inverse is: 1-horizonMask

                float2 sunCenter = float2(0.5, 0.7);
                float sunRadius = 0.2;

                // distance from current pixel to the circle center
                float d = distance(uv, sunCenter);
                float blur = 0.02;
                float sunMask = smoothstep(sunRadius - blur, sunRadius + blur, d); //step(sunRadius, d); if d < radius, returns 0, otherwise 1

                // though not necessary, using the smoothstep function is an easy way to define the boundaries of your gradient.
                // this gradient driving value will be 0 below 70% of the quad height and will be 1 above 80% of the quad height.
                float gradient1Driver = smoothstep(0.6, 0.7, uv.y);

                 // this is just an example of how to use the smoothstep gradient driver calculation to blend between the two colors.
                // you will need to create many more blends of colors and will need to decide how you ultimately want to blend them all together using math.
                float3 Temp = lerp(_colorSky1, _colorSky2, gradient1Driver);
                gradient1Driver = smoothstep(0.8, 0.9, uv.y);
                float3 colorSky = lerp(Temp, _colorSky3, gradient1Driver);

                //Creating the image
                float3 output = _colorSun * (1-sunMask) + colorSky * horizonMask + _colorSea1 * (1-horizonMask);

                //sea wave
                float waveY   = 0.02 * sin(uv.x * 15.0) + horizon - 0.15; // 0.02 = amplitude, 25 = frequency
                float seaMask = step(uv.y, waveY);                 // 1 below the wave curve, 0 above
                output = lerp(output, _colorSea2, seaMask);         // paint a solid blue block up to the wavy top

                waveY = 0.03 * cos(uv.x * 20.0) + horizon - 0.3;
                seaMask = step(uv.y, waveY); 
                output = lerp(output, _colorSea3, seaMask);

                //sun's reflection
                /*
                0.02, 0.01 = ripple amplitudes

                120.0, 60.0 = vertical ripple frequencies

                0.35 = reflection intensity
                */
                float2 ruv = float2(
                    // sideways ripple
                    //0.02 amplitude, 130 frequency

                    uv.x + 0.02 * sin((horizon - uv.y)*130), 
                    // vertical reflection, ruv.y = 2*horizon - uv.y: mirrors the Y across the horizon line
                    //So if horizon = 0.5, then a point at 0.6 becomes 0.4 (mirrored above).
                    2.0 * horizon - uv.y                       
                );
                float reflMask = (1 - horizonMask) * (1 - step(sunRadius, distance(ruv, sunCenter))); // hard-edged sun mask
                /*
                distance(ruv, sunCenter): how far the reflected point is from the original sun’s center
                step(sunRadius, distance(...)): is 0 inside the sun, 1 outside.
                */
                
                // tint sea with the warped reflection, the 0.2 reduces the intensity from the original sun
                output = lerp(output, _colorSun, 0.2 * reflMask);                 

                //float3 maskTest = float3(sunMask, sunMask, sunMask); 

                return float4(output, 1.0);
            }
            ENDHLSL
        }
    }
}
