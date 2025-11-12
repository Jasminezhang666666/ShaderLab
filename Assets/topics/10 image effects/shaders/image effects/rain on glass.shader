Shader "shader lab/week 10/rain lenses advanced"
{
    Properties
    {
        _LensStrength     ("lens strength", Range(0, 2))        = 1.0
        _CellCount        ("droplet grid count", Range(4, 80))  = 24

        _MinRadius        ("min big radius", Range(0.001,0.1))  = 0.012
        _MaxRadius        ("max big radius", Range(0.005,0.2))  = 0.035

        _SmallRadiusScale ("small radius scale", Range(0.1,1))  = 0.45
        _SmallRatio       ("small drop ratio", Range(0,1))      = 0.7

        _MaxRain          ("max rain density", Range(0,1))      = 0.3
        _RainSpeed        ("rain grow speed", Range(0,1))       = 0.06

        _DropCycleSpeed   ("drop cycle speed", Range(0,1))      = 0.25
        _FallDistance     ("fall distance", Range(0,1))         = 0.22

        _EdgeSoftness     ("edge softness", Range(0.1, 4))      = 2.0
        _FresnelPower     ("fresnel rim power", Range(0.1,8))   = 3.0
        _FresnelIntensity ("fresnel intensity", Range(0,0.5))   = 0.12
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

            CBUFFER_START(UnityPerMaterial)
            float _LensStrength;
            float _CellCount;

            float _MinRadius;
            float _MaxRadius;

            float _SmallRadiusScale;
            float _SmallRatio;

            float _MaxRain;
            float _RainSpeed;

            float _DropCycleSpeed;
            float _FallDistance;

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

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            // simple 2D hash
            float2 hash22(float2 p)
            {
                float n = sin(dot(p, float2(41.0, 289.0)));
                return frac(float2(262144.0, 32768.0) * n);
            }

            // strongest drop affecting this pixel
            void FindBestDrop(
                float2 uv,
                float  globalRain,
                out float  bestMask,
                out float2 bestSampleUV,
                out float  bestDistNorm,
                out float2 bestNormal2D
            )
            {
                bestMask      = 0.0;
                bestSampleUV  = uv;
                bestDistNorm  = 0.0;
                bestNormal2D  = float2(0.0, 1.0);

                if (globalRain <= 0.0001)
                    return;

                float cells = _CellCount;
                float2 gridPos = uv * cells;
                float2 cellId  = floor(gridPos);

                // explore 3x3 neighborhood of cells
                [unroll]
                for (int j = -1; j <= 1; j++)
                {
                    for (int i = -1; i <= 1; i++)
                    {
                        float2 id = cellId + float2(i, j);

                        float2 rndA = hash22(id);
                        float2 rndB = hash22(id + float2(17.0, 53.0));
                        float2 rndC = hash22(id + float2(101.0, 7.0));

                        // 1) gradually enable cells over time
                        float appear = rndA.x; // 0..1
                        if (globalRain < appear)
                            continue;

                        // 2) some cells never get drops
                        if (rndA.y > _MaxRain)
                            continue;

                        // 3) drop size: small vs big
                        bool  isSmall    = (rndB.x < _SmallRatio);
                        float baseRadius = lerp(_MinRadius, _MaxRadius, rndB.y);
                        if (isSmall)
                            baseRadius *= _SmallRadiusScale;

                        // 4) base center inside cell, keep away from screen edges a bit
                        float2 centerLocal = rndB * 0.5 + 0.25; // [0.25,0.75]
                        float2 centerBase  = (id + centerLocal) / cells;

                        // 5) per-drop cycle (0..1), looping
                        float life = frac(_Time.y * _DropCycleSpeed + rndC.x * 10.0);

                        float2 center = centerBase;
                        float  aspect = 1.0; // ~round

                        if (!isSmall)
                        {
                            // three phases: round → stretched falling → round-ish again
                            const float p1 = 0.25;
                            const float p2 = 0.8;

                            if (life < p1)
                            {
                                // just landed: slightly squishy but almost round
                                float t = life / p1;
                                aspect = lerp(0.95, 1.1, t);
                            }
                            else if (life < p2)
                            {
                                // falling straight down & stretching
                                float t = (life - p1) / (p2 - p1);
                                aspect  = lerp(1.0, 1.8, t);
                                float fall = t * _FallDistance;
                                center.y -= fall;
                            }
                            else
                            {
                                // near bottom: stops moving, becomes more round again
                                float t = (life - p2) / (1.0 - p2);
                                aspect  = lerp(1.8, 1.1, t);
                                center.y -= _FallDistance;
                            }

                            // clamp to screen so big drops don’t get totally chopped
                            center.y = clamp(center.y, 0.0 + baseRadius, 1.0 - baseRadius);
                        }

                        float2 rel = uv - center;

                        // slightly irregular outline – very low amplitude so it’s not “六边形”
                        float2 relShape = float2(rel.x * aspect, rel.y / aspect);
                        float angle = atan2(relShape.y, relShape.x); // -pi..pi

                        float wobble1 = sin(angle * 2.0 + rndA.x * 6.2831853);
                        float wobble2 = cos(angle * 3.0 + rndA.y * 6.2831853);
                        float irregular = 1.0 + 0.06 * (0.5 * wobble1 + 0.5 * wobble2);

                        float dist     = length(relShape);
                        float distNorm = dist / (baseRadius * irregular); // 1 at edge

                        if (distNorm > 1.0)
                            continue;

                        float mask = saturate(1.0 - pow(distNorm, _EdgeSoftness));
                        if (mask <= bestMask)
                            continue;

                        // lens mapping: sample from *outside* the drop, upside-down
                        float nd = saturate(distNorm);                // 0 center, 1 rim
                        float lensPower = (1.0 - nd * nd);           // strong in center
                        float2 dir = (dist > 1e-4) ? (rel / dist) : float2(0,0);

                        // sample outside the mask along dir, scaled by radius
                        float offsetMag = baseRadius * _LensStrength * lensPower;
                        float2 uvSample = center - dir * offsetMag;  // minus = flipped

                        bestMask     = mask;
                        bestSampleUV = uvSample;
                        bestDistNorm = distNorm;

                        float2 n2d = relShape;
                        float lenN = max(length(n2d), 1e-4);
                        bestNormal2D = n2d / lenN; // outward 2D normal
                    }
                }
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float2 uv = i.uv;

                float3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;

                // global rain factor: 0 = dry, 1 = fully rainy
                float globalRain = saturate(_RainSpeed * _Time.y);

                float  bestMask;
                float2 lensUV;
                float  bestDistNorm;
                float2 bestNormal2D;
                FindBestDrop(uv, globalRain, bestMask, lensUV, bestDistNorm, bestNormal2D);

                if (bestMask <= 0.0001)
                    return float4(baseColor, 1.0);

                lensUV = clamp(lensUV, float2(0.001, 0.001), float2(0.999, 0.999));
                float3 lensColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, lensUV).rgb;

                // clear water: just refracted background inside the drop
                float3 color = lerp(baseColor, lensColor, bestMask);

                // --- directional Fresnel rim ---
                // edge factor: 0 at center, 1 near rim
                float edge = saturate(bestDistNorm);
                float rimThickness = pow(edge, _FresnelPower);  // tighten to rim
                rimThickness *= bestMask;                       // fade outside drop

                // approximate 2D normal & light direction (from top-right)
                float2 N2 = normalize(bestNormal2D);
                float2 L2 = normalize(float2(0.6, 0.8));  // light from upper-right

                // white highlight on side facing light
                float lightTerm = saturate(dot(N2, L2));       // top-right rim
                float whiteRim  = lightTerm * rimThickness * _FresnelIntensity;

                // dark rim on opposite side (lower-left)
                float darkTerm  = saturate(dot(N2, -L2));
                float blackRim  = darkTerm * rimThickness * (_FresnelIntensity * 0.75);

                color += whiteRim;
                color -= blackRim;

                color = saturate(color);

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
