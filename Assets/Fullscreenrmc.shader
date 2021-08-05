Shader "Custom/Fullscreenrmc"
{
    Properties
    {
		_3DTex("Texture", 3D) = "white" {}
        _MainTex ("Texture", 2D) = "white" {}
		_Low("Low", Float) = 500
		_High("High", Float) = 600
		_ExtinctionColor("Extinction Color", Color) = (1.0,1.0,1.0)
		_NoiseDithering("Noise dithering", 2D) = "white" {}
		_Noise1("Noise texture 1 ", 2D) = "white" {}
		_Noise2("Noise texture 2 ", 2D) = "white" {}
		_Radius("Radius of Earth", Float ) = 100000
		_Tiling1("Tiling1", Float) = 4000
		_Tiling2("Tiling2", Float) = 8000
		_DnstyM("Density Multiplier",Range(0,10)) = 1

		_N("Number of samples", Int) = 42
		_Nsh("Number of shadow samples", Int) = 6
		_density("density",Float) = 10
		_shadowdensity("shadow density",Float) = 5
		_Ambientdensity("ambient density",Float) = 0.5
		_cov("coverage", Range(0,1))=0.28

    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
		//Tags{ "LightMode" = "ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc" // for _LightColor0

			sampler3D _3DTex;
			float4 _ExtinctionColor;
			sampler2D _NoiseDithering;
			uniform float4 _NoiseDithering_TexelSize;
			float _Low;
			float _High;
			float _Radius;
			sampler2D _Noise1;
			sampler2D _Noise2;
			float _Tiling1;
			float _Tiling2;
			float _DnstyM;
			uniform int _N;
			uniform int _Nsh;
			uniform float _density;
			uniform float _shadowdensity;
			uniform float _Ambientdensity;
			uniform float _cov;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 ray: TEXCOORD1;
            };

			float4x4 clipToWorld;

			inline float rand(float3 myVector) {
				return frac(sin(_Time[0] * dot(myVector, float3(12.9898, 78.233, 45.5432))) * 43758.5453);
			}

			inline float rand1(float3 myVector) {
				return tex2D(_NoiseDithering, _Time[3] + (myVector + 0.5) * _NoiseDithering_TexelSize.xy).r;
			}

			inline float rand2(float3 myVector) {
				float2 interleavedPos = (fmod(floor(myVector.xy), 4.0));
				return tex2D(_NoiseDithering, interleavedPos / 4.0 + float2(0.5 / 4.0, 0.5 / 4.0)).w;
			}

			inline float HenyeyGreenstein(float cos_angle, float eccentricity) {
				const float pi = 3.14159;
				return ((1 - eccentricity * eccentricity) / pow((1 + eccentricity * eccentricity - 2 * eccentricity*cos_angle), 3 / 2)) / 4 * pi;
			}

			inline float sample_density(float3 V) {
				//return tex3D(_3DTex, V);
				//return tex2D(_Noise1, V.xz/2000);
				//return max(tex2D(_Noise1, V.xz / 2000)-0.28,0);
				//return tex2D(_Noise1, (V.xz + 3 * _Time[3]) / 2000) * tex2D(_Noise1, (V.xz + 2 * _Time[3]) / 8000);
				//return tex3D(_3DTex, V / 7000);
				return max(tex3D(_3DTex, V / _Tiling1) + 0.3*tex3D(_3DTex, V / _Tiling2) -_cov,0)/(1-_cov);// *(0.5 + tex3D(_3DTex, V / 2000));
				return max(tex2D(_Noise1, (V.xz + 3 * _Time[3]) / _Tiling1) - _cov, 0) / (1 - _cov);// *tex2D(_Noise2, (V.xz + 2 * _Time[3]) / _Tiling2);//
				return tex2D(_Noise1, (V.xz + 3 * _Time[3])/ _Tiling1) * tex2D(_Noise2, (V.xz + 2 * _Time[3])/ _Tiling2);
				return tex2D(_Noise1, (V.xz + 3 * _Time[3]) / _Tiling1) * tex2D(_Noise2, (V.xz + 2 * _Time[3]) / _Tiling2) * tex3D(_3DTex, V/20000);
				return 1.0;
			}

			inline float csample_density(float3 V) {
				return max(tex3D(_3DTex, V / _Tiling1) + 0.3*0.5 - _cov, 0) / (1 - _cov);// *(0.5 + tex3D(_3DTex, V / 2000));
			}

			/*float sample_density(float3 p)
			{
				float cloudHeight = _High - _Low;
				float atmoHeight = p.z;//length(p - vec3(0.0, -EARTH_RADIUS, 0.0)) - EARTH_RADIUS;
				cloudHeight = clamp((atmoHeight - _Low) / (cloudHeight), 0.0, 1.0);
				//p.z += iTime * 10.3;
				float largeWeather = clamp((tex2D(_Noise1, -0.00005*p.zx) - 0.18)*5.0, 0.0, 2.0);
				//p.x += iTime * 8.3;
				float weather = largeWeather * max(0.0, tex2D(_Noise1, 0.0002*p.zx) - 0.28) / 0.72;
				weather *= smoothstep(0.0, 0.5, cloudHeight) * smoothstep(1.0, 0.5, cloudHeight);
				float cloudShape = pow(weather, 0.3 + 1.5*smoothstep(0.2, 0.5, cloudHeight));
				if (cloudShape <= 0.0)
					return 0.0;
				//p.x += iTime * 12.3;
				//float den = max(0.0, cloudShape - 0.7*fbm(p*.01));
				float den = cloudShape;
				if (den <= 0.0)
					return 0.0;

				//p.y += iTime * 15.2;
				//den = max(0.0, den - 0.2*fbm(p*0.05));
				return largeWeather * 0.2*min(1.0, 5.0*den);
			}*/

			inline float sqr(float a) { return a * a; }
			
			inline float2 intersection(float3 ray) {
				float b = 2 * (_Radius + _WorldSpaceCameraPos.y)*ray.y;
				float c = (2 * _Radius +  _WorldSpaceCameraPos.y + _Low) * (_WorldSpaceCameraPos.y - _Low);
				float c1 = (2 * _Radius + _WorldSpaceCameraPos.y + _High) * (_WorldSpaceCameraPos.y - _High);
				c = sqr(b) - 4 * c;
				c1 = sqr(b) - 4 * c1;
				c = (c < 0) ? -1 : max((-b + sqrt(c)) * 0.5, 0);
				c1 = (c1 < 0) ? -1 : max((-b + sqrt(c1)) * 0.5, 0);
				return float2(c, c1);
			}
			inline float2 intersection1(float3 ray) {
				float b = 2 * (_Radius + _WorldSpaceCameraPos.y)*ray.y;
				float c = (2 * _Radius + _WorldSpaceCameraPos.y + _Low) * (_WorldSpaceCameraPos.y - _Low);
				float c1 = (2 * _Radius + _WorldSpaceCameraPos.y + _High) * (_WorldSpaceCameraPos.y - _High);
				c = sqr(b) - 4 * c;
				c1 = sqr(b) - 4 * c1;
				float c_,c1_;
				c_ = (c < 0) ? -1 : (-b - sqrt(c)) * 0.5;
				c = (c < 0) ? -1 : (-b + sqrt(c)) * 0.5;
				c1_ = (c1 < 0) ? -1 : (-b - sqrt(c1)) * 0.5;
				c1 = (c1 < 0) ? -1 : (-b + sqrt(c1)) * 0.5;
				if (_WorldSpaceCameraPos.y < _Low) {
					return float2(c, c1);
				}
				if (_WorldSpaceCameraPos.y >= _Low && _WorldSpaceCameraPos.y < _High) {
					return float2(0, (c_ < 0) ? c1 : c_);
				}
				//if (_WorldSpaceCameraPos.y >= _High) {
					return (c1_<0)? float2(-1,-1) : float2(c1_, (c_<0)? c1 : c_);
				//}
			}

            v2f vert (appdata v)
            {
                v2f o;

				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				float4 clip = float4(o.vertex.xy, 0.0, 1.0);
				o.ray = mul(clipToWorld, clip) - _WorldSpaceCameraPos;

                return o;
            }

            sampler2D _MainTex;
			sampler2D_float _CameraDepthTexture;
			float4 _CameraDepthTexture_ST;

			//#define _JITTER
			#define _HGFUNCTION
			//#define _GRADIENTBLEND

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv.xy);
				depth = LinearEyeDepth(depth);
				float3 worldspace = i.ray * depth + _WorldSpaceCameraPos;
				float3 rayDirection = normalize(i.ray.xyz);
				int N = _N;
				int Nsh = _Nsh;
	
				float steps = 5;
				float shadowsteps = steps;

				float3 Vec=0;
				float3 V, V2;
				float curdensity = 0;
				float cursample = 0;
				float3 lightenergy = 0;
				float transmittance = 1;
				float density = _DnstyM * _density; /// size;
				float3 shadowdensity = _DnstyM * _shadowdensity / _ExtinctionColor;//(size *_ExtinctionColor);
				float AmbientDensity = _Ambientdensity;// / size;

				// calculate number of steps;
				float2 intersect = (intersection1(rayDirection));
				//if (rayDirection.y < -0.8 || (depth - intersect.x)<0) return tex2D(_MainTex, i.uv);
				//if ((rayDirection.y < -0.02) || ((depth - intersect.x)<0 && !(abs(depth - _ProjectionParams.z)<1))) return tex2D(_MainTex, i.uv);
				if (((depth - intersect.x) < 0 && !(abs(depth - _ProjectionParams.z) < 1)) || intersect.x < -0) return tex2D(_MainTex, i.uv);
				//if (((depth - intersect.x) < 0 && !(abs(depth - _ProjectionParams.z) < 1)) || (intersect.x < 0)) return tex2D(_MainTex, i.uv);
				Vec = (intersect.x>+0)? rayDirection * intersect.x : rayDirection;
				//intersect.y = min(depth,intersect.y);
				//Vec = rayDirection * intersect.x;

				N = min((int)((intersect.y - intersect.x) / steps),N);
				N = max(N, 1);

				//Nsh = min((int)((_High-) / shadowsteps), Nsh);
				//shadowsteps = 2 * steps;
				//Nsh = max(Nsh, 1);
				//return fixed4((float3)(steps / 100), 1);

#if defined (_JITTER)
				// Temporal jitter: вещь хорошая но надо бы оптимизировать
				float Jitter = 2 * steps;
				Vec += rayDirection * rand(float3(i.uv, 1)) * Jitter;
#endif

				[loop]
				for (int j = 0; j<N; ++j) {
					V = _WorldSpaceCameraPos + Vec;
						if ((cursample = sample_density(V))>0.001)
						{
							float3 Vec2 = 0;
							float shadowdist = 0;                          
							Nsh = min((int)((_High-(_WorldSpaceCameraPos.y + Vec.y)) / (_WorldSpaceLightPos0.y * shadowsteps)), Nsh);
							Nsh = max(Nsh, 1);

							[loop]
							for (int k = 0; k < Nsh; ++k) {
								V2 = _WorldSpaceCameraPos + Vec + Vec2;
								shadowdist += csample_density(V2);
								Vec2 += shadowsteps * normalize(_WorldSpaceLightPos0.xyz);
							}

							curdensity = saturate(cursample * density);// * steps;
							float3 shadowterm = exp(-shadowdist * shadowdensity );//*shadowsteps
							float3 absorbedlight = shadowterm * curdensity;

							//lightenergy += _LightColor0 * shadowterm*(1- exp(-curdensity)) * transmittance;
							lightenergy += _LightColor0 * absorbedlight * transmittance;

							//ambient
							float cloudHeight = saturate((_WorldSpaceCameraPos.y + Vec.y - _Low) / (_High - _Low));
							//float3 ambient = (0.5 + 0.6*cloudHeight)*float3(0.2, 0.5, 1.0)*6.5 + float3(0.8,0.8,0.8) * max(0.0, 1.0 - 2.0*cloudHeight);
							float3 ambient = (0.5 + 0.6*cloudHeight);// * max(0.0, 1.0 - 2.0*cloudHeight);
							//lightenergy += (_LightColor0 * absorbedlight + ambient) * transmittance;
							lightenergy += unity_AmbientSky * exp(-AmbientDensity) * (ambient) * transmittance;
							
							//shadowdist = 0;
							//V = _WorldSpaceCameraPos + Vec + float3(0, 0, 0.05);//*size;
							//shadowdist += sample_density(V);
							//V = _WorldSpaceCameraPos + Vec + float3(0, 0, .1);// *size;
							//shadowdist += sample_density(V);
							//V = _WorldSpaceCameraPos + Vec + float3(0, 0, .2);// *size;
							//shadowdist += sample_density(V);
							////lightenergy += exp(-shadowdist * AmbientDensity) * curdensity * ShadeSH9(float4(0, 0, 0, 1)) * transmittance;
							////lightenergy += exp(-shadowdist * AmbientDensity) * curdensity * unity_AmbientSky * transmittance;
							//
							//transmittance *= exp(-curdensity);
							transmittance *= 1 - curdensity;
						}
					Vec += rayDirection * steps;
					if (transmittance < 0.01) { transmittance = 0; break; }
				}

				float3 color;
#if defined (_GRADIENTBLEND)
				float grad = pow(rayDirection.y-0.01,0.25);
				transmittance += 1 - grad;
				//return fixed4(grad, grad, grad, grad);
#endif
				//return fixed4(lightenergy, 1);
#if defined (_HGFUNCTION)
				color = lightenergy * HenyeyGreenstein(dot(normalize(_WorldSpaceLightPos0.xyz), rayDirection), 0.2);
				return fixed4(color*(1 - transmittance) + transmittance * tex2D(_MainTex, i.uv), 1);
#endif
				
				//return fixed4(lightenergy,1);
				color = lightenergy;
				return fixed4(color*(1 - transmittance) + transmittance * tex2D(_MainTex, i.uv),1);

				//float4 color = float4(rayDirection, 1.0);
				//return depth/100 + tex2D(_MainTex,i.uv);
				//return tex2D(_MainTex, i.uv);
            }
            ENDCG
        }
    }
}
