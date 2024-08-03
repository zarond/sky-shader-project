Shader "Unlit/unlit1"
{

	Properties
	{
		//_MainTex ("Color (RGB) Alpha (A)", 2D) = "white" {}
		_3DTex ("Texture", 3D) = "white" {}
		_ExtinctionColor("Extinction Color", Color) = (1.0,1.0,1.0)
		//N("number of ray steps",int) = 48
		//Nsh("number of shadow rays",int) = 32
	}
	SubShader
	{
		//Tags { "RenderType"="Opaque" }
		Tags { "Queue"="Transparent" "RenderType"="Transparent"}
		LOD 100

		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha
		//Blend One One
		//Blend DstColor Zero

		Pass
		{
		 	Tags {"LightMode"="ForwardBase"}
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			//#pragma target 3.0


			
			#include "UnityCG.cginc"
			#include "UnityLightingCommon.cginc" // for _LightColor0
			//#include "noiseSimplex.cginc" // чужой работающий шум (что-то он медленный какой-то)

			//uniform float4x4 _CamToWorld;  //unused
			uniform vector origin;
			//uniform float4x4 World2Object; //оказалось не нужно
			uniform float3 size;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				//float4 normal : NORMAL;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1;
				//float3 worldNormal : TEXCOORD2;
			};

			//sampler2D _MainTex;
			sampler3D _3DTex;
			//sampler2D _CameraDepthTexture;
			float4 _MainTex_ST;
			float4 _ExtinctionColor;
			//int N,Nsh;

			inline float sample_density(float3 V){
				//return tex3D(_3DTex, V);
				return tex3Dlod(_3DTex, float4(V, 0));
				//return 1;
			}

			float4 sample_light(float3 V){
				return (unity_AmbientSky + _LightColor0 * max(dot(_WorldSpaceLightPos0,V),0));
			}

			inline bool boxtest(float3 V){
				return (V.x<size.x && V.x>0.0 &&
						V.y<size.y && V.y>0.0 &&
						V.z<size.z && V.z>0.0);
			//	return any(floor(abs(V-size/2)-size/2));
			}
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.ray = mul(unity_ObjectToWorld, v.vertex);
				//o.worldNormal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//float depth = tex2D(_CameraDepthTexture, i.uv).r;
				//depth = Linear01Depth(depth);
				//half4 bgcolor = tex2Dproj(_BackgroundTexture, i.grabPos);

				float3 rayDirection = normalize((i.ray - _WorldSpaceCameraPos).xyz);

				const int N=64;
				const int Nsh = 24;
				float steps = (1.74/N) * size.x;
				float shadowsteps = (1.74/Nsh) * size.x;

				float3 Vec = (dot(-_WorldSpaceCameraPos + origin,rayDirection)-0.87*size.x)*rayDirection;
				//float3 Vec = i.ray - _WorldSpaceCameraPos;
				float3 V,V2;

				float curdensity = 0;
				float cursample = 0;
				float3 lightenergy = 0;
				float transmittance = 1;
				float density = 10;
				float3 shadowdensity = 5/_ExtinctionColor;

				density*=steps;
				shadowdensity*=shadowsteps;

				//[loop]
				for (int j=0;j<N;++j){
					V =  mul(unity_WorldToObject,_WorldSpaceCameraPos + Vec - origin) + float3(0.5,0.5,0.5);
					if (boxtest(V)){
					if ((cursample = sample_density(V))>0.001)// && (length(Vec)<3))
					{
						//cursample = sample_density(V);
						float3 Vec2=0;
						float shadowdist = 0;
						//[loop]
						for (int k=0;k<Nsh;++k){
							V2 =  mul(unity_WorldToObject,_WorldSpaceCameraPos + Vec + Vec2 - origin) + float3(0.5,0.5,0.5);
							if (boxtest(V2))	shadowdist += sample_density(V2); else break;
							Vec2 += shadowsteps*normalize(_WorldSpaceLightPos0.xyz);
						}
						curdensity = saturate(cursample * density);
						float3 shadowterm = exp(-shadowdist * shadowdensity);
						float3 absorbedlight = shadowterm * curdensity;
						lightenergy += absorbedlight * transmittance;
						transmittance*=1-curdensity;
					}
					} 
					//} else break;
					Vec+=rayDirection*steps;
					//if (length(Vec)>3) break;
				}

				return fixed4(unity_AmbientSky + _LightColor0 * lightenergy,1-transmittance);

			}
			ENDCG
		}
	}
	//Fallback "Diffuse"
}
