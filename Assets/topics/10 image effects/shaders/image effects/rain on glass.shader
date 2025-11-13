Shader "shader lab/week 10/rain on glass"
{
    Properties
    {
        // Screen-space refraction: how far (in pixels) to shift sampling left/right
        _RefractionPixels ("refraction pixels", Range(0, 40)) = 10

        // Grid resolution for spawning droplets (N x N cells)
        _CellCount        ("droplet grid count", Int)          = 16

        // Radius range for drops (in UV space)
        _MinRadius        ("min radius", Range(0.001,0.1))     = 0.0035
        _MaxRadius        ("max radius", Range(0.005,0.2))     = 0.011

        // Ratio of small static drops vs big moving ones
        _SmallRatio       ("small drop ratio", Range(0,1))     = 0.9

        // Overall rain appearance over time
        _MaxRain          ("max rain density", Range(0,1))     = 0.2
        _RainSpeed        ("rain grow speed", Range(0,1))      = 0.08

        // Movement for falling drops
        _FallSpeed        ("big fall speed", Range(0,2))       = 0.6

        // Simple stretch controls (instead of min/max/stretch factors)
        _LineStretch      ("line drop stretch", Range(1,5))    = 3.0  // how long streaks are
        _OvalStretch      ("oval drop stretch", Range(1,3))    = 1.5  // how tall falling ovals are

        // Fresnel-style highlights around the drops
        _FresnelPower     ("fresnel rim power", Range(0.5,8))  = 3.0
        _FresnelIntensity ("fresnel intensity", Range(0,1))    = 0.28

        // Fog / condensation parameters
        _FogStrength     ("fog strength", Range(0, 2))         = 0.8
        _FogGrowSpeed    ("fog grow speed", Range(0, 1))       = 0.15
        _FogTint         ("fog tint", Color)                   = (0.92, 0.95, 0.98, 0.4)
        // Use alpha of _FogTint to control max fog opacity
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
            #pragma vertex   vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_CELLS 24

            CBUFFER_START(UnityPerMaterial)
            // Refraction
            float _RefractionPixels;

            // Drop spawning / size
            int   _CellCount;
            float _MinRadius;
            float _MaxRadius;

            float _SmallRatio;
            float _MaxRain;
            float _RainSpeed;

            // Falling motion
            float _FallSpeed;
            float _LineStretch;
            float _OvalStretch;

            // Fresnel
            float _FresnelPower;
            float _FresnelIntensity;

            // Fog
            float  _FogStrength;
            float  _FogGrowSpeed;
            float4 _FogTint;

            // Blit texture size: (1/width, 1/height, width, height)
            float4 _BlitTexture_TexelSize;
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

            // Fullscreen triangle vertex
            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            // Simple 2D hash: takes a cell id and gives back two pseudo-random values in [0,1)
            float2 hash22 (float2 p)
            {
                float n = sin(dot(p, float2(41.0, 289.0)));
                return frac(float2(262144.0, 32768.0) * n);
            }

            // Computes the "best" droplet at this pixel:
            //  - outMask: how strongly we are inside a drop
            //  - outDistNorm: normalized distance to the drop edge (0 center → 1 rim)
            //  - outNormal2D: approximate 2D normal on the drop shape
            void ComputeDropField(
                float2 uv,
                float  globalRain,
                out float  outMask,
                out float  outDistNorm,
                out float2 outNormal2D
            )
            {
                // Default: no droplet here
                outMask     = 0.0;
                outDistNorm = 0.0;
                outNormal2D = float2(0.0, 1.0);

                if (globalRain <= 0.0)
                    return;

                int   N  = clamp(_CellCount, 1, MAX_CELLS);
                float Nf = (float)N;

                // As rain time increases, more cells are allowed to spawn drops
                float spawnPhase = saturate(globalRain / 0.6);

                // "Best" droplet candidate at this pixel
                float  bestMask     = 0.0;
                float  bestCenterY  = 10.0;
                float2 bestNormal   = float2(0.0, 1.0);
                float  bestDistNorm = 0.0;
                bool   bestIsMoving = false;

                // Fixed edge softness for all shapes
                float edgePow = 2.0;

                // Loop over a grid of potential drops
                for (int gy = 0; gy < MAX_CELLS; gy++)
                {
                    if (gy >= N) break;

                    for (int gx = 0; gx < MAX_CELLS; gx++)
                    {
                        if (gx >= N) break;

                        float2 id = float2(gx, gy);

                        // Three independent random vectors for this cell
                        float2 rndA = hash22(id);
                        float2 rndB = hash22(id + float2(17.0, 53.0));
                        float2 rndC = hash22(id + float2(101.0, 7.0));

                        // Only spawn this cell after a certain "spawn phase"
                        if (spawnPhase < rndA.x)
                            continue;

                        // Clamp density so we don't spawn too many drops
                        if (rndA.y > _MaxRain)
                            continue;

                        // Radius based on random value
                        float baseRadius = lerp(_MinRadius, _MaxRadius, rndA.y);

                        // Decide small vs big
                        bool   isSmall    = (rndB.x < _SmallRatio);
                        float2 centerBase = (id + rndB) / Nf;
                        float2 center     = centerBase;

                        // Large non-small drops become candidates for movement
                        bool isBigMoving = (!isSmall && baseRadius > lerp(_MinRadius, _MaxRadius, 0.6));
                        bool isMoving    = isBigMoving;

                        float stretchY   = 1.0;
                        float isLineDrop = 0.0;

                        // Position + stretching
                        if (isBigMoving)
                        {
                            // Basic falling speed with some random variation
                            float baseSpeed = _FallSpeed * (0.6 + rndC.x * 0.8);

                            // Some big drops become long streaks
                            isLineDrop = (rndC.y < 0.3) ? 1.0 : 0.0;

                            // Streaks fall faster, ordinary ovals are slower
                            float speed = (isLineDrop > 0.5) ? baseSpeed : (baseSpeed * 0.5);

                            // Looping time for each drop, offset per cell so they’re not synced
                            float t = frac(_Time.y * speed + rndC.y);

                            // Simple stretch control instead of min/max curves
                            float lineStretch = _LineStretch;
                            float ovalStretch = _OvalStretch;

                            float stretchFactor = (isLineDrop > 0.5) ? lineStretch : ovalStretch;
                            stretchFactor       = lerp(1.0, stretchFactor, spawnPhase);

                            stretchY = stretchFactor;

                            // Move from above the top edge to below the bottom edge
                            float margin = min(baseRadius * stretchY, 0.45);
                            float startY = 1.0 + margin;
                            float endY   = -margin;
                            center.y     = lerp(startY, endY, t);
                        }
                        else
                        {
                            // Static drops stay on the glass
                            center.y = clamp(center.y, baseRadius, 1.0f - baseRadius);
                        }

                        // Position of pixel relative to this drop center
                        float2 rel      = uv - center;
                        float2 relShape = float2(rel.x, rel.y / stretchY);

                        float d  = length(relShape);
                        float dn = d / baseRadius;

                        float mask;
                        float distNormLocal;

                        //  SHAPE BRANCHES

                        // Moving line drop:
                        // rounded head at the bottom
                        // rounded-rectangle-like tail behind
                        if (isMoving && isLineDrop > 0.5)
                        {
                            float lineRadius = baseRadius * 1.35;

                            // Round head (slightly offset upward so it bulges at bottom)
                            float headRadius = lineRadius * 0.55;
                            float headOffset = -headRadius * 0.3;
                            float2 pHead     = float2(rel.x, rel.y - headOffset);
                            float headD      = length(pHead) / headRadius;
                            float headMask   = saturate(1.0 - pow(headD, edgePow));

                            // Tail: a vertical superellipse (a rounded rectangle)
                            float tailLen = max(lineRadius * (stretchY - 1.0), lineRadius * 0.6);
                            float cutY    = headOffset + headRadius * 0.2;

                            float tailMask = 0.0;
                            if (rel.y > cutY)
                            {
                                float tailMidY = cutY + tailLen * 0.5;

                                float2 pTail = float2(
                                    rel.x / headRadius,
                                    (rel.y - tailMidY) / tailLen
                                );

                                float px = abs(pTail.x);
                                float py = abs(pTail.y);
                                float p  = 3.0;
                                float se = pow(px, p) + pow(py, p);
                                tailMask = saturate(1.0 - se);
                            }

                            // Combine head and tail
                            float shapeMask = max(headMask, tailMask);
                            if (shapeMask <= 0.0)
                                continue;

                            mask          = shapeMask;
                            distNormLocal = 1.0 - shapeMask; // 0 = center, 1 = edge
                        }
                        // Moving oval drop: simple stretched ellipse
                        else if (isMoving)
                        {
                            float effRadius = baseRadius * 0.8;
                            float2 relOval  = float2(rel.x, rel.y / stretchY);
                            float dOval     = length(relOval);

                            if (dOval > effRadius)
                                continue;

                            float dnOval = dOval / effRadius;
                            mask         = saturate(1.0 - pow(dnOval, edgePow));
                            if (mask <= 0.0)
                                continue;

                            distNormLocal = dnOval;
                        }
                        // Static "blob" drop: union of 1–4 overlapped circles
                        else
                        {
                            float r0 = baseRadius;

                            // 40% single drops, 60% multi-lobe blobs
                            float comboRand = rndC.x;
                            int   lobeCount = 1;
                            if (comboRand >= 0.4)
                            {
                                if      (comboRand < 0.7) lobeCount = 2;
                                else if (comboRand < 0.9) lobeCount = 3;
                                else                     lobeCount = 4;
                            }

                            // Main lobe at center
                            float2 o0 = float2(0.0, 0.0);

                            // Lobe slightly below
                            float2 o1 = float2(
                                lerp(-0.15, 0.15, rndB.x) * r0,
                                lerp( 0.4,  0.9,  rndB.y) * r0
                            );

                            // Lobe slightly above
                            float2 o2 = float2(
                                lerp(-0.15, 0.15, rndA.x) * r0,
                               -lerp( 0.4,  0.8,  rndA.y) * r0
                            );

                            // Optional extra lobe further down (for longer shapes)
                            float2 rndExtra = hash22(id + float2(9.0, 9.0));
                            float2 o3 = float2(
                                lerp(-0.12, 0.12, rndExtra.x) * r0,
                                lerp( 1.0,  1.8,  rndExtra.y) * r0
                            );

                            float dMin = 9999.0;

                            float d0 = length(rel - o0);
                            dMin = min(dMin, d0);

                            if (lobeCount > 1)
                            {
                                float d1 = length(rel - o1);
                                dMin = min(dMin, d1);
                            }
                            if (lobeCount > 2)
                            {
                                float d2 = length(rel - o2);
                                dMin = min(dMin, d2);
                            }
                            if (lobeCount > 3)
                            {
                                float d3 = length(rel - o3);
                                dMin = min(dMin, d3);
                            }

                            // Outside all lobes
                            if (dMin > r0)
                                continue;

                            distNormLocal = dMin / r0; // 0 center, 1 rim
                            mask          = saturate(1.0 - pow(distNormLocal, edgePow));
                            if (mask <= 0.0)
                                continue;
                        }

                        // 2D "normal" on the droplet shape (used for Fresnel + refraction)
                        float lenShape = max(length(relShape), 1e-4);
                        float2 n2d     = (lenShape > 0.0) ? (relShape / lenShape)
                                                          : float2(0.0, 1.0);

                        // Choose which droplet "wins" at this pixel
                        if (isMoving)
                        {
                            // Moving drops: prefer them when overlap is strong, and among those, prefer the lower one (smaller center.y)
                            float overlapThreshold = 0.25;

                            if (!bestIsMoving)
                            {
                                if (mask > overlapThreshold || bestMask == 0.0)
                                {
                                    bestIsMoving = true;
                                    bestMask     = mask;
                                    bestCenterY  = center.y;
                                    bestNormal   = n2d;
                                    bestDistNorm = distNormLocal;
                                }
                            }
                            else
                            {
                                if (center.y < bestCenterY || mask > bestMask)
                                {
                                    bestMask     = mask;
                                    bestCenterY  = center.y;
                                    bestNormal   = n2d;
                                    bestDistNorm = distNormLocal;
                                }
                            }
                        }
                        else
                        {
                            // Static drops only compete when no moving drop won yet
                            if (!bestIsMoving)
                            {
                                if (mask > bestMask || center.y < bestCenterY)
                                {
                                    bestMask     = mask;
                                    bestCenterY  = center.y;
                                    bestNormal   = n2d;
                                    bestDistNorm = distNormLocal;
                                }
                            }
                        }
                    }
                }

                // If nothing was selected, stay empty
                if (bestMask <= 0.0)
                    return;

                outMask     = bestMask;
                outNormal2D = bestNormal;
                outDistNorm = bestDistNorm;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float2 uv        = i.uv;
                float3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;

                // Global rain factor: more time → more drops
                float globalRain = saturate(_RainSpeed * _Time.y);

                // Fog base factor (time driven)
                float fogGrow = saturate(_FogGrowSpeed * _Time.y);
                float fogBase = fogGrow * _FogStrength;

                // Never let fog become fully opaque
                fogBase = min(fogBase, 0.6);

                // Use fog tint alpha as an extra overall opacity control
                fogBase *= saturate(_FogTint.a);

                // Sample droplet field
                float  mask;
                float  distNorm;
                float2 normal2D;
                ComputeDropField(uv, globalRain, mask, distNorm, normal2D);

                // No drop here → only fog over the background
                if (mask <= 0.0001)
                {
                    float3 colorNoDrops = baseColor;

                    if (fogBase > 0.0001)
                    {
                        colorNoDrops = lerp(colorNoDrops, _FogTint.rgb, fogBase);
                    }

                    return float4(colorNoDrops, 1.0);
                }

                // Refraction sampling under drops
                float2 texel    = _BlitTexture_TexelSize.xy;
                float  sideSign = (uv.x < 0.5) ? -1.0 : 1.0;

                // Left half of screen refracts from the left, right half from the right
                float2 baseUV = uv + float2(sideSign * _RefractionPixels * texel.x, 0.0);

                // No extra sphere bulge now – just the side refraction
                float2 finalUV = clamp(baseUV, float2(0.001, 0.001), float2(0.999, 0.999));
                float3 lensColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, finalUV).rgb;

                // Clear water → lerp from baseColor to refracted color, using drop mask
                float3 color = lerp(baseColor, lensColor, mask);

                // Fresnel: dark up/left, bright down/right edges
                float edge    = saturate(distNorm); // 0 center → 1 rim
                float rimBase = pow(edge, _FresnelPower);

                float2 N2 = normalize(normal2D);

                float darkUp   = saturate( N2.y);
                float darkLeft = saturate(-N2.x);
                float darkTerm = saturate(0.05 * darkUp + 0.95 * darkLeft);

                float whiteDown  = saturate(-N2.y);
                float whiteRight = saturate( N2.x);
                float whiteTerm  = saturate(0.7 * whiteDown + 0.3 * whiteRight);

                float whiteRim = rimBase * whiteTerm * _FresnelIntensity;
                float blackRim = rimBase * darkTerm  * _FresnelIntensity;

                color += whiteRim;
                color -= blackRim;

                color = saturate(color);

                //  FOG / CONDENSATION OVER GLASS
                //  grows over time
                //  cleared inside drops
                //  slightly less fog above drops (using normal2D.y)
                if (fogBase > 0.0001)
                {
                    // Simple clearing radius and trail strength baked in
                    float fogClearRadius = 1.6;
                    float fogTrailBoost  = 1.0;

                    // Clear around the drop center based on a scaled distance
                    float scaledR = saturate(distNorm / max(fogClearRadius, 0.0001));
                    float clearAroundDrop = saturate(1.0 - scaledR * scaledR); // 1 in center → 0 outward

                    // Extra fog clearing above the drop, so it leaves a little "trail"
                    float upFactor  = saturate(-normal2D.y); // 1 above center, 0 below
                    float trailMask = clearAroundDrop * upFactor * fogTrailBoost;

                    float clearFactor = saturate(clearAroundDrop + trailMask);

                    // Local fog is weaker near the drop / its trail
                    float fogLocal = fogBase * (1.0 - clearFactor);

                    color = lerp(color, _FogTint.rgb, fogLocal);
                }

                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
