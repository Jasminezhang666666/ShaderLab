Shader "shader lab/week 10/rain combined drops"
{
    Properties
    {
        // how many screen pixels to shift sampling horizontally
        _RefractionPixels ("refraction pixels", Range(0, 40)) = 10
        _SphereStrength   ("sphere distortion", Range(0, 3))  = 1.0

        _CellCount        ("droplet grid count", Int)           = 16

        _MinRadius        ("min radius", Range(0.001,0.1))      = 0.0035
        _MaxRadius        ("max radius", Range(0.005,0.2))      = 0.011

        _SmallRatio       ("small drop ratio", Range(0,1))      = 0.9

        _MaxRain          ("max rain density", Range(0,1))      = 0.2
        _RainSpeed        ("rain grow speed", Range(0,1))       = 0.08

        _FallSpeed        ("big fall speed", Range(0,2))        = 0.6
        _StretchMin       ("big min stretch", Range(1,3))       = 1.2
        _StretchMax       ("big max stretch", Range(1,5))       = 3.0

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

            #define MAX_CELLS 24

            CBUFFER_START(UnityPerMaterial)
            float _RefractionPixels;
            float _SphereStrength;

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

            float4 _BlitTexture_TexelSize; // (1/width,1/height,width,height)
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            struct MeshData { uint vertexID : SV_VertexID; };

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

            // outLensUV is now just a dummy (we don't use it anymore)
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

                int   N  = clamp(_CellCount, 1, MAX_CELLS);
                float Nf = (float)N;

                float spawnPhase = saturate(globalRain / 0.6);

                float  bestMask      = 0.0;
                float  bestCenterY   = 10.0;
                float2 bestNormal    = float2(0.0, 1.0);
                float  bestDistNorm  = 0.0;
                bool   bestIsMoving  = false;

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

                        if (spawnPhase < rndA.x)  continue;
                        if (rndA.y > _MaxRain)    continue;

                        float baseRadius = lerp(_MinRadius, _MaxRadius, rndA.y);

                        bool   isSmall    = (rndB.x < _SmallRatio);
                        float2 centerBase = (id + rndB) / Nf;
                        float2 center     = centerBase;

                        bool isBigMoving = (!isSmall && baseRadius > lerp(_MinRadius, _MaxRadius, 0.6));
                        bool isMoving    = isBigMoving;

                        float stretchY   = 1.0;
                        float isLineDrop = 0.0;

                        if (isBigMoving)
                        {
                            float baseSpeed = _FallSpeed * (0.6 + rndC.x * 0.8);

                            isLineDrop = (rndC.y < 0.3) ? 1.0 : 0.0;

                            // line drops fall faster, ellipses slower
                            float speed = (isLineDrop > 0.5) ? baseSpeed : (baseSpeed * 0.5);
                            float t     = frac(_Time.y * speed + rndC.y);

                            float bigFactor     = saturate((baseRadius - _MinRadius) / (_MaxRadius - _MinRadius));
                            float stretchFactor = lerp(_StretchMin, _StretchMax, bigFactor);
                            stretchFactor       = lerp(1.0, stretchFactor, spawnPhase);

                            float tailMul = lerp(1.0, 2.7, isLineDrop);
                            stretchY      = stretchFactor * tailMul;

                            float margin = min(baseRadius * stretchY, 0.45);
                            float startY = 1.0 + margin;
                            float endY   = -margin;
                            center.y     = lerp(startY, endY, t);
                        }
                        else
                        {
                            center.y = clamp(center.y, baseRadius, 1.0f - baseRadius);
                        }

                        float2 rel      = uv - center;
                        float2 relShape = float2(rel.x, rel.y / stretchY);

                        float d  = length(relShape);
                        float dn = d / baseRadius;
                        float mask;

                        if (isLineDrop > 0.5)
                        {
                            // line drop: head + rounded tail
                            float lineRadius = baseRadius * 1.35;

                            float headRadius = lineRadius * 0.55;
                            float headOffset = -headRadius * 0.3;
                            float2 pHead     = float2(rel.x, rel.y - headOffset);
                            float headD      = length(pHead) / headRadius;
                            float headMask   = saturate(1.0 - pow(headD, _EdgeSoftness));

                            float tailLen = max(lineRadius * (stretchY - 1.0), lineRadius * 0.6);
                            float cutY    = headOffset + headRadius * 0.2;

                            float tailMask = 0.0;
                            if (rel.y > cutY)
                            {
                                float tailMidY = cutY + tailLen * 0.5;

                                float2 pTail = float2(
                                    rel.x / headRadius,             // half-width = headRadius
                                    (rel.y - tailMidY) / tailLen
                                );

                                // superellipse (rounded rectangle)
                                float px = abs(pTail.x);
                                float py = abs(pTail.y);
                                float p  = 3.0;
                                float se = pow(px, p) + pow(py, p);
                                tailMask = saturate(1.0 - se);
                            }

                            float shapeMask = max(headMask, tailMask);
                            if (shapeMask <= 0.0)
                                continue;

                            mask = shapeMask;
                            dn   = 1.0 - shapeMask;
                        }
                        else
                        {
                            // ellipses / round drops
                            float effRadius = baseRadius;
                            if (isMoving)              // falling ellipses thinner
                                effRadius = baseRadius * 0.65;

                            if (d > effRadius)
                                continue;

                            dn   = d / effRadius;
                            mask = saturate(1.0 - pow(dn, _EdgeSoftness));
                            if (mask <= 0.0)
                                continue;
                        }

                        float2 n2d = (d > 1e-4) ? (relShape / max(d, 1e-4)) : float2(0.0, 1.0);

                        if (isMoving)
                        {
                            float overlapThreshold = 0.25;

                            if (!bestIsMoving)
                            {
                                if (mask > overlapThreshold || bestMask == 0.0)
                                {
                                    bestIsMoving = true;
                                    bestMask      = mask;
                                    bestCenterY   = center.y;
                                    bestNormal    = n2d;
                                    bestDistNorm  = dn;
                                }
                            }
                            else
                            {
                                if (center.y < bestCenterY || mask > bestMask)
                                {
                                    bestMask      = mask;
                                    bestCenterY   = center.y;
                                    bestNormal    = n2d;
                                    bestDistNorm  = dn;
                                }
                            }
                        }
                        else
                        {
                            if (!bestIsMoving)
                            {
                                if (mask > bestMask || center.y < bestCenterY)
                                {
                                    bestMask      = mask;
                                    bestCenterY   = center.y;
                                    bestNormal    = n2d;
                                    bestDistNorm  = dn;
                                }
                            }
                        }
                    }
                }

                if (bestMask <= 0.0)
                    return;

                outMask      = bestMask;
                outNormal2D  = bestNormal;
                outDistNorm  = bestDistNorm;
                outLensUV    = uv;    // dummy, not used anymore
            }

            float4 frag(Interpolators i) : SV_Target
            {
                float2 uv        = i.uv;
                float3 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv).rgb;

                float globalRain = saturate(_RainSpeed * _Time.y);

                float  mask;
                float2 dummyUV;
                float  distNorm;
                float2 normal2D;
                ComputeDropField(uv, globalRain, mask, dummyUV, distNorm, normal2D);

                if (mask <= 0.0001)
                    return float4(baseColor, 1.0);

                // --- refraction sampling ---
                float2 texel = _BlitTexture_TexelSize.xy;

                // left half of screen samples to the left, right half samples to the right
                float sideSign = (uv.x < 0.5) ? -1.0 : 1.0;
                float2 baseSampleUV = uv + float2(sideSign * _RefractionPixels * texel.x, 0.0);

                // spherical distortion inside the drop
                float r       = saturate(distNorm);        // 0 center, 1 rim
                float sphere  = (1.0 - r * r);            // stronger towards center
                float2 n2     = normalize(normal2D);      // radial direction

                // flip along radial dir to fake "upside-down" image
                float2 sphereOffset =
                    -n2 * sphere * _SphereStrength * _RefractionPixels * texel.x;

                float2 finalUV = baseSampleUV + sphereOffset;
                finalUV = clamp(finalUV, float2(0.001, 0.001), float2(0.999, 0.999));

                float3 lensColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, finalUV).rgb;

                // clear water: refracted background where drops are
                float3 color = lerp(baseColor, lensColor, mask);

                // Fresnel: dark up/left, bright down/right
                float edge    = saturate(distNorm);
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

                return float4(color, 1.0);
            }

            ENDHLSL
        }
    }
}
