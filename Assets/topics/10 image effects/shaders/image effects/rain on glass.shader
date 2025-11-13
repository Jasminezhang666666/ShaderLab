Shader "shader lab/week 10/rain combined drops"
{
    Properties
    {
        _LensStrength     ("lens strength", Range(0, 2))        = 1.2

        _CellCount        ("droplet grid count", Int)           = 16

        // Smaller drops overall
        _MinRadius        ("min radius", Range(0.001,0.1))      = 0.0035
        _MaxRadius        ("max radius", Range(0.005,0.2))      = 0.011

        _SmallRatio       ("small drop ratio", Range(0,1))      = 0.9

        // Fewer total active drops
        _MaxRain          ("max rain density", Range(0,1))      = 0.2
        _RainSpeed        ("rain grow speed", Range(0,1))       = 0.08

        _FallSpeed        ("big fall speed", Range(0,2))        = 0.6
        _StretchMin       ("big min stretch", Range(1,3))       = 1.2
        _StretchMax       ("big max stretch", Range(1,5))       = 2.6

        _EdgeSoftness     ("edge softness", Range(0.5, 4))      = 2.0

        _FresnelPower     ("fresnel rim power", Range(0.5,8))   = 3.0
        _FresnelIntensity ("fresnel intensity", Range(0,1))     = 0.28
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }

        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_CELLS 24   // safety cap for loops

            CBUFFER_START(UnityPerMaterial)
            float _LensStrength;

            int   _CellCount;
            float _MinRadius;
            float _MaxRadius;

            float _SmallRatio;
            float _MaxRain;
            float _RainSpeed;

            float _FallSpeed;
            float _StretchMin;
            float _StretchMax;

            float _EdgeSoftness;

            float _FresnelPower;
            float _FresnelIntensity;
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

            Interpolators vert(MeshData v)
            {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            float2 hash22(float2 p)
            {
                float n = sin(dot(p, float2(41.0, 289.0)));
                return frac(float2(262144.0, 32768.0) * n);
            }

            // Many small static drops, a few bigger ones sliding straight DOWN.
            // For each pixel we keep ONLY the lowest drop (smallest center.y).
            void ComputeDropField(
                float2 uv,
                float  globalRain,
                out float  outMask,
                out float2 outLensUV,
                out float  outDistNorm,
                out float2 outNormal2D
            )
            {
                outMask      = 0.0;
                outLensUV    = uv;
                outDistNorm  = 0.0;
                outNormal2D  = float2(0.0, 1.0);

                if (globalRain <= 0.0)
                    return;

                int N = _CellCount;
                N = clamp(N, 1, MAX_CELLS);
                float Nf = (float)N;

                // spawn phase: fills up, then stops adding new drops
                float spawnPhase = saturate(globalRain / 0.6);

                // winner at this pixel = drop with SMALLEST center.y (closest to bottom)
                float bestMask      = 0.0;
                float bestCenterY   = 10.0;   // start high, we look for smaller
                float2 bestNormal   = float2(0.0, 1.0);
                float  bestDistNorm = 0.0;
                float2 bestLensOff  = float2(0.0, 0.0);

                for (int gy = 0; gy < MAX_CELLS; gy++)
                {
                    if (gy >= N) break;

                    for (int gx = 0; gx < MAX_CELLS; gx++)
                    {
                        if (gx >= N) break;

                        float2 id = float2(gx, gy);

                        float2 rndA = hash22(id);
                        float2 rndB = hash22(id + float2(17.0, 53.0));
                        float2 rndC = hash22(id + float2(101.0, 7.0));

                        // spawn over time, but capped by spawnPhase
                        if (spawnPhase < rndA.x)
                            continue;

                        // density cap
                        if (rndA.y > _MaxRain)
                            continue;

                        float baseRadius = lerp(_MinRadius, _MaxRadius, rndA.y);

                        bool isSmall = (rndB.x < _SmallRatio);

                        float2 centerBase = (id + rndB) / Nf;
                        float2 center     = centerBase;

                        bool isBigMoving = (!isSmall && baseRadius > lerp(_MinRadius, _MaxRadius, 0.6));

                        float stretchY = 1.0;

                        if (isBigMoving)
                        {
                            float speed = _FallSpeed * (0.6 + rndC.x * 0.8);
                            float t = frac(_Time.y * speed + rndC.y); // 0..1

                            float bigFactor     = saturate((baseRadius - _MinRadius) / (_MaxRadius - _MinRadius));
                            float stretchFactor = lerp(_StretchMin, _StretchMax, bigFactor);
                            stretchFactor       = lerp(1.0, stretchFactor, spawnPhase);
                            stretchY            = stretchFactor;

                            // move from ABOVE top edge (y > 1) to BELOW bottom edge (y < 0)
                            float margin = baseRadius * stretchY;
                            margin = min(margin, 0.45);

                            float startY = 1.0 + margin;  // off top
                            float endY   = -margin;       // off bottom

                            // as t increases, y DECREASES (top → bottom)
                            center.y = lerp(startY, endY, t);
                        }
                        else
                        {
                            // static dots clamped inside screen
                            center.y = clamp(center.y, baseRadius, 1.0f - baseRadius);
                        }

                        float2 rel      = uv - center;
                        float2 relShape = float2(rel.x, rel.y / stretchY);

                        float d = length(relShape);
                        if (d > baseRadius)
                            continue;

                        float dn   = d / baseRadius; // 0 center, 1 edge
                        float mask = saturate(1.0 - pow(dn, _EdgeSoftness));
                        if (mask <= 0.0)
                            continue;

                        float2 n2d = (d > 1e-4) ? (relShape / d) : float2(0.0, 1.0);

                        // Lens: clear inside, upside-down distortion
                        float lensPower = (1.0 - dn * dn);
                        float2 dir = (length(rel) > 1e-4) ? normalize(rel) : float2(0.0, 1.0);
                        float offsetMag = baseRadius * _LensStrength * lensPower;
                        float2 lensOffset = -dir * offsetMag;

                        // --- collision rule: keep the LOWER drop (smaller y) at this pixel ---
                        if (mask > 0.0 && center.y < bestCenterY)
                        {
                            bestCenterY   = center.y;
                            bestMask      = mask;
                            bestNormal    = n2d;
                            bestDistNorm  = dn;
                            bestLensOff   = lensOffset;
                        }
                    }
                }

                if (bestMask <= 0.0)
                    return;

                outMask      = bestMask;
                outNormal2D  = bestNormal;
                outDistNorm  = bestDistNorm;
                outLensUV    = uv + bestLensOff;
            }

            float4 frag(Interpolators i) : SV_Target
            {
                float2 uv = i.uv;
                float3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;

                // global rain grows, but spawn stops increasing after ~0.6
                float globalRain = saturate(_RainSpeed * _Time.y);

                float  mask;
                float2 lensUV;
                float  distNorm;
                float2 normal2D;
                ComputeDropField(uv, globalRain, mask, lensUV, distNorm, normal2D);

                if (mask <= 0.0001)
                    return float4(baseColor, 1.0);

                lensUV = clamp(lensUV, float2(0.001, 0.001), float2(0.999, 0.999));
                float3 lensColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, lensUV).rgb;

                // clear water: background visible but refracted where drops are
                float3 color = lerp(baseColor, lensColor, mask);

                // ---- Fresnel: dark up/left, bright bottom ----
                float edge    = saturate(distNorm);         // 0 center, 1 rim
                float rimBase = pow(edge, _FresnelPower);

                float2 N2 = normalize(normal2D);

                float darkUp   = saturate( N2.y);
                float darkLeft = saturate(-N2.x);
                float darkTerm = saturate(0.6 * darkUp + 0.4 * darkLeft);

                float whiteDown  = saturate(-N2.y);
                float whiteRight = saturate( N2.x);
                float whiteTerm  = saturate(0.7 * whiteDown + 0.3 * whiteRight);

                float whiteRim = rimBase * whiteTerm * _FresnelIntensity;
                float blackRim = rimBase * darkTerm  * _FresnelIntensity;

                color += whiteRim;   // bright lower side
                color -= blackRim;   // darker upper/left

                color = saturate(color);

                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
