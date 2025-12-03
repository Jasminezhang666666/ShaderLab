Shader "shader lab/week 10/bullet shatter"
{
    Properties
    {
        _EffectT        ("Effect progress (0-1)", Range(0,1)) = 0
        _HoleRadius     ("Hole radius", Range(0,0.5)) = 0.06
        _CrackThickness ("Crack thickness", Range(0.001,0.1)) = 0.03
        _TileCount      ("Tile count (x,y)", Vector) = (12, 7, 0, 0)
        _FallDistance   ("Fall distance", Range(0,2)) = 0.8
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        ZWrite Off
        Cull Off
        ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _EffectT;
                float _HoleRadius;
                float _CrackThickness;
                float2 _TileCount;
                float _FallDistance;
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            struct MeshData
            {
                uint vertexID : SV_VertexID;
            };

            struct Interpolators
            {
                float4 posCS : SV_POSITION;
                float2 uv    : TEXCOORD0;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord   (v.vertexID);
                return o;
            }

            float rand(float2 n)
            {
                return frac(sin(dot(n, float2(12.9898, 78.233))) * 43758.5453);
            }

            // Very simple spider-web cracks using angle + frac
            float crackMask(float2 uv, float crackT, float holeR)
            {
                float2 c = uv - 0.5;
                float r  = length(c);

                // No cracks inside the hole
                if (r < holeR)
                    return 0.0;

                // How far cracks have spread (from hole edge outward)
                float maxR = lerp(holeR + 0.02, 1.0, crackT);
                if (r > maxR)
                    return 0.0;

                // Angle in range [0,1]
                float angle = atan2(c.y, c.x);      // [-PI, PI]
                angle = angle / (2.0 * 3.14159265) + 0.5; // [0,1]

                // Number of cracks
                const float CRACKS = 18.0;

                // Where we are between two crack directions (0 at crack, 0.5 between)
                float pos = angle * CRACKS;
                float f   = frac(pos);
                float distToLine = min(f, 1.0 - f);

                // Thickness: normalized so that distToLine == _CrackThickness → 0
                float thickness = _CrackThickness;
                float crack = 1.0 - saturate(distToLine / (thickness + 1e-4));

                // Make cracks denser near the center
                float density = saturate(1.5 - r / maxR);
                crack *= density;

                return saturate(crack);
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float2 screenUV = i.uv;
                float2 uv       = screenUV;

                float t = saturate(_EffectT);

                // Split timeline:
                // 0 → 0.7  : cracks grow
                // 0.7 → 1.0: shatter + fall
                float crackT   = saturate(t / 0.7);
                float shatterT = saturate((t - 0.7) / 0.3);

                // ----- Shatter: tile-based falling -----
                if (shatterT > 0.0)
                {
                    float2 tileCount = max(_TileCount, float2(1.0, 1.0));

                    float2 tileIndex  = floor(screenUV * tileCount);
                    float2 tileCenter = (tileIndex + 0.5) / tileCount;

                    float r1 = rand(tileIndex);
                    float r2 = rand(tileIndex + 13.37);

                    float fall = shatterT * shatterT * _FallDistance * (0.4 + 0.6 * r1);
                    float sway = (r2 - 0.5) * shatterT * 0.3;

                    float angle = (r2 - 0.5) * shatterT * 1.7;
                    float cs = cos(angle);
                    float sn = sin(angle);

                    float2 local = screenUV - tileCenter;
                    local = float2(local.x * cs - local.y * sn,
                                   local.x * sn + local.y * cs);

                    uv = tileCenter + local + float2(sway, -fall);
                }

                // Base scene
                float3 color = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv);

                // ----- Bullet hole -----
                float2 c = screenUV - 0.5;
                float r  = length(c);

                // Hole grows slightly with crackT
                float holeR = lerp(_HoleRadius * 0.8, _HoleRadius, crackT);

                float insideHole = step(r, holeR);          // 1 inside
                float edgeWidth  = _HoleRadius * 0.4;
                float ring       = 1.0 - saturate(abs(r - holeR) / (edgeWidth + 1e-4));

                // Erase inside hole
                color *= (1.0 - insideHole);

                // Bright rim
                color = lerp(color, float3(1,1,1), ring * crackT);

                // ----- Cracks -----
                float cracks = crackMask(screenUV, crackT, holeR);

                // VERY strong white cracks so you can see them
                color = lerp(color, float3(1,1,1), cracks);

                // Fade whole image slightly as it shatters
                color *= (1.0 - shatterT * 0.3);

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
