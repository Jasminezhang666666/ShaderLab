Shader "shader lab/week 7/HW7_Cube"
{
    Properties
    {
        _PaperTint      ("Paper Tint", Color) = (0.92,0.95,1.00,1)
        _FiberTex       ("Xuan Fiber (R)", 2D) = "gray" {}
        _GrainTex       ("Dry Grain (R)", 2D) = "gray" {}
        _PaperUVScale   ("Paper UV Scale", Range(4, 20)) = 12

        _CubeSize       ("Cube Half-Size (OS) (fallback)", Vector) = (0.5,0.5,0.5,0)
        _MasterSpeed    ("Master Time Scale", Range(0.1, 2)) = 0.45

        _EdgeGranular   ("Edge Granularity", Range(0,2)) = 1.2
        _RipStrength    ("Rip/Tear Intensity", Range(0,2)) = 1.3

        _WindDirDeg     ("Wind Dir (deg)", Range(0,360)) = 30
        _WindStrength   ("Wind Strength", Range(0,2)) = 0.9
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            //==================== constants ====================
            #define MAX_DROPS 16
            #define DEG2RAD 0.017453292519943295
            static const float3 INK_BLUE   = float3(0.20, 0.45, 0.95);
            static const float3 INK_YELLOW = float3(1.00, 0.90, 0.20);

            static const float  T_BLACK=0.25, T_PIXEL=2.2, T_GLOW=3.4, T_MELT=4.2, T_DRY=6.0, T_WIND=7.5;

            static const float  GLOSS=0.75, SPEC_WET_BOOST=1.5;
            static const int    POSTER_STEPS=3;

            static const float  GRAVITY_SPEED = 0.38;
            static const float  HUE_TIME_SCALE=0.18;
            static const float  YELLOW_THR=0.63, EMISS_AMP=2.0;
            static const float  EDGE_GAIN=1.5;
            static const float  ABSORB_STRENGTH=0.18;
            static const float  DROP_GLOBAL_SCALE = 0.10;

            //==================== material inputs ====================
            CBUFFER_START(UnityPerMaterial)
            float4 _PaperTint;
            float  _PaperUVScale;
            float4 _CubeSize;      // 仅作 fallback
            float  _MasterSpeed;
            float  _EdgeGranular;
            float  _RipStrength;
            float  _WindDirDeg;
            float  _WindStrength;
            float  _DropCount;     // 由 Director 设置
            CBUFFER_END

            float4 _DropPosTime[MAX_DROPS];  // (ux, -, baseR, start)
            float4 _DropParamsA[MAX_DROPS];  // (anisoPar, anisoPerp, expand, seed)

            TEXTURE2D(_FiberTex);  SAMPLER(sampler_FiberTex);
            TEXTURE2D(_GrainTex);  SAMPLER(sampler_GrainTex);

            //==================== safety helpers ====================
            float3 safeNormalize(float3 v) { float m=max(length(v),1e-6); return v/m; }
            float  safe01(float x){ return saturate(isnan(x)?0:x); }
            float2 safe01v2(float2 x){ return float2(safe01(x.x), safe01(x.y)); }

            //==================== tri-planar style UVs ====================
            struct MeshData { float4 vertex:POSITION; float3 normal:NORMAL; };
            struct Interpolators {
                float4 posCS:SV_POSITION;
                float3 posWS:TEXCOORD0;
                float3 posOS:TEXCOORD1;
                float3 nWS  :TEXCOORD2;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.posWS = TransformObjectToWorld(v.vertex.xyz);
                o.posOS = v.vertex.xyz;
                o.posCS = TransformWorldToHClip(o.posWS);
                o.nWS   = safeNormalize(TransformObjectToWorldNormal(v.normal));
                return o;
            }

            // 主导面判断：法线绝对值最大的分量对应面（稳定，不跳）
            bool IsTopFace(float3 nWS)
            {
                float ax=abs(nWS.x), ay=abs(nWS.y), az=abs(nWS.z);
                return ay >= max(ax, az);
            }

            // 用对象坐标做平面投影，若 _CubeSize 未写入，仍能工作
            float2 ProjectUV(float3 posOS, float3 nWS)
            {
                float3 h = max(_CubeSize.xyz, float3(1e-6,1e-6,1e-6)); // fallback 尺寸
                float ax=abs(nWS.x), ay=abs(nWS.y), az=abs(nWS.z);
                float2 uv;
                if (ay >= max(ax, az)) {      // top/bottom → xz
                    uv = posOS.xz/(h.xz*2.0)*0.5+0.5;
                } else if (ax > az) {         // ±X side → zy
                    uv = float2(posOS.z/(h.z*2.0)*0.5+0.5, (h.y-posOS.y)/(h.y*2.0));
                } else {                      // ±Z side → xy
                    uv = float2(posOS.x/(h.x*2.0)*0.5+0.5, (h.y-posOS.y)/(h.y*2.0));
                }
                return saturate(uv);
            }

            // 边缘遮罩（投影到当前面的 0..1 UV 决定）
            float RimMask(float2 uv){ float m = 1.0 - min(min(uv.x,1-uv.x), min(uv.y,1-uv.y))*2.0; return saturate(m); }

            //==================== noise ====================
            float hash21(float2 p){ return frac(sin(dot(p, float2(12.9898,78.233))) * 43758.5453123); }
            float valueNoise(float2 uv){ float2 ip=floor(uv), f=frac(uv);
                float a=hash21(ip), b=hash21(ip+float2(1,0)), c=hash21(ip+float2(0,1)), d=hash21(ip+float2(1,1));
                float2 u=smoothstep(0,1,f); return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y); }
            float fbm(float2 uv){ float f=1.0,a=0.5,s=0.0; [unroll]for(int i=0;i<4;i++){ s+=a*valueNoise(uv*f); f*=2.0; a*=0.5;} return s; }

            float2 FiberTangent(float2 uvTex)
            {   // 用纹理梯度估切向，方向稳定
                float e = 1.0 / max(_PaperUVScale * 256.0, 64.0);
                float2 du=float2(e,0), dv=float2(0,e);
                float fx1=SAMPLE_TEXTURE2D(_FiberTex,sampler_FiberTex,uvTex+du).r;
                float fx0=SAMPLE_TEXTURE2D(_FiberTex,sampler_FiberTex,uvTex-du).r;
                float fy1=SAMPLE_TEXTURE2D(_FiberTex,sampler_FiberTex,uvTex+dv).r;
                float fy0=SAMPLE_TEXTURE2D(_FiberTex,sampler_FiberTex,uvTex-dv).r;
                float2 grad=float2(fx1-fx0, fy1-fy0);
                return normalize(float2(-grad.y, grad.x) + 1e-5);
            }

            //==================== drop fields (top) ====================
            void TopDropContribution(float2 uvTop, float t, float2 dropUV, float baseR, float anisoPar, float anisoPerp, float expandSpeed,
                                     out float thick, out float wet, out float hueK, out float blackPulse, out float hueSeed)
            {
                baseR *= (0.75 * DROP_GLOBAL_SCALE);

                float paperL = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uvTop*_PaperUVScale).r;
                float absorb = saturate(1.0 + ABSORB_STRENGTH*(paperL-0.5));
                float R = (baseR + expandSpeed * sqrt(max(t,0))) * absorb;

                float2 dirT = FiberTangent(uvTop * _PaperUVScale);
                float2 dirN = float2(-dirT.y, dirT.x);
                float2 d = uvTop - dropUV;
                float2 proj = float2(dot(d, dirT), dot(d, dirN));
                float a = max(1e-4, anisoPar*R);
                float b = max(1e-4, anisoPerp*R);
                float fall = exp(- (proj.x*proj.x)/(a*a) - (proj.y*proj.y)/(b*b));

                float ring = saturate(1.0 - smoothstep(0.0, 1.0, length(d)/max(R,1e-4)));
                thick = saturate(0.6*fall + 0.4*ring);

                float wet0 = smoothstep(0, 0.2, fall);
                float dryK = smoothstep(T_DRY, T_DRY+1.2, t);
                wet = saturate( wet0 * (1.0 - 0.85*dryK) );

                hueK = saturate( smoothstep(0.15, 1.0, t/T_GLOW) );
                blackPulse = (t>=0 && t<=T_BLACK) ? 1.0 : 0.0;

                hueSeed = hash21(dropUV*137.2);
            }

            void AccTop(float2 uvTop, float tNow, out float thick, out float wet, out float hueK, out float blackPulse,
                        out float wPixel, out float wGlow, out float wMelt, out float wDry, out float wWind, out float hueSeed)
            {
                thick=0; wet=0; hueK=0; blackPulse=0;
                wPixel=wGlow=wMelt=wDry=wWind=0; hueSeed=0;

                int count = (int)_DropCount;
                [loop] for (int i=0;i<MAX_DROPS;i++){
                    if(i>=count) break;
                    float4 pt = _DropPosTime[i];
                    float4 pa = _DropParamsA[i];
                    float t = tNow - pt.w; if(t<0) continue;

                    float ti, wi, hk, bp, hs;
                    TopDropContribution(uvTop, t, float2(pt.x, pt.x), pt.z, pa.x, pa.y, pa.z, ti, wi, hk, bp, hs);
                    hs = frac(hs*0.5 + pa.w*0.5);

                    thick = max(thick, ti);
                    wet   = max(wet,   wi);
                    hueK  = max(hueK,  hk);
                    blackPulse = max(blackPulse, bp);
                    hueSeed = max(hueSeed, hs);

                    wPixel = max(wPixel, step(T_PIXEL, t));
                    wGlow  = max(wGlow,  step(T_GLOW,  t));
                    wMelt  = max(wMelt,  step(T_MELT,  t));
                    wDry   = max(wDry,   step(T_DRY,   t));
                    wWind  = max(wWind,  step(T_WIND,  t));
                }
            }

            float3 HueBlend(float3 blue, float3 yellow, float hueK, float NdotL, float wet, float tNow, float hueSeed)
            {
                float kL = 0.30*(1.0-NdotL);
                float kW = 0.22*(1.0-wet);
                float kT = 0.08*(0.5+0.5*sin(tNow*HUE_TIME_SCALE));
                float k  = saturate(hueK*0.6 + kL + kW + kT);

                float bias = lerp(-0.06, 0.10, hueSeed);
                float3 blueVar = saturate(blue + float3(0.0, bias, bias*0.4));
                return lerp(blueVar, yellow, k);
            }

            float Beads(float v, float seed)
            {
                float period = 0.072;
                float width  = 0.027;
                float j = frac(v / period + seed*3.17);
                float d = abs(j - 0.5);
                return smoothstep(width, width*0.35, d);
            }

            //==================== fragment ====================
            float4 frag(Interpolators i):SV_Target
            {
                // lights
                float tNow = _Time.y * _MasterSpeed;
                Light Lmain = GetMainLight();
                float3 N = safeNormalize(i.nWS);
                float3 L = safeNormalize(Lmain.direction);
                float3 V = safeNormalize(GetCameraPositionWS() - i.posWS);
                float3 Hh = safeNormalize(V + L);

                float NdotL = safe01(dot(N,L));
                float halfLambert = pow(NdotL*0.5+0.5, 2.0);

                // face / UV
                bool isTop = IsTopFace(N);
                float2 uv = ProjectUV(i.posOS, N);

                // early paper if没有滴点
                if ((int)_DropCount <= 0)
                {
                    float f = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uv*_PaperUVScale).r;
                    float3 paperCol = _PaperTint.rgb * (0.92 + 0.08*f);
                    return float4(paperCol, 1);
                }

                // TOP fields evaluated在顶面与“顶边采样”都需要，因此都算一次
                float2 uvTop = uv; // 当前面为 top 时就是顶面 uv；若是侧面，下方会用 rimU 取边缘再取一次
                float thickT, wetT, hueKT, blackPulseT, wPixelT,wGlowT,wMeltT,wDryT,wWindT, hueSeedT;
                AccTop(uvTop, tNow, thickT, wetT, hueKT, blackPulseT, wPixelT,wGlowT,wMeltT,wDryT,wWindT, hueSeedT);

                // common shading pieces
                float fiberTop = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, uvTop*_PaperUVScale).r;
                float paperAO = 0.7 + 0.3*fiberTop;

                float3 inkBaseT = HueBlend(INK_BLUE, INK_YELLOW, hueKT, NdotL, wetT, tNow, hueSeedT);
                float3 inkColT  = lerp(inkBaseT, float3(0,0,0), blackPulseT);

                float lamP = ceil(halfLambert * POSTER_STEPS) / max(POSTER_STEPS,1);
                float3 diffuseT = lamP * inkColT * Lmain.color;

                float ndh = safe01(dot(N,Hh));
                float  spec = pow(ndh, lerp(8,256,GLOSS));
                spec *= GLOSS * (0.3 + 0.7*wetT) * SPEC_WET_BOOST;
                float3 specT = spec * Lmain.color;

                float yellowGate = smoothstep(YELLOW_THR, 1.0, dot(inkBaseT, float3(0.333,0.333,0.333)));
                float eCurve = saturate(yellowGate*(0.3+0.7*thickT)*(0.2+0.8*(1.0-wetT)));
                float3 emisT = inkBaseT * eCurve * (EMISS_AMP * lerp(0.5,1.5,wGlowT));

                float grainTop = SAMPLE_TEXTURE2D(_GrainTex, sampler_GrainTex, uvTop*_PaperUVScale*2.0).r;
                float rim = RimMask(uvTop);

                float3 colorTop = (diffuseT + specT);
                colorTop = lerp(colorTop, colorTop + emisT, yellowGate);
                colorTop *= lerp(1.0, 0.8 + 0.2*grainTop, rim * _EdgeGranular);

                float ripPhase = saturate((tNow - T_DRY) / (T_WIND - T_DRY + 1.2)) * _RipStrength;
                float3 paperColTop = _PaperTint.rgb * (0.92 + 0.08*fiberTop);
                colorTop = lerp(colorTop, paperColTop, ripPhase*0.5);
                float alphaTop = 1.0 * (1.0 - ripPhase*0.4);

                // ==== side dripping using top-edge feed ====
                float3 colorSide = colorTop;
                float  alphaSide = alphaTop;
                if (!isTop)
                {
                    // 侧面 UV：u 沿边，v 顶→底
                    float u = uv.x, v = uv.y;

                    // 顶边处“取源”
                    float2 edgeTopUV = float2(u, 1.0);
                    float thickR, wetR, hueKR, blackPulseR, wp,wg,wm,wd,ww, hueSeedR;
                    AccTop(edgeTopUV, tNow, thickR, wetR, hueKR, blackPulseR, wp,wg,wm,wd,ww, hueSeedR);

                    float tFall = max(0, tNow - T_MELT);
                    float fall  = GRAVITY_SPEED * tFall * saturate(thickR);
                    float vDown = saturate(v - fall);

                    float bead   = Beads(vDown, hueSeedR) * smoothstep(0.0, 0.45, 1.0 - vDown);
                    float pixMask= (wp>0.0) ? fbm(float2(u*8.0, vDown*8.0) + tNow*0.05) : 0.0;

                    float3 baseSide = HueBlend(INK_BLUE, INK_YELLOW, hueKR, NdotL, wetR, tNow, hueSeedR) * 0.87;
                    float fiberSide = SAMPLE_TEXTURE2D(_FiberTex, sampler_FiberTex, float2(u, vDown)*_PaperUVScale).r;
                    colorSide = baseSide * (0.75 + 0.25*fiberSide);
                    colorSide *= lerp(1.0, 0.8 + 0.2*pixMask, 0.6);
                    colorSide *= saturate(bead * 1.8);

                    float wetStripe = saturate(1.0 - v*2.0);
                    float specS = pow(safe01(dot(N, safeNormalize(V+L))), 32.0) * 0.35 * wetStripe;
                    colorSide += specS * Lmain.color;

                    float edgeU = 1.0 - abs(u*2.0 - 1.0);
                    float edgeStrip = saturate(1.0 - edgeU*2.0);
                    float grainS = SAMPLE_TEXTURE2D(_GrainTex, sampler_GrainTex, float2(u, vDown)*_PaperUVScale*2.0).r;
                    colorSide *= lerp(1.0, 0.8 + 0.2*grainS, edgeStrip * _EdgeGranular);

                    // 平滑风蚀（不再闪）
                    float a = _WindDirDeg * DEG2RAD;
                    float2 W = _WindStrength * float2(cos(a), sin(a));
                    float n = valueNoise(float2(u, vDown)*64.0 + W*2.0 + tNow*0.2);
                    float erode = smoothstep(0.68, 0.92, n) * 0.6 * saturate((tNow - T_WIND)/2.0);
                    colorSide = lerp(colorSide, colorSide*0.7, erode);
                    alphaSide = 1.0 * (1.0 - erode*0.8);
                }

                // compose & final safety
                float3 color = isTop ? colorTop : colorSide;
                color *= _PaperTint.rgb;
                if (any(isnan(color))) color = _PaperTint.rgb;

                return float4(saturate(color), saturate(isTop?alphaTop:alphaSide));
            }
            ENDHLSL
        }
    }
}
