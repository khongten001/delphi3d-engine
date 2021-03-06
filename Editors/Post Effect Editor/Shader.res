        ��  ��                  :  @   ��
 S H A D E R G L O B A L S . F X         0 	        cbuffer global : register(b0)
{
  float4x4 View, Projection;
  float3 DirectionalLightDir;
  float4 DirectionalLightColor;
  float3 Ambient;
  float3 CameraPosition, CameraUp, CameraLeft, CameraDirection;
  float2 viewport_size;
};

#define MAX_BONES 66

static const float PI = 3.14159265f;

#define GAUSS_0 {0.44198, 0.27901}
#define GAUSS_1 {0.250301, 0.221461, 0.153388}
#define GAUSS_2 {0.214607, 0.189879, 0.131514, 0.071303}
#define GAUSS_3 {0.20236, 0.179044, 0.124009, 0.067234, 0.028532}
#define GAUSS_4 {0.198596, 0.175713, 0.121703, 0.065984, 0.028002, 0.0093}

#define GAUSS_0_ADDITIVE {1.0, 0.63127}
#define GAUSS_1_ADDITIVE {1.0, 0.88478, 0.61281}
#define GAUSS_2_ADDITIVE {1.0, 0.88478, 0.61281, 0.33224}
#define GAUSS_3_ADDITIVE {1.0, 0.88478, 0.61281, 0.33224, 0.14099}
#define GAUSS_4_ADDITIVE {1.0, 0.88478, 0.61281, 0.33224, 0.14099, 0.04683}

float sqr(float value){
  return value*value;
}

float3 BeleuchtungsBerechnung(float3 Normale,float3 Licht){
  //normale Beleuchtung + Ambient
  //Berechnung ist physikalisch falsch sieht aber besser aus
  float Diffus = saturate(dot(Normale,Licht))*1.5;
  float InverseDiffus = saturate(dot(Normale,-Licht))*1.5;
  return (Diffus+Ambient*(InverseDiffus-Diffus+1)+Ambient);
}

float3 BeleuchtungsBerechnungMitSchatten(float3 Normale,float3 Licht, float Shadowstrength){
  //normale Beleuchtung + Ambient
  //Berechnung ist physikalisch falsch sieht aber besser aus
  float Diffus = saturate(dot(Normale,Licht))*1.5 * (1-Shadowstrength);
  float InverseDiffus = saturate(dot(Normale,-Licht))*1.5;
  return (Diffus+Ambient*(InverseDiffus-Diffus+1)+Ambient);
}

/////////////////////////////////////////////
// HSV //////////////////////////////////////
/////////////////////////////////////////////

float MinComponent(float3 v)
{
    float t = (v.x<v.y) ? v.x : v.y;
    t = (t<v.z) ? t : v.z;
    return t;
}

float MaxComponent(float3 v)
{
    float t = (v.x>v.y) ? v.x : v.y;
    t = (t>v.z) ? t : v.z;
    return t;
}

float3 RGBToHSV(float3 RGB)
{
    float3 HSV = 0;
    float minVal = MinComponent(RGB);
    float maxVal = MaxComponent(RGB);
    float delta = maxVal - minVal;             
    HSV.z = maxVal;
    if (delta != 0) {            // If gray, leave H & S at zero
       HSV.y = delta / maxVal;
       float3 delRGB;
       delRGB = ( ( ( maxVal.xxx - RGB ) / 6.0 ) + ( delta / 2.0 ) ) / delta;
       if      ( RGB.x == maxVal ) HSV.x = delRGB.z - delRGB.y;
       else if ( RGB.y == maxVal ) HSV.x = ( 1.0/3.0) + delRGB.x - delRGB.z;
       else if ( RGB.z == maxVal ) HSV.x = ( 2.0/3.0) + delRGB.y - delRGB.x;
       if ( HSV.x < 0.0 ) { HSV.x += 1.0; }
       if ( HSV.x > 1.0 ) { HSV.x -= 1.0; }
    }
    return (HSV);
}

float3 HSVToRGB(float3 HSV)
{
    float3 RGB = HSV.z;
    if ( HSV.y != 0 ) {
       float var_h = HSV.x * 6;
       float f = frac(var_h);
       float p = HSV.z * (1.0 - HSV.y);
       float q = HSV.z * (1.0 - HSV.y * f);
       float t = HSV.z * (1.0 - HSV.y * (1.0 - f));
       if      (var_h < 1) { RGB = float3(HSV.z, t, p); }
       else if (var_h < 2) { RGB = float3(q, HSV.z, p); }
       else if (var_h < 3) { RGB = float3(p, HSV.z, t); }
       else if (var_h < 4) { RGB = float3(p, q, HSV.z); }
       else if (var_h < 5) { RGB = float3(t, p, HSV.z); }
       else if (var_h < 6) { RGB = float3(HSV.z, p, q); }
       else                { RGB = float3(HSV.z, t, p); }
   }
   return (RGB);
}

// from : http://www.chilliant.com/rgb2hsv.html

float3 HUEtoRGB(in float H)
{
  float R = abs(H * 6 - 3) - 1;
  float G = 2 - abs(H * 6 - 2);
  float B = 2 - abs(H * 6 - 4);
  return saturate(float3(R,G,B));
}

float Epsilon = 1e-10;

float3 RGBtoHCV(in float3 RGB)
{
  // Based on work by Sam Hocevar and Emil Persson
  float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
  float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
  float C = Q.x - min(Q.w, Q.y);
  float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
  return float3(H, C, Q.x);
}

// The weights of RGB contributions to luminance.
// Should sum to unity.
float3 HCYwts = float3(0.299, 0.587, 0.114);

float3 HCYtoRGB(in float3 HCY)
{
  float3 RGB = HUEtoRGB(HCY.x);
  float Z = dot(RGB, HCYwts);
  if (HCY.z < Z)
  {
      HCY.y *= HCY.z / Z;
  }
  else if (Z < 1)
  {
      HCY.y *= (1 - HCY.z) / (1 - Z);
  }
  return (RGB - Z) * HCY.y + HCY.z;
}

float3 RGBtoHCY(in float3 RGB)
{
  float3 HCV = RGBtoHCV(RGB);
  float Y = dot(RGB, HCYwts);
  if (HCV.y != 0)
  {
    float Z = dot(HUEtoRGB(HCV.x), HCYwts);
    if (Y > Z)
    {
      Y = 1 - Y;
      Z = 1 - Z;
    }
    HCV.y *= Z / Y;
  }
  return float3(HCV.x, HCV.y, Y);
}

float3 RGBtoHSL(in float3 RGB)
{
  float3 HCV = RGBtoHCV(RGB);
  float L = HCV.z - HCV.y * 0.5;
  float S = HCV.y / (1 - abs(L * 2 - 1) + Epsilon);
  return float3(HCV.x, S, L);
}

float3 HSLtoRGB(in float3 HSL)
{
  float3 RGB = HUEtoRGB(HSL.x);
  float C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
  return (RGB - 0.5) * C + HSL.z;
}

/////////////////////////////////////////////
// Generate texturecoordinates //////////////
/////////////////////////////////////////////

/*
  Converts a Normal to a texturecoordinate for a sphere with only a normal 2D-Texture.
*/
float2 SphereMap(float3 Normal)
{
   return float2(atan2(Normal.x,Normal.z)/(2*PI) + 0.5,(asin(-Normal.y)/PI + 0.5));
}

/*
  Converts a Normal to a texturecoordinate for a cubemap with only a normal 2D-Texture. Should be optimized.
*/
float2 CubeMap(float3 Normal){
  float2 newTex;
  float3 absNormal = float3(abs(Normal.x),abs(Normal.y),abs(Normal.z));
  float3 tempNormal = (Normal / max(absNormal.x,max(absNormal.y,absNormal.z)));
  if (absNormal.z>=absNormal.x) {
    if (absNormal.y>=absNormal.x) {
      if (absNormal.z>=absNormal.y) {
        newTex.x = -tempNormal.x*sign(tempNormal.z);
        newTex.y = -tempNormal.y;
      } else {
        newTex.x = tempNormal.x*sign(tempNormal.y);
        newTex.y = tempNormal.z;
      }
    } else {
      newTex.x = -tempNormal.x*sign(tempNormal.z);
      newTex.y = -tempNormal.y;
    }
    } else {
    if (absNormal.x>=absNormal.y) {
      if (absNormal.z>=absNormal.y) {
        newTex.x = tempNormal.z*sign(tempNormal.x);
        newTex.y = -tempNormal.y;
      } else {
        newTex.x = tempNormal.z*sign(tempNormal.x);
        newTex.y = -tempNormal.y;
      }
    } else {
      newTex.x = tempNormal.x*sign(tempNormal.y);
      newTex.y = tempNormal.z;
    }
  }
	return (newTex*0.5+0.5);
}  \  @   ��
 S H A D E R T E X T U R E S . F X       0 	        //Texturslots
texture ColorTexture : register(t0);      //Slot0
texture NormalTexture : register(t1);     //Slot1
texture MaterialTexture : register(t2);   //Slot2
texture VariableTexture1 : register(t3);  //Slot3
texture VariableTexture2 : register(t4);  //Slot4
texture VariableTexture3 : register(t5);  //Slot5
texture VariableTexture4 : register(t6);  //Slot6

//Sampler for texture access
sampler ColorTextureSampler : register(s0) = sampler_state
{
  texture = <ColorTexture>;
};
sampler NormalTextureSampler : register(s1) = sampler_state
{
  texture = <NormalTexture>;
};
sampler MaterialTextureSampler : register(s2) = sampler_state
{
  texture = <MaterialTexture>;
};
sampler VariableTexture1Sampler : register(s3) = sampler_state
{
  texture = <VariableTexture1>;
};
sampler VariableTexture2Sampler : register(s4) = sampler_state
{
  texture = <VariableTexture2>;
};
sampler VariableTexture3Sampler : register(s5) = sampler_state
{
  texture = <VariableTexture3>;
};
sampler VariableTexture4Sampler : register(s6) = sampler_state
{
  texture = <VariableTexture4>;
};
�=  @   ��
 S T A N D A R D S H A D E R . F X       0 	        #block defines
#endblock

#include Shaderglobals.fx
#include Shadertextures.fx

#ifdef SHADOWMAPPING
  #define SHADOW_SAMPLING_RANGE 1
  #include Shadowmapping.fx
#endif

cbuffer local : register(b1)
{
  float4x4 World, WorldInverseTranspose;

  #ifdef MATERIAL
    float Specularpower;
    float Specularintensity;
    float Speculartint;
    float Shadingreduction;
  #endif

  #ifdef ALPHA
    float Alpha;
  #endif
  #ifdef ALPHATEST
    float AlphaTestRef;
  #endif

  #ifdef COLOR_REPLACEMENT
    float4 ReplacementColor;
  #endif

  #ifdef COLORADJUSTMENT
    float3 HSVOffset;
    float3 AbsoluteHSV;
  #endif

  #ifdef TEXTURETRANSFORM
    float2 TextureOffset;
    float2 TextureScale;
  #endif

  #ifdef MORPH
    float4 Morphweights[2]; // 8 (4*2) is hardcoded maximum
  #endif

  #block custom_parameters
  #endblock
};

cbuffer bones : register(b2)
{
  float4x3 BoneTransforms[MAX_BONES];
};

#block custom_methods
#endblock

#ifdef SKINNING
  // number of influencing bones per vertex in range [1, 4]
  #define NumBoneInfluences 4
#endif

struct VSInput
{
  #block vs_input_override
    float3 Position : POSITION0;
    #ifdef MORPH
      #if MORPH_COUNT > 0
        float3 Position_Morph_1 : POSITION1;
      #endif
      #if MORPH_COUNT > 1
        float3 Position_Morph_2 : POSITION2;
      #endif
      #if MORPH_COUNT > 2
        float3 Position_Morph_3 : POSITION3;
      #endif
      #if MORPH_COUNT > 3
        float3 Position_Morph_4 : POSITION4;
      #endif
      #if MORPH_COUNT > 4
        float3 Position_Morph_5 : POSITION5;
      #endif
      #if MORPH_COUNT > 5
        float3 Position_Morph_6 : POSITION6;
      #endif
      #if MORPH_COUNT > 6
        float3 Position_Morph_7 : POSITION7;
      #endif
      #if MORPH_COUNT > 7
        float3 Position_Morph_8 : POSITION8;
      #endif
    #endif
    #ifdef VERTEXCOLOR
      float4 Color : COLOR0;
    #endif
    #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL) || defined(FORCE_TEXCOORD_INPUT)
      float2 Tex : TEXCOORD0;
    #endif
    #if defined(ALPHAMAP_TEXCOORDS)
      float2 AlphaTex : TEXCOORD1;
    #endif
    #if defined(LIGHTING) || defined(FORCE_NORMALMAPPING_INPUT)
      float3 Normal : NORMAL0;
      #if defined(NORMALMAPPING) || defined(FORCE_NORMALMAPPING_INPUT)
        float3 Tangent : TANGENT0;
        float3 Binormal : BINORMAL0;
      #endif
    #endif

    #if defined(SKINNING) || defined(FORCE_SKINNING_INPUT)
      float4 BoneWeights : BLENDWEIGHT0;
      float4 BoneIndices : BLENDINDICES0;
    #endif

    #ifdef SMOOTHED_NORMAL
      float3 SmoothedNormal : NORMAL1;
    #endif
  #endblock

  #block vs_input
  #endblock
};

struct VSOutput
{
  float4 Position : POSITION0;
  #ifdef VERTEXCOLOR
    float4 Color : COLOR0;
  #endif
  #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL)
    float2 Tex : TEXCOORD0;
  #endif
  #ifdef ALPHAMAP_TEXCOORDS
    float2 AlphaTex : TEXCOORD1;
  #endif
  #ifdef LIGHTING
    float3 Normal : TEXCOORD2;

    #ifdef NORMALMAPPING
      float3 Tangent : TEXCOORD3;
      float3 Binormal : TEXCOORD4;
    #endif

    #if defined(MATERIAL) && !defined(GBUFFER)
      float3 Halfway : TEXCOORD5;
    #endif
  #endif
  #if defined(GBUFFER) || defined(SHADOWMAPPING) || defined(NEEDWORLD)
    float3 WorldPosition : TEXCOORD6;
  #endif
  #ifdef SMOOTHED_NORMAL
    float3 SmoothedNormal : TEXCOORD7;
  #endif

  #block vs_output
  #endblock
};

struct PSInput
{
  float4 Position : POSITION0;
  #ifdef VERTEXCOLOR
    float4 Color : COLOR0;
  #endif
  #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL) || defined(MATERIALTEXTURE)
    float2 Tex : TEXCOORD0;
  #endif
  #ifdef ALPHAMAP_TEXCOORDS
    float2 AlphaTex : TEXCOORD1;
  #endif
  #ifdef LIGHTING
    float3 Normal : TEXCOORD2;

    #ifdef NORMALMAPPING
      float3 Tangent : TEXCOORD3;
      float3 Binormal : TEXCOORD4;
    #endif

    #if defined(MATERIAL) && !defined(GBUFFER)
      float3 Halfway : TEXCOORD5;
    #endif
  #endif
  #if defined(GBUFFER) || defined(SHADOWMAPPING) || defined(NEEDWORLD)
    float3 WorldPosition : TEXCOORD6;
  #endif
  #ifdef SMOOTHED_NORMAL
    float3 SmoothedNormal : TEXCOORD7;
  #endif

  #ifdef CULLNONE
    #ifdef DX9
      float winding : VFACE;
    #else
      bool winding : SV_IsFrontFace;
    #endif
  #endif

  #block ps_input
  #endblock
};

struct PSOutput
{
  #ifndef GBUFFER
    float4 Color : Color0;
  #else
    #ifdef DRAW_COLOR
      float4 Color : COLOR_0;
    #endif
    #ifdef DRAW_POSITION
      float4 PositionBuffer : COLOR_1;
    #endif
    #ifdef DRAW_NORMAL
      float4 NormalBuffer : COLOR_2;
    #endif
    #ifdef DRAW_MATERIAL
      float4 MaterialBuffer : COLOR_3;
    #endif
  #endif
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;

  #block pre_vertexshader

  #endblock

  float4 pos = float4(vsin.Position, 1.0);
  #ifdef MORPH
    #if MORPH_COUNT > 0
      pos.xyz += vsin.Position_Morph_1 * Morphweights[0][0];
    #endif
    #if MORPH_COUNT > 1
      pos.xyz += vsin.Position_Morph_2 * Morphweights[0][1];
    #endif
    #if MORPH_COUNT > 2
      pos.xyz += vsin.Position_Morph_3 * Morphweights[0][2];
    #endif
    #if MORPH_COUNT > 3
      pos.xyz += vsin.Position_Morph_4 * Morphweights[0][3];
    #endif
    #if MORPH_COUNT > 4
      pos.xyz += vsin.Position_Morph_5 * Morphweights[1][0];
    #endif
    #if MORPH_COUNT > 5
      pos.xyz += vsin.Position_Morph_6 * Morphweights[1][1];
    #endif
    #if MORPH_COUNT > 6
      pos.xyz += vsin.Position_Morph_7 * Morphweights[1][2];
    #endif
    #if MORPH_COUNT > 7
      pos.xyz += vsin.Position_Morph_8 * Morphweights[1][3];
    #endif
  #endif

  #ifdef LIGHTING
    float3 normal = vsin.Normal;
  #endif

  #ifdef RHW
    #ifdef DX9
      pos.xy -= 0.5;
    #endif
    // Pixelposition -> NDC
    vsout.Position = float4(pos.xy / viewport_size * 2 - 1, pos.z, 1.0);
    vsout.Position.y *= -1;
  #else
    #ifdef SKINNING
      float4x3 skinning = 0;

      [unroll]
      for (int i = 0; i < NumBoneInfluences; i++) {
        skinning += vsin.BoneWeights[i] * BoneTransforms[vsin.BoneIndices[i]];
      }

      pos.xyz = mul((float3x3)skinning, pos.xyz) + skinning._41_42_43;

      #ifdef LIGHTING
        normal = mul((float3x3)skinning, normal);
      #endif
    #endif

    #ifdef SMOOTHED_NORMAL
      #ifdef SKINNING
        float3 SmoothedNormal = mul((float3x3)skinning, vsin.SmoothedNormal);
      #else
        float3 SmoothedNormal = vsin.SmoothedNormal;
      #endif
      SmoothedNormal = normalize(mul((float3x3)WorldInverseTranspose, normalize(SmoothedNormal)));
    #endif

    #block vs_worldposition
      float4 Worldposition = mul(World, pos);
    #endblock

    #if defined(GBUFFER) || defined(SHADOWMAPPING) || defined(NEEDWORLD)
      vsout.WorldPosition = Worldposition.xyz;
    #endif
    vsout.Position = mul(Projection, mul(View, Worldposition));
  #endif

  #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL)
    #ifdef TEXTURETRANSFORM
      vsout.Tex = vsin.Tex * TextureScale + TextureOffset;
    #else
      vsout.Tex = vsin.Tex;
    #endif
  #endif
  #ifdef ALPHAMAP_TEXCOORDS
     vsout.AlphaTex = vsin.AlphaTex;
  #endif
  #ifdef VERTEXCOLOR
    vsout.Color = vsin.Color;
  #endif

  #ifdef LIGHTING
    #ifdef NORMALMAPPING
      float3 Normal = normalize(mul((float3x3)WorldInverseTranspose, normalize(normal)));
      float3 Tangent = normalize(mul((float3x3)World, normalize(vsin.Tangent)));
      float3 Binormal = normalize(mul((float3x3)World, normalize(vsin.Binormal)));
      vsout.Normal = Normal;
      vsout.Tangent = Tangent;
      vsout.Binormal = Binormal;
    #else
      vsout.Normal = normalize(mul((float3x3)WorldInverseTranspose, normalize(normal)));
    #endif

    #ifndef GBUFFER
      #ifdef MATERIAL
        vsout.Halfway = normalize(normalize(CameraPosition - Worldposition.xyz) + DirectionalLightDir);
      #endif
    #endif
  #endif

  #ifdef SMOOTHED_NORMAL
    vsout.SmoothedNormal = SmoothedNormal;
  #endif
  
  #block after_vertexshader

  #endblock

  return vsout;
}

PSOutput MegaPixelShader(PSInput psin){
  PSOutput pso;

  // ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Shared render code independently of rendering to GBuffer or directly
  // ////////////////////////////////////////////////////////////////////////////////////////////////////
  #if !defined(GBUFFER) || defined(DRAW_COLOR)
    #block pixelshader_diffuse
      #ifdef VERTEXCOLOR
        #ifdef DIFFUSETEXTURE
          pso.Color = tex2D(ColorTextureSampler,psin.Tex) * psin.Color;
        #else
          pso.Color = psin.Color;
        #endif
      #else
        #ifdef DIFFUSETEXTURE
          pso.Color = tex2D(ColorTextureSampler, psin.Tex);
        #else
          pso.Color = float4(0.5, 0.5, 0.5, 1.0);
        #endif
      #endif
    #endblock

    #ifdef COLOR_REPLACEMENT
      pso.Color.rgb = lerp(pso.Color.rgb, ReplacementColor.rgb, ReplacementColor.a);
    #endif

    #ifdef ALPHA
      pso.Color.a *= Alpha;
    #endif

    #ifdef ALPHAMAP
      #ifdef ALPHAMAP_TEXCOORDS
        pso.Color.a *= tex2D(VariableTexture2Sampler, psin.AlphaTex).a;
      #else
        pso.Color.a *= tex2D(VariableTexture2Sampler, psin.Tex).a;
      #endif
    #endif

    #ifdef ALPHATEST
      clip(pso.Color.a - AlphaTestRef);
    #endif
  #endif

  #if defined(MATERIALTEXTURE)
    // Material texture assumed argb = (Shading Reduction, Specularintensity, Specularpower, Specular Tinting)
    float4 Material = tex2D(MaterialTextureSampler, psin.Tex);
  #endif

  #ifdef LIGHTING
    float3 Normal = normalize(psin.Normal);
    #ifdef CULLNONE
      #ifdef DX9
        Normal = Normal * psin.winding;
      #else
        if (!psin.winding) Normal *= -1;
      #endif
    #endif
    #if defined(LIGHTING) && defined(NORMALMAPPING)
      float3x3 tangent_to_world = float3x3(normalize(psin.Tangent), Normal, normalize(psin.Binormal));
      float3 texture_normal = tex2D(NormalTextureSampler,psin.Tex).rbg * 2 - 1;
      Normal = normalize(mul(texture_normal, tangent_to_world));
    #endif
  #else
    #ifdef DRAW_NORMAL
      float3 Normal = 0;
    #endif
  #endif

  #ifdef GBUFFER
  // ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Rendering to GBuffer, split up all information we have
  // ////////////////////////////////////////////////////////////////////////////////////////////////////

    #ifdef DRAW_MATERIAL
      #ifdef MATERIAL
        #ifndef MATERIALTEXTURE
          pso.MaterialBuffer = float4(Specularintensity, Specularpower / 255.0 , Speculartint, Shadingreduction);
        #else
          pso.MaterialBuffer = float4(Specularintensity * Material.r, max(Material.g, Specularpower / 255.0), Speculartint * Material.b, max(Material.a, Shadingreduction));
        #endif
      #else
        #ifndef MATERIALTEXTURE
          pso.MaterialBuffer = 0;
        #else
          pso.MaterialBuffer = float4(0, 0, 0, Material.a);
        #endif
      #endif

      #ifdef ALPHA
        #ifdef DRAW_COLOR
          pso.MaterialBuffer.a = pso.Color.a;
        #else
          pso.MaterialBuffer.a = Alpha;
        #endif
      #endif
    #endif

    #ifdef DRAW_POSITION
      #ifdef ALPHA
        #ifdef DRAW_COLOR
          pso.PositionBuffer = float4(psin.WorldPosition.xyz, pso.Color.a);
        #else
          pso.PositionBuffer = float4(psin.WorldPosition.xyz, Alpha);
        #endif
      #else
         pso.PositionBuffer = float4(psin.WorldPosition.xyz, 0);
      #endif
    #endif

    #ifdef DRAW_NORMAL
      #ifdef ALPHA
        #ifdef DRAW_COLOR
          pso.NormalBuffer = float4(Normal, pso.Color.a);
        #else
          #ifdef VERTEXCOLOR
            pso.NormalBuffer = float4(Normal, psin.Color.a);
          #else
            pso.NormalBuffer = float4(Normal, 1);
          #endif
        #endif
      #else
        pso.NormalBuffer = float4(Normal, length(CameraPosition - psin.WorldPosition.xyz));
      #endif
    #endif
  #endif

  // ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Rendering without GBuffer, directly drawing the resulting color
  // ////////////////////////////////////////////////////////////////////////////////////////////////////
  #ifndef GBUFFER
    #ifdef LIGHTING
      #ifdef SHADOWMAPPING
        float Shadowstrength = GetShadowStrength(psin.WorldPosition, Normal, VariableTexture3Sampler
         #ifdef DX11
           ,VariableTexture3
         #endif
         );
        float3 LightIntensity = saturate(dot(Normal,DirectionalLightDir.xyz)) * (1-Shadowstrength) * DirectionalLightColor.rgb * DirectionalLightColor.a;
      #else
        float3 LightIntensity = saturate(dot(Normal,DirectionalLightDir.xyz)) * DirectionalLightColor.rgb * DirectionalLightColor.a;
      #endif

      #ifdef MATERIAL
        float3 Halfway = normalize(psin.Halfway);
        // build material
        #ifdef MATERIALTEXTURE
          float specular_tint = Material.b;
          float specular_power = max(Material.g * 255.0, Specularpower) + 1;
          float specular_intensity = Material.r * Specularintensity;
          float shading_reduction = max(Material.a, Shadingreduction);
        #else
          float specular_tint = Speculartint;
          float specular_power = Specularpower;
          float specular_intensity = Specularintensity;
          float shading_reduction = Shadingreduction;
        #endif
        // apply lighting
        float3 Specular = lerp(DirectionalLightColor.rgb, pso.Color.rgb, specular_tint);
        Specular *= pow(saturate(dot(Normal, Halfway)), specular_power);
        Specular *= specular_intensity;
        pso.Color.rgb = pso.Color.rgb * lerp(LightIntensity + Ambient, 1.0, shading_reduction) + Specular * LightIntensity;
      #else
        #ifdef MATERIALTEXTURE
          pso.Color.rgb = pso.Color.rgb * lerp(LightIntensity + Ambient, 1.0, Material.a);
        #else
          pso.Color.rgb = pso.Color.rgb * (LightIntensity + Ambient);
        #endif
      #endif
    #endif
  #endif

  // ////////////////////////////////////////////////////////////////////////////////////////////////////
  // Postprocessing
  // ////////////////////////////////////////////////////////////////////////////////////////////////////

  #block color_adjustment
    #if !defined(GBUFFER) || defined(DRAW_COLOR)
      #ifdef COLORADJUSTMENT
        pso.Color.rgb = RGBToHSV(pso.Color.rgb);
        #ifdef ABSOLUTECOLORADJUSTMENT
          pso.Color.rgb = lerp(pso.Color.rgb,HSVOffset,AbsoluteHSV);
          pso.Color.rgb = lerp(pso.Color.rgb, float3(abs(frac(pso.Color.r + HSVOffset.r)), saturate(pso.Color.gb + HSVOffset.gb)), 1 - AbsoluteHSV);
        #else
          pso.Color.rgb = float3(abs(frac(pso.Color.r + HSVOffset.r)), saturate(pso.Color.gb + HSVOffset.gb));
        #endif
        pso.Color.rgb = HSVToRGB(pso.Color.rgb);
      #endif
    #endif
  #endblock

  #block after_pixelshader

  #endblock

  return pso;
}

technique MegaTec
{
   pass p0
   {
    VertexShader = compile vs_3_0 MegaVertexShader();
    PixelShader = compile ps_3_0 MegaPixelShader();
   }
}
     L   ��
 F U L L S C R E E N Q U A D H E A D E R . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

struct VSInput
{
  float3 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct PSOutput
{
  float4 Color : COLOR0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = float4(vsin.Position, 1.0);
  #ifdef DX9
    vsout.Position.xy -= float2(1.0, -1.0) / viewport_size;
  #endif
  vsout.Tex = vsin.Tex;
  return vsout;
} �   L   ��
 F U L L S C R E E N Q U A D F O O T E R . F X       0 	        technique MegaTec
{
   pass p0
   {
      VertexShader = compile vs_3_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
   }
} i  H   ��
 S C R E E N T O B A C K B U F F E R . F X       0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  #ifdef DX11
    pso.Color.rgb = ColorTexture.Load(float3(psin.Tex * viewport_size, 0)).rgb;
  #else
	  pso.Color.rgb = tex2Dlod(ColorTextureSampler, float4(psin.Tex, 0, 0)).rgb;
  #endif
  return pso;
}

#include FullscreenQuadFooter.fx   q  d   ��
 D E F E R R E D D I R E C T I O N A L A M B I E N T L I G H T . F X         0 	        #include Shaderglobals.fx
#include Shadertextures.fx

#define MAX_LIGHTS 4

cbuffer local : register(b1)
{
  float4 DirectionalLightDirs[MAX_LIGHTS];
  float4 DirectionalLightColors[MAX_LIGHTS];
  int DirectionalLightCount;
};

struct VSInput
{
  float3 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = float4(vsin.Position, 1.0);
  #ifdef DX9
    vsout.Position.xy -= float2(1.0, -1.0) / viewport_size;
  #endif
  vsout.Tex = vsin.Tex;
  return vsout;
}

struct PSInput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
  float4 TexPos : VPOS;
};

struct PSOutput
{
  float4 Color : COLOR0;
  #ifdef LIGHTBUFFER
    float4 Lightbuffer : COLOR1;
  #endif
};

PSOutput MegaPixelShader(PSInput psin){
  PSOutput pso;
  float3 Specular = 0;
  float3 LightIntensity = 0;
  #ifdef DX9
    float4 Color = tex2D(ColorTextureSampler,psin.Tex);
    clip(Color.a-0.001);
    float3 Position = tex2D(VariableTexture1Sampler,psin.Tex).rgb;
    float3 Normal = tex2D(NormalTextureSampler,psin.Tex).rgb;
    float4 Material = tex2D(VariableTexture2Sampler,psin.Tex);
    #ifdef SHADOWMASK
      float Shadowmask = tex2D(VariableTexture3Sampler,psin.Tex).a;
    #endif
  #else
    float4 Color = ColorTexture.Load(float3(psin.TexPos.xy, 0));
    clip(Color.a-0.001);
    float3 Position = VariableTexture1.Load(float3(psin.TexPos.xy, 0)).rgb;
    float3 Normal = NormalTexture.Load(float3(psin.TexPos.xy, 0)).rgb;
    float4 Material = VariableTexture2.Load(float3(psin.TexPos.xy, 0));
    #ifdef SHADOWMASK
      float Shadowmask = VariableTexture3.Load(float3(psin.TexPos.xy, 0)).a;
    #endif
  #endif

  for(float i=0; i < DirectionalLightCount; i++) {
    float3 Halfway = normalize(normalize(CameraPosition-Position)+DirectionalLightDirs[i].xyz);
    #ifdef SHADOWMASK
      //LightIntensity += BeleuchtungsBerechnungMitSchatten(Normal,DirectionalLightDirs[i].xyz,Shadowmask) * DirectionalLightColors[i].rgb * DirectionalLightColors[i].a;
      LightIntensity += saturate(dot(Normal,DirectionalLightDirs[i].xyz)) * (1-Shadowmask) * DirectionalLightColors[i].rgb * DirectionalLightColors[i].a;
      // only first light is affected by shadow
      Shadowmask = 0;
    #else
      //LightIntensity += BeleuchtungsBerechnung(Normal,DirectionalLightDirs[i].xyz) * DirectionalLightColors[i].rgb * DirectionalLightColors[i].a;
      LightIntensity += saturate(dot(Normal,DirectionalLightDirs[i].xyz)) * DirectionalLightColors[i].rgb * DirectionalLightColors[i].a;
    #endif
    Specular += lerp(DirectionalLightColors[i].rgb, Color.rgb, Material.b) * pow(saturate(dot(Normal,Halfway)),(Material.g * 255.0)+1) * Material.r;
  }

  pso.Color.rgb = Color.rgb * lerp(LightIntensity + Ambient, 1.0, Material.a) + Specular * LightIntensity;
  pso.Color.a = Color.a;
  #ifdef LIGHTBUFFER
    pso.Lightbuffer = float4(lerp((1 + Specular) * LightIntensity + Ambient, 1, Material.b),1);
  #endif
  return pso;
}

#include FullscreenQuadFooter.fx   y  H   ��
 D E F E R R E D P O I N T L I G H T . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

struct VSInput
{
  float3 Position : POSITION0;
  float4 Color : COLOR0;
  float3 WorldPositionCenter : TEXCOORD0;
  float3 Range : TEXCOORD1;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float3 WorldPositionCenter : TEXCOORD1;
  float3 Range : TEXCOORD2;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = mul(Projection, mul(View, float4(vsin.Position, 1)));
  vsout.WorldPositionCenter = vsin.WorldPositionCenter;
  vsout.Color = vsin.Color;
  vsout.Range = vsin.Range;
  return vsout;
}

struct PSInput
{
  float4 ScreenPosition : VPOS;
  float4 Color : COLOR0;
  float3 WorldPositionCenter : TEXCOORD1;
  float3 Range : TEXCOORD2;
};

struct PSOutput
{
  float4 Color : COLOR0;
  #ifdef LIGHTBUFFER
    float4 Lightbuffer : COLOR1;
  #endif
};

PSOutput MegaPixelShader(PSInput psin){
  PSOutput pso;

  #ifdef DX9
    psin.ScreenPosition.xy /= viewport_size;
    float4 Color = tex2D(ColorTextureSampler,psin.ScreenPosition.xy);
    clip(Color.a-0.001);
    float3 Position = (tex2D(VariableTexture1Sampler,psin.ScreenPosition.xy).rgb);
    float dist = distance(psin.WorldPositionCenter,Position);
    clip(psin.Range.x - dist);
    float3 Normal = normalize(tex2D(NormalTextureSampler,psin.ScreenPosition.xy).rgb);
    float4 Material = tex2D(VariableTexture2Sampler,psin.ScreenPosition.xy);
  #else
    float4 Color = ColorTexture.Load(float3(psin.ScreenPosition.xy, 0));
    clip(Color.a-0.001);
    float3 Position = VariableTexture1.Load(float3(psin.ScreenPosition.xy, 0)).rgb;
    float dist = distance(psin.WorldPositionCenter,Position);
    clip(psin.Range.x - dist);
    float3 Normal = normalize(NormalTexture.Load(float3(psin.ScreenPosition.xy, 0)).rgb);
    float4 Material = VariableTexture2.Load(float3(psin.ScreenPosition.xy, 0));
  #endif

  float3 Light = normalize(psin.WorldPositionCenter-Position);
  float3 Halfway = normalize(normalize(CameraPosition-Position)+Light);
  float intensity = (1 - pow(saturate(dist / psin.Range.x), psin.Range.y + 1)) * (psin.Range.z + 1);
  float3 Beleuchtung = BeleuchtungsBerechnung(Normal,Light) * intensity;
  float3 Specular = lerp(psin.Color.rgb, Color.rgb, Material.b) * pow(saturate(dot(Normal,Halfway)),(Material.g*255)) * Material.r;
  pso.Color.rgb = (Color.rgb + Specular) * (Beleuchtung * psin.Color.rgb) * psin.Color.a; // + (Material.a * Color.rgb); Shading Reduction only for Directional light and Ambient
  pso.Color.a = Color.a;
  #ifdef LIGHTBUFFER
    pso.Lightbuffer = float4((1+Specular)*(Beleuchtung*psin.Color.rgb)*psin.Color.a, 1);// + (Color.rgb * Material.a),1);
  #endif
  return pso;
}

technique MegaTec
{
    pass p0
    {
      VertexShader = compile vs_3_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
    }
}   -  D   ��
 P O S T E F F E C T D R A W Z . F X         0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  float depth = tex2D(ColorTextureSampler,psin.Tex).r/1000;
  depth = depth == 0 ? 1 : depth;
  pso.Color.rgb = (1-depth)*1.2-0.2;
  return pso;
}

#include FullscreenQuadFooter.fx   \  P   ��
 P O S T E F F E C T D R A W Z G B U F F E R . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float near, far;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  float depth = (tex2D(ColorTextureSampler,psin.Tex).a - near) / (far - near);
  pso.Color.rgb = (1 - saturate(depth));
  return pso;
}

#include FullscreenQuadFooter.fx�   P   ��
 P O S T E F F E C T D R A W P O S I T I O N . F X       0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  pso.Color.rgb = (tex2D(ColorTextureSampler,psin.Tex).rgb/50);
  return pso;
}

#include FullscreenQuadFooter.fx�   L   ��
 P O S T E F F E C T D R A W C O L O R . F X         0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  pso.Color.rgb = tex2D(ColorTextureSampler,psin.Tex).rgb;
  return pso;
}

#include FullscreenQuadFooter.fx �   L   ��
 P O S T E F F E C T D R A W N O R M A L . F X       0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  pso.Color.rgb = ((tex2D(ColorTextureSampler,psin.Tex).rgb)+1)/2;
  return pso;
}

#include FullscreenQuadFooter.fx $  P   ��
 P O S T E F F E C T D R A W N O R M A L S S . F X       0 	        #include FullscreenQuadHeader.fx

float3 CameraUp,CameraLeft;

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  float4 NormalDepth = tex2D(ColorTextureSampler,psin.Tex);
  float3 Normal = normalize(NormalDepth.xyz);
  float Up = dot(normalize(CameraUp),Normal);
  float Left = dot(normalize(CameraLeft),Normal);
  float3 newNormal = (float3(-Left,-Up,1-sqrt(Left*Left+Up*Up)))/2+0.5;
  pso.Color.rgb = (NormalDepth.w==0)?float3(0.5,0.5,1):((newNormal));
  return pso;
}

#include FullscreenQuadFooter.fx�  D   ��
 P O S T E F F E C T E D G E A A . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1) {
  float pixelwidth, pixelheight, positionbias, normalbias;
};

PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  // determine edge ------------------------------------------------------------
  pso.Color.a = 0;
  float4 center = tex2D(NormalTextureSampler, psin.Tex);
  float4 up = tex2D(NormalTextureSampler, psin.Tex + float2(0, -pixelheight));
  float4 left = tex2D(NormalTextureSampler, psin.Tex + float2(-pixelwidth, 0));
  float4 right = tex2D(NormalTextureSampler, psin.Tex + float2(pixelwidth, 0));
  float4 down = tex2D(NormalTextureSampler, psin.Tex + float2(0, pixelheight));
  // position
  float distance = sqr(center.a - up.a);
  distance += sqr(center.a - left.a);
  distance += sqr(center.a - right.a);
  distance += sqr(center.a - down.a);
  pso.Color.a += saturate(distance - positionbias);
  // normal
  float normal = dot(center.rgb, up.rgb);
  normal += dot(center.rgb, left.rgb);
  normal += dot(center.rgb, right.rgb);
  normal += dot(center.rgb, down.rgb);
  // uses hard normaldifferences, if background (normal = zero vector) don't detect
  pso.Color.a += saturate(normalbias - normal) * length(center.rgb);

  // blur edge -----------------------------------------------------------------
  #ifdef DRAW_EDGES
    pso.Color.rbg = float3(1.0,0.0,0.0);
  #else
    // average color => blur
    float3 CCenter = tex2D(VariableTexture1Sampler, psin.Tex).rgb;
    float3 CUp = tex2D(VariableTexture1Sampler, psin.Tex + float2(0, -pixelheight)).rgb;
    float3 CLeft = tex2D(VariableTexture1Sampler, psin.Tex + float2(-pixelwidth, 0)).rgb;
    float3 CRight = tex2D(VariableTexture1Sampler, psin.Tex + float2(pixelwidth, 0)).rgb;
    float3 CDown = tex2D(VariableTexture1Sampler, psin.Tex + float2(0, pixelheight)).rgb;
    pso.Color.rgb = (CCenter + CUp + CLeft + CRight + CDown) / 5.0;
  #endif

  return pso;
}

#include FullscreenQuadFooter.fx
   �
  P   ��
 P O S T E F F E C T G A U S S I A N B L U R . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float pixelwidth, pixelheight, intensity;
  #ifdef BILATERAL
  float range, normalbias;
  #endif
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  #define REAL_KERNELSIZE KERNELSIZE+2
  #ifdef ADDITIVE
    #if KERNELSIZE == 0
      float kernel[REAL_KERNELSIZE] = GAUSS_0_ADDITIVE;
    #elif KERNELSIZE == 1
      float kernel[REAL_KERNELSIZE] = GAUSS_1_ADDITIVE;
    #elif KERNELSIZE == 2
      float kernel[REAL_KERNELSIZE] = GAUSS_2_ADDITIVE;
    #elif KERNELSIZE == 3
      float kernel[REAL_KERNELSIZE] = GAUSS_3_ADDITIVE;
    #elif KERNELSIZE == 4
      float kernel[REAL_KERNELSIZE] = GAUSS_4_ADDITIVE;
    #endif
  #else
    #if KERNELSIZE == 0
      float kernel[REAL_KERNELSIZE] = GAUSS_0;
    #elif KERNELSIZE == 1
      float kernel[REAL_KERNELSIZE] = GAUSS_1;
    #elif KERNELSIZE == 2
      float kernel[REAL_KERNELSIZE] = GAUSS_2;
    #elif KERNELSIZE == 3
      float kernel[REAL_KERNELSIZE] = GAUSS_3;
    #elif KERNELSIZE == 4
      float kernel[REAL_KERNELSIZE] = GAUSS_4;
    #endif
  #endif
  pso.Color = float4(tex2D(ColorTextureSampler, psin.Tex).rgb * kernel[0], 1);
  #ifdef BILATERAL
    float4 normaldepth = tex2D(NormalTextureSampler, psin.Tex);
    float weigthsum = kernel[0];
  #endif
  [unroll]
  for (float i = 1.0; i < REAL_KERNELSIZE; i++) {
    float2 tex_offset = i * float2(pixelwidth, pixelheight);
    #ifdef BILATERAL
      float2 sample_coord = psin.Tex + tex_offset;
      float4 sample_normaldepth = tex2D(NormalTextureSampler, sample_coord);
      float rangecheck = abs(normaldepth.w - sample_normaldepth.w) < range ? 1.0 : 0.0;
      rangecheck *= dot(normaldepth.xyz, sample_normaldepth.xyz) > normalbias ? 1.0 : 0.0;
      weigthsum += rangecheck * kernel[i];
      pso.Color.rgb += tex2D(ColorTextureSampler, sample_coord).rgb * kernel[i] * rangecheck;

      sample_coord = psin.Tex - tex_offset;
      sample_normaldepth = tex2D(NormalTextureSampler, sample_coord);
      rangecheck = abs(normaldepth.w - sample_normaldepth.w) < range ? 1.0 : 0.0;
      rangecheck *= dot(normaldepth.xyz, sample_normaldepth.xyz) > normalbias ? 1.0 : 0.0;
      weigthsum += rangecheck * kernel[i];
      pso.Color.rgb += tex2D(ColorTextureSampler, sample_coord).rgb * kernel[i] * rangecheck;
    #else
      pso.Color.rgb += tex2D(ColorTextureSampler, psin.Tex + tex_offset).rgb * kernel[i];
      pso.Color.rgb += tex2D(ColorTextureSampler, psin.Tex - tex_offset).rgb * kernel[i];
    #endif
  }
  #ifdef BILATERAL
    pso.Color.rgb /= weigthsum;
  #endif
  pso.Color.rgb *= intensity;
  return pso;
}

#include FullscreenQuadFooter.fx.  T   ��
 P O S T E F F E C T U N S H A R P M A S K I N G . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float amount;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  float3 scene = tex2D(ColorTextureSampler, psin.Tex).rgb;
  float3 blurred_scene = tex2D(NormalTextureSampler, psin.Tex).rgb;
  float3 difference = scene - blurred_scene;
  // add the differences between blurred scene and scene to highlight edges with
  // contrast overshooting
  pso.Color.rgb = scene + difference * amount;
  return pso;
}

#include FullscreenQuadFooter.fx
    @   ��
 P O S T E F F E C T F O G . F X         0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float4 fog_color;
  float start_range, range;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.rgb = fog_color.rgb;
  float scene_depth = tex2D(ColorTextureSampler,psin.Tex).a;
  // linear fog
  float fog_factor = saturate((scene_depth - start_range) / range);
  // fully fog background
  pso.Color.a = saturate(fog_factor + 1 - tex2D(NormalTextureSampler,psin.Tex).a);
  return pso;
}

#include FullscreenQuadFooter.fx   �  L   ��
 P O S T E F F E C T M O T I O N B L U R . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1) {
  float4x4 oldViewProj;
  float scale, pixelwidth, pixelheight;
};

// Blur along the moved direction to blur the last motion
PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  float background = tex2D(VariableTexture1Sampler, psin.Tex).a;
  clip(background - 0.5);
  // get from the current world position the screen position of the last frame
  float4 old_screen_pos = float4(tex2D(ColorTextureSampler, psin.Tex).rgb, 1);
  old_screen_pos = mul(oldViewProj, old_screen_pos);
  old_screen_pos.xyz /= old_screen_pos.w;
  old_screen_pos.y *= -1;

  float2 blur_vector = (old_screen_pos.xy * 0.5 + 0.5) - psin.Tex;

  float3 result = 0;
  //#define KERNELSIZE 11
  //float kernel[KERNELSIZE] = {0.035822, 0.05879, 0.086425, 0.113806, 0.13424, 0.141836, 0.13424, 0.113806, 0.086425, 0.05879, 0.035822};
  #define KERNELSIZE 25
  float kernel[KERNELSIZE] = {0.000048, 0.000169, 0.000538, 0.001532, 0.003907, 0.008921, 0.018247, 0.033432, 0.054867, 0.080658, 0.106212, 0.125283, 0.132372, 0.125283, 0.106212, 0.080658, 0.054867, 0.033432, 0.018247, 0.008921, 0.003907, 0.001532, 0.000538, 0.000169, 0.000048};
  for (int i = 0; i < KERNELSIZE; ++i) {
    float factor = (i / (float(KERNELSIZE) - 1) - 0.5) * scale;
    float2 offset = factor * blur_vector;
    result += tex2D(NormalTextureSampler, psin.Tex + offset).rgb * kernel[i];
  }

  pso.Color = float4(result.rgb, 1);
  return pso;
}

#include FullscreenQuadFooter.fx
m  @   ��
 P O S T E F F E C T T O O N . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1) {
  float border_gradient, specular_threshold, light_offset, light_threshold;
  float3 border_color;
};

PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  float4 Color = tex2D(ColorTextureSampler, psin.Tex);
  float factor = 1;
  // if no lighting is specified, lighting is in color
  float3 Light = 1;
  float3 Specular = 0;

  #ifndef NO_LIGHTING
    // discretize lighting
    float3 OriginalLight = tex2D(VariableTexture1Sampler, psin.Tex).rgb;
    Specular = (OriginalLight - 1) > float3(specular_threshold, specular_threshold, specular_threshold) ? 1 : 0;
    Light = saturate(trunc(saturate(OriginalLight) / light_threshold) + light_offset);
  #endif

  #ifndef NO_BORDER
    // apply black border
    float BlackBorder = saturate(tex2D(NormalTextureSampler, psin.Tex).r);
    factor = pow(BlackBorder, border_gradient);
  #endif

  clip(Color.a - 0.1 + (1 - factor));

  pso.Color.rgb = lerp(border_color, (Color.rgb * Light + Specular), factor);
  pso.Color.a = 1;
  return pso;
}

#include FullscreenQuadFooter.fx
   �  @   ��
 P O S T E F F E C T S S A O . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1) {
  float range, width, height, JumpMax;
  float4x4 ViewProjection;
  float4 Kernel[KERNELSIZE];
};

PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  float urbackground = tex2D(VariableTexture1Sampler, psin.Tex).a;
  clip(urbackground - 0.5);
  pso.Color.a = 1.0;

  float3 normal = normalize(tex2D(NormalTextureSampler, psin.Tex).rgb);
  float3 rvec = tex2D(VariableTexture2Sampler, psin.Tex * float2(width, height)).rgb;
  float3 tangent = normalize(rvec - normal * dot(rvec, normal));
  float3 bitangent = cross(normal, tangent);
  float3x3 tbn = float3x3(tangent, bitangent, normal);

  float count = 1.0;
  float occlusion = 0.0;
  float realZ, testZ, range_check;
  float3 samplePosition;
  float4 offset, sampleCoord;
  float4 position = float4(tex2D(ColorTextureSampler, psin.Tex).rgb, 1);
  for (int i = 0; i < KERNELSIZE; ++i) {
    offset = position + float4(mul(Kernel[i].xyz, tbn), 0);
    sampleCoord = mul(ViewProjection, offset);
    sampleCoord.xy /= sampleCoord.w;
    sampleCoord.xy = (sampleCoord.xy * float2(0.5, -0.5) + 0.5);
    sampleCoord.xy = sampleCoord.xy - psin.Tex;
    sampleCoord.xy /= clamp(length(sampleCoord.xy) / JumpMax, 1.0, 10000.0);
    sampleCoord.xy = sampleCoord.xy + psin.Tex;
    samplePosition = tex2D(ColorTextureSampler, sampleCoord.xy).rgb;
    realZ = length(samplePosition.xyz - CameraPosition);
    urbackground = tex2D(VariableTexture1Sampler, sampleCoord.xy).a;
    if (urbackground<0.5) realZ = 10000.0;
    // realZ = tex2D(NormalTextureSampler,sampleCoord.xy).a;
    testZ = length(offset.xyz - CameraPosition);
    range_check = abs(realZ - testZ) < range ? 1.0 : 0.0;
    occlusion += (realZ > testZ ? 0.0 : 1.0) * range_check;
    count += range_check;
  }
  pso.Color.rgb = 1.0 - ((occlusion / count));
  return pso;
}

#include FullscreenQuadFooter.fx
   =  @   ��
 P O S T E F F E C T V B A O . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1) {
  float range, width, height, JumpMax;
  float4x4 ViewProjection;
  float4 Kernel[KERNELSIZE];
};

#define BIAS 0.1
#define EPSILON 0.000001

PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  float occlusion = 0.0;
  float4 normalDepth = tex2D(NormalTextureSampler, psin.Tex);
  normalDepth.xyz = normalize(normalDepth.xyz);
  clip(normalDepth.w - 0.01);
  float4 position = float4(tex2D(ColorTextureSampler, psin.Tex).rgb, 1);
  position.xyz += normalDepth.xyz * (range / 2.0);
  normalDepth.w = distance(position.xyz, CameraPosition);
  position = mul(ViewProjection, position);
  position.xy /= position.w;
  position.xy = position.xy * float2(0.5, -0.5) + 0.5;
  float3 noise = tex2D(VariableTexture2Sampler, psin.Tex * float2(width, height)).rgb;
  float normalization = EPSILON;
  for (int i = 0; i < KERNELSIZE; ++i) {
    float4 sampleCoord = mul(Projection, float4(Kernel[i].xy, normalDepth.w, 1));
    sampleCoord.xy /= sampleCoord.w;
    sampleCoord.xy = float2(sampleCoord.x * noise.x - sampleCoord.y * noise.y, sampleCoord.x * noise.y + sampleCoord.y * noise.x) + position.xy;
    float sampleZ = tex2D(NormalTextureSampler, sampleCoord.xy).a;
    // background is 0.0 but must be infinite far away
    sampleZ = (sampleZ <= 0.0) ? 1000.0 : sampleZ;
    float zEntry = normalDepth.w - Kernel[i].z;
    float deltaZ = sampleZ - zEntry;
    float range_check = ((deltaZ <= 0) ? saturate(1 + deltaZ / range) : 1.0);
    deltaZ = clamp(deltaZ, 0, 2.0 * Kernel[i].z);
    occlusion += deltaZ;
    normalization += Kernel[i].z * 2.0 * range_check;
  }
  pso.Color.rgb = ((occlusion / normalization * (1 + BIAS))) + (normalization <= EPSILON ? 1.0 : 0.0);
  pso.Color.a = 1.0;
  return pso;
}

#include FullscreenQuadFooter.fx
   |  @   ��
 P O S T E F F E C T H B A O . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float range,width,height,JumpMax;
  float4x4 ViewProjection;
  float4 Kernel[KERNELSIZE];
};

#define BIAS 0.3

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float urbackground = tex2D(VariableTexture1Sampler,psin.Tex).a;
  clip(urbackground-0.5);
  float endocclusion = 0.0;
  float4 normalDepth = tex2D(NormalTextureSampler,psin.Tex);
  float3 noise = tex2D(VariableTexture2Sampler,psin.Tex*float2(width,height)).rgb;
  float3 position = tex2D(ColorTextureSampler,psin.Tex).rgb;
  for(int i=0;i<KERNELSIZE;++i){
    float2 direction = Kernel[i].xy/normalDepth.w;
    direction = float2(direction.x*noise.x-direction.y*noise.y,direction.x*noise.y+direction.y*noise.x)*noise.z;
    float2 offset = 0;
    float occlusion = BIAS;
    for(int j=0;j<SAMPLES;++j){
      offset += direction;
      float3 samplePosition = tex2D(ColorTextureSampler,psin.Tex+offset).rgb;
      float3 sampleDir = (samplePosition-position);
      float rayLength = length(sampleDir);
      float range_check = rayLength < range ? 1.0 : 0.0;
      occlusion = max(occlusion,dot((sampleDir/rayLength),normalDepth.xyz)*range_check);
    }
    endocclusion+=(occlusion-BIAS)/(1-BIAS);
  }
  pso.Color.rgb = 1-(endocclusion/(KERNELSIZE/2));
  pso.Color.a = 1.0;
  return pso;
}

#include FullscreenQuadFooter.fx
�  H   ��
 P O S T E F F E C T M U L T I P L Y . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float darkness;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float3 factor = tex2D(NormalTextureSampler, psin.Tex).rgb;
  pso.Color.argb = tex2D(ColorTextureSampler, psin.Tex).argb;
  clip(tex2D(VariableTexture1Sampler, psin.Tex).a - 0.5);
  pso.Color.rgb *= pow(saturate(factor), darkness);
  return pso;
}

#include FullscreenQuadFooter.fx
�  H   ��
 P O S T E F F E C T B O X B L U R . F X         0 	        #include FullscreenQuadHeader.fx

float pixelwidth,pixelheight;

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.rgb = float3(0,0,0);
  for (int i = -1; i < 3; ++i) {
    for (int j = -1; j < 3; ++j) {
      float2 offset = float2(pixelwidth * j, pixelheight * i);
      float3 pixelfarbe = tex2D(ColorTextureSampler, psin.Tex + offset).rgb;
      pso.Color.rgb += pixelfarbe * pixelfarbe;
    }
  }
  pso.Color.rgb *= 0.0625;
  pso.Color.rgb = tex2D(ColorTextureSampler, psin.Tex);
  pso.Color.a = 1;
  return pso;
}

technique MegaTec
{
   pass p0
   {
      VertexShader = compile vs_2_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
   }
}
   �  X   ��
 P O S T E F F E C T Z D I F F E R E N C E B L U R . F X         0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float pixelwidth, pixelheight, range;
};

#define KERNELSIZE 3
#define weight float3(0.29411764706,0.23529411764706,0.1176470588235)

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float depth = tex2D(ColorTextureSampler, psin.Tex).a;
  depth = depth == 0 ? 1000.0 : depth;
  pso.Color.rgb = 0;
  pso.Color.a = depth * weight[0];
  float weigthsum = weight[0];
  for (int i=1; i<KERNELSIZE; i++) {
    float2 sampleCoord = psin.Tex + (i * float2(pixelwidth, pixelheight) / depth * 100);
    float sampledepth = tex2D(ColorTextureSampler, sampleCoord).a;
    sampledepth = sampledepth == 0? 1000.0 : sampledepth;
    //float rangecheck = abs(depth-sampledepth)<range? 1.0 : 0.0;
    weigthsum += weight[i];
    pso.Color.a += (abs(depth - sampledepth) < range ? sampledepth : depth + range) * weight[i];

    sampleCoord = psin.Tex -(i * float2(pixelwidth, pixelheight) / depth * 100);
    sampledepth = tex2D(ColorTextureSampler, sampleCoord).a;
    sampledepth = sampledepth == 0 ? 1000.0 : sampledepth;
    //rangecheck = abs(depth-sampledepth)<range? 1.0 : 0.0;
    weigthsum += weight[i];
    pso.Color.a += (abs(depth - sampledepth) < range ? sampledepth : depth + range) * weight[i];
  }
  pso.Color.a /= weigthsum;
  pso.Color.a = min(pso.Color.a,depth);
  return pso;
}

#include FullscreenQuadFooter.fx   P   ��
 P O S T E F F E C T Z D I F F E R E N C E . F X         0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float range;
};

#define BIAS 0.1

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float depth = tex2D(ColorTextureSampler, psin.Tex).a;
  depth = depth == 0 ? 1000.0 : depth;
  float blurredDepth = tex2D(NormalTextureSampler, psin.Tex).a;
  pso.Color.a = 1;
  float darkness = (1 - (abs(depth - blurredDepth) / range))/(1 - BIAS);
  pso.Color.rgb = darkness <= 0 ? 1 : darkness;

  return pso;
}

#include FullscreenQuadFooter.fx   �  P   ��
 P O S T E F F E C T B L A C K B O R D E R . F X         0 	        #include FullscreenQuadHeader.fx

#define KERNELSIZE 3

cbuffer local : register(b1) {
  float pixelwidth, pixelheight, range, normalbias, border_threshold;
};

PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  float weight[KERNELSIZE] = {0.312, 0.2269, 0.1176};
  float3 original_color = tex2D(ColorTextureSampler, psin.Tex).rgb;
  pso.Color = float4(original_color * weight[0], 0);
  float4 normaldepth = tex2D(NormalTextureSampler, psin.Tex);
  float shading_reduction = tex2D(VariableTexture2Sampler, psin.Tex).w;
  float threshold_check = step(border_threshold, shading_reduction);
  for (int i = 1; i < KERNELSIZE; i++) {
    float2 offset = (i * float2(pixelwidth, pixelheight));
    float2 sampleCoord = psin.Tex + offset;
    float4 sampleNormaldepth = tex2D(NormalTextureSampler, sampleCoord);
    shading_reduction = tex2D(VariableTexture2Sampler, sampleCoord).w;
    float rangecheck = abs(normaldepth.w - sampleNormaldepth.w) < range ? 1.0 : 0.0;
    rangecheck *= dot(normaldepth.xyz, sampleNormaldepth.xyz) >= normalbias * length(normaldepth.xyz) ? 1.0 : 0.0;
    threshold_check += step(border_threshold, shading_reduction);
    pso.Color.rgb += tex2D(ColorTextureSampler, sampleCoord).rgb * weight[i] * rangecheck;

    sampleCoord -= 2 * offset;
    sampleNormaldepth = tex2D(NormalTextureSampler, sampleCoord);
    shading_reduction = tex2D(VariableTexture2Sampler, sampleCoord).w;
    rangecheck = abs(normaldepth.w - sampleNormaldepth.w) < range ? 1.0 : 0.0;
    rangecheck *= dot(normaldepth.xyz, sampleNormaldepth.xyz) >= normalbias * length(normaldepth.xyz) ? 1.0 : 0.0;
    threshold_check += step(border_threshold, shading_reduction);
    pso.Color.rgb += tex2D(ColorTextureSampler, sampleCoord).rgb * weight[i] * rangecheck;
  }
  pso.Color.rgb = lerp(pso.Color.rgb, original_color, threshold_check);
  return pso;
}

#include FullscreenQuadFooter.fx
 �  @   ��
 P O S T E F F E C T S S R . F X         0 	        #include Shaderglobals.fx
#include Shadertextures.fx

struct VSInput
{
  float4 Position : POSITION0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Tex : TEXCOORD0;
};

struct PSOutput
{
  float4 Color : COLOR0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = mul(Projection, mul(View, mul(World, vsin.Position)));
  vsout.Tex = vsout.Position;
  return vsout;
}

float range,width,height,alpha;
int raysamples;
float4 bgcolor;
float4x4 ViewProj;

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  psin.Tex.xy=(psin.Tex.xy/psin.Tex.w)*float2(0.5,-0.5)+0.5;

  float3 position = tex2D(VariableTexture1Sampler,psin.Tex).rgb;
  float4 normalDepth = tex2D(VariableTexture2Sampler,psin.Tex);
  normalDepth.xyz=normalize(normalDepth.xyz);
  float3 lookdir = normalize(CameraPosition-position);

  lookdir = (lookdir+2*((dot(lookdir,normalDepth.xyz)*normalDepth.xyz)-lookdir))*(range/raysamples);

  float4 raypos = float4(position+lookdir,1);
  pso.Color.argb = float4(alpha,bgcolor.rgb);
  float tracing = 1;
  for(int i=0;i<raysamples;++i){
    float4 projpoint = mul(ViewProj, raypos);
    float2 tex = (projpoint.xy/projpoint.w)*float2(0.5,-0.5)+0.5;
    float sampledepth = tex2D(VariableTexture2Sampler,tex).a;
    sampledepth = sampledepth==0?1000.0:sampledepth;
    if ((tracing>0)&&(sampledepth<=length(raypos-CameraPosition))) {
       pso.Color.argb = float4(alpha,tex2D(VariableTexture3Sampler,tex).rgb);
       tracing = -1;
    }
    raypos.xyz += lookdir;
  }
  return pso;
}

technique MegaTec
{
   pass p0
   {
      VertexShader = compile vs_3_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
   }
} �  L   ��
 P O S T E F F E C T D I S T O R T I O N . F X       0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float rangex, rangey;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float2 offset = (tex2D(NormalTextureSampler,psin.Tex).rg - 0.5) * 2;
  //clip(dot(offset, offset) - 0.01);
  pso.Color = float4(tex2D(ColorTextureSampler,psin.Tex + (offset * float2(rangex, rangey))).rgb, 1);
  return pso;
}

#include FullscreenQuadFooter.fx
    @   ��
 P A R T I C L E S H A D E R . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

cbuffer local : register(b1)
{
  float4x4 InvView;
  float viewportheight, viewportwidth, Softparticlerange, Depthweightrange;
};

struct VSInput
{
  float3 Position : POSITION0;
  float3 Normal : NORMAL0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float3 Size : TEXCOORD1;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float2 DepthSize : COLOR1;
  #ifndef NONORMALCORRECTION
    float3 FragmentNormal : COLOR2;
  #endif
};

struct PSInput
{
  float2 vPos : VPOS;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float2 DepthSize : COLOR1;
  #ifndef NONORMALCORRECTION
    float3 FragmentNormal : COLOR2;
  #endif
};

struct PSOutput
{
  float4 NormalBuffer : COLOR0;
  float4 ColorBuffer : COLOR1;
  float4 CounterBuffer : COLOR2;
  #ifndef NOADDBUFFER
    float4 AdditionalBuffer : COLOR3;
  #endif
};

VSOutput MegaVertexShader(VSInput vsin) {
  VSOutput vsout;

  float4 Worldposition = float4(vsin.Position, 1);
  vsout.DepthSize = float2(distance(Worldposition.xyz, CameraPosition), min(vsin.Size.x, vsin.Size.y));
  float4 ViewPos = mul(View, Worldposition);
  vsout.Position = mul(Projection, ViewPos);
  #ifndef NONORMALCORRECTION
    vsout.FragmentNormal = normalize(ViewPos.xyz) * float3(1, -1, 1);
  #endif
  vsout.Tex = vsin.Tex;
  vsout.Color = vsin.Color;

  return vsout;
}

#ifdef HALFSIZEBUFFERS
	#define MAXDEPTH 300.0
#else
	#define MAXDEPTH 1000.0
#endif

PSOutput MegaPixelShader(PSInput psin){
  PSOutput pso;

  // draw billboards as unfilled black quads
  #ifdef SHOWBILLBOARDS
    pso.NormalBuffer = float4(0,1,0,psin.DepthSize.x);
    pso.ColorBuffer = float4(0,0,0,psin.DepthSize.x);
    pso.CounterBuffer = (abs(psin.Tex.x-0.5)>0.49)||(abs(psin.Tex.y-0.5)>0.49)?float4(1,1,1,1):float4(0,0,0,0);
    #ifndef NOADDBUFFER
      pso.AdditionalBuffer = pso.CounterBuffer;
    #endif
    return pso;
  #endif

  // read color and alpha of fragment, discard if too transparent (Alpha-Test)
  float4 Color = tex2D(ColorTextureSampler,psin.Tex)*psin.Color;
  clip(Color.a-0.001);

  // read scenedepth for fragmentposition from GBuffer
  float2 pixel_tex = (psin.vPos.xy + float2(0.5,0.5))/float2(viewportwidth,viewportheight);
  float Depth = tex2Dlod(VariableTexture1Sampler,float4(pixel_tex, 0.0, 0.0)).a;
  Depth = (Depth==0)?1000.0:Depth;

  // apply virtual texturmapping
  #if defined(SPHERICALMAPPING) || defined(CUBEMAPPING)
    float2 newTex = psin.Tex*2-1;

    float3 OriginSurfaceNormal = normalize(float3(newTex.x,newTex.y,sqrt(max(0,1-(newTex.x*newTex.x+newTex.y*newTex.y)))));
    float3 SurfaceNormal = OriginSurfaceNormal;

    // apply normalcorrection
    #ifndef NONORMALCORRECTION
      float3 NCNormal = normalize(psin.FragmentNormal);
      float3 NCTangent = cross(float3(0,1,0),NCNormal);
      float3 NCBinormal = cross(NCNormal,NCTangent);
      float3x3 orthogonalToPerspective = float3x3(NCTangent,NCBinormal,NCNormal);
      SurfaceNormal = normalize(mul((float3x3)orthogonalToPerspective, SurfaceNormal));
    #endif

    SurfaceNormal = normalize(mul((float3x3)InvView, SurfaceNormal*float3(1,-1,-1))*float3(-1,1,-1));

    float3 SurfaceTangent = cross(SurfaceNormal,float3(0,1,0));
    float3 SurfaceBinormal = cross(SurfaceTangent,SurfaceNormal);

    // apply either spheremapping or cubemapping
    #if !defined(CUBEMAPPING)
      newTex = SphereMap(SurfaceNormal);
    #else
      newTex = CubeMap(SurfaceNormal);
    #endif

    float4 NormalDepth = tex2Dlod(NormalTextureSampler,float4(newTex,0,0));
    float3 Normal = normalize(NormalDepth.rbg*2-1);

    float3x3 sphereToWorld = float3x3(SurfaceTangent,SurfaceNormal,SurfaceBinormal);
    Normal = mul((float3x3)View, mul(Normal,(float3x3)sphereToWorld)*float3(1,-1,1))*float3(-1,1,1);
    NormalDepth.a *= dot(OriginSurfaceNormal,float3(0,0,1));
  #else
    float4 NormalDepth = tex2D(NormalTextureSampler,psin.Tex);
    float3 Normal = normalize(NormalDepth.rgb*2-1);
    // apply normalcorrection
    #ifndef NONORMALCORRECTION
      float3 NCNormal = normalize(psin.FragmentNormal);
      float3 NCTangent = cross(float3(0,1,0),NCNormal);
      float3 NCBinormal = cross(NCNormal,NCTangent);
      float3x3 orthogonalToPerspective = float3x3(NCTangent,NCBinormal,NCNormal);
      Normal = mul((float3x3)orthogonalToPerspective,Normal);
    #endif
  #endif

  // apply depthadjustment
  #ifdef NODEPTHOFFSET
    float DepthOffset = 0;
  #else
    float DepthOffset = NormalDepth.a*psin.DepthSize.y/2;
  #endif

  psin.DepthSize.x -= DepthOffset;

  // apply depthweight
  #ifdef NODEPTHWEIGHT
	  float Weight = Color.a;
  #else
	  float Weight = Color.a*(exp((100.0-psin.DepthSize.x)/Depthweightrange));
  #endif
  // maxmimal particledepth
  pso.NormalBuffer.a = psin.DepthSize.x+2*DepthOffset;
  // weighted normal
  pso.NormalBuffer.rgb = normalize(Normal)*Weight;

  // slight visual improvement with tranlation of particles to the back while fading out, remove some plopping of the lighting
  #ifndef NOANTIDEPTHPLOPPING
    pso.NormalBuffer.a += (1-Color.a)*psin.DepthSize.y/2;
    psin.DepthSize.x += (1-Color.a)*psin.DepthSize.y/2;
  #endif

  // generate special data for rendering at lower resolutions
  #if defined(LOWRES) && !defined(NOLOWRES)
    // calculate minimal and maximal depth of the edges
    float4 NeighbourDepth = float4(tex2D(VariableTexture1Sampler,((psin.vPos+float2(1.5,0.5))/float2(viewportwidth,viewportheight))).a,
                                   tex2D(VariableTexture1Sampler,((psin.vPos+float2(0.5,-0.5))/float2(viewportwidth,viewportheight))).a,
                                   tex2D(VariableTexture1Sampler,((psin.vPos+float2(-0.5,0.5))/float2(viewportwidth,viewportheight))).a,
                                   tex2D(VariableTexture1Sampler,((psin.vPos+float2(0.5,1.5))/float2(viewportwidth,viewportheight))).a);

    NeighbourDepth = (NeighbourDepth.xyzw==float4(0.0f,0.0f,0.0f,0.0f))?float4(1000.0f,1000.0f,1000.0f,1000.0f):NeighbourDepth.xyzw;

    float NewDepth = min(Depth,min(NeighbourDepth.x,min(NeighbourDepth.y,min(NeighbourDepth.z,NeighbourDepth.w))));
    Depth = max(Depth,max(NeighbourDepth.x,max(NeighbourDepth.y,max(NeighbourDepth.z,NeighbourDepth.w))));

    pso.CounterBuffer.a = MAXDEPTH-NewDepth;
    // alpha with softparticles depended of the appropiate edge (mined or maxed)
    pso.CounterBuffer.r = Color.a * saturate((NewDepth-psin.DepthSize.x)/Softparticlerange);
    pso.CounterBuffer.g = Color.a * saturate((Depth-psin.DepthSize.x)/Softparticlerange);
  #else
    pso.CounterBuffer.a = 0;
    pso.CounterBuffer.rg = Color.a * saturate((Depth-psin.DepthSize.x)/Softparticlerange);
  #endif
  // write depthweight for the weightsum
  pso.CounterBuffer.b = Weight;

  // minimal particledepth
  pso.ColorBuffer.a = MAXDEPTH-psin.DepthSize.x;
  // weighted color
  pso.ColorBuffer.rgb = Weight * Color.rgb;

  // for linear density: write middle depth
  // for weighted alpha: write the count of written fragments with adjustment
  #ifndef NOADDBUFFER
    pso.AdditionalBuffer.a = pso.ColorBuffer.a;
	  #ifdef NOWEIGHTEDALPHASMOOTHING
      #if defined(LOWRES) && !defined(NOLOWRES)
  	    pso.AdditionalBuffer.rb = float2(1.0,((NewDepth-psin.DepthSize.x>0)?1.0:0.0));
      #else
  	    pso.AdditionalBuffer.rb = 1.0;
      #endif
      pso.AdditionalBuffer.g = (psin.DepthSize.x+DepthOffset);
	  #else
      #if defined(LOWRES) && !defined(NOLOWRES)
  	    pso.AdditionalBuffer.r = 1.0+pso.CounterBuffer.g;
        pso.AdditionalBuffer.b = ((NewDepth-psin.DepthSize.x>0)?1.0:0.0)+pso.CounterBuffer.r;
      #else
  	    pso.AdditionalBuffer.rb = 1.0+pso.CounterBuffer.g;
      #endif
      pso.AdditionalBuffer.g = (psin.DepthSize.x+DepthOffset)*pso.AdditionalBuffer.r;
	  #endif
  #endif

  return pso;
}

technique MegaTec
{
   pass p0
   {
     VertexShader = compile vs_3_0 MegaVertexShader();
     PixelShader = compile ps_3_0 MegaPixelShader();
   }
}
  I  \   ��
 P O S T E F F E C T D R A W P A R T I C L E B U F F E R . F X       0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  #ifdef DRAWNORMAL
    float Density = tex2D(MaterialTextureSampler,psin.Tex).b;
    pso.Color.rgb = (Density==0)?float3(0.5,0.5,1.0):(normalize(tex2D(ColorTextureSampler,psin.Tex).rgb/Density)/2+0.5);
  #endif
  #ifdef DRAWCOLOR
    float Density = tex2D(MaterialTextureSampler,psin.Tex).b;
    pso.Color.rgb = (Density==0)?float3(0,0,0):(tex2D(NormalTextureSampler,psin.Tex).rgb/Density);
  #endif
  #ifdef DRAWDENSITY
    float2 Density = (tex2D(MaterialTextureSampler,psin.Tex).rg);
    float n =  tex2D(VariableTexture2Sampler,psin.Tex).r;
    pso.Color.bg = saturate(1-pow(1-Density.r/n,n));
    pso.Color.r = saturate(1-pow(1-Density.g/n,n));
  #endif
  #ifdef DRAWDEPTH
    float2 Depth = float2(tex2D(ColorTextureSampler,psin.Tex).a,1000.0-tex2D(NormalTextureSampler,psin.Tex).a);
    pso.Color.rgb = float3(1-saturate(Depth.y/50.0),0*abs(Depth.x-Depth.y)/50.0,0*abs(Depth.x-Depth.y)/50.0);
  #endif
  #ifdef DRAWMIDDLEDEPTH
    float2 FBDepth = float2(tex2D(ColorTextureSampler,psin.Tex).a,1000.0-tex2D(NormalTextureSampler,psin.Tex).a);
    float2 Depth = tex2D(VariableTexture2Sampler,psin.Tex).rg;
    pso.Color.rgb = abs((Depth.g/Depth.r)-(FBDepth.x+FBDepth.y)/2)/10.0;
  #endif
  #ifdef DRAWLIGHT
    pso.Color.rgb = tex2D(VariableTexture1Sampler,psin.Tex).rgb;
  #endif
  return pso;
}

technique MegaTec
{
   pass p0
   {
      VertexShader = compile vs_2_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
   }
}
   �  t   ��
 P A R T I C L E D E F E R R E D D I R E C T I O N A L A M B I E N T L I G H T . F X         0 	        #include Shaderglobals.fx
#include Shadertextures.fx

cbuffer local : register(b1)
{
  float pixelwidth, pixelheight, testvalue;
};

struct VSInput
{
  float3 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = float4(vsin.Position, 1);
  #ifdef DX9
    vsout.Position.xy -= float2(pixelwidth, -pixelheight);
  #endif
  vsout.Tex = vsin.Tex;
  return vsout;
}

struct PSOutput
{
  float4 Color : COLOR0;
  #ifdef LIGHTBUFFER
    float4 Lightbuffer : COLOR1;
  #endif
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;

  // discard fragment if no particles has drawn to this pixel
  float4 DensityCounter = tex2D(VariableTexture1Sampler,psin.Tex);
  clip(DensityCounter.g-0.0001);
  pso.Color.a=DensityCounter.g;
  float4 NormalMaxDepth = tex2D(ColorTextureSampler,psin.Tex);

  // fetch weighted normal, an enlight the particleeffekt with given directional light
  float3 Normal = NormalMaxDepth.rgb / DensityCounter.b;
  float3 Beleuchtung = BeleuchtungsBerechnung(normalize(Normal),DirectionalLightDir)*DirectionalLightColor.rgb*DirectionalLightColor.a;

  pso.Color.rgb = Beleuchtung;

  return pso;
}

technique MegaTec
{
   pass p0
   {
     VertexShader = compile vs_3_0 MegaVertexShader();
     PixelShader = compile ps_3_0 MegaPixelShader();
   }
}
      L   ��
 P A R T I C L E T O B A C K B U F F E R . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

cbuffer local : register(b1)
{
  float pixelwidth, pixelheight, Softparticlerange, Aliasingrange, width, weight, Solidness;
};

struct VSInput
{
  float3 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = float4(vsin.Position, 1);
  #ifdef DX9
    vsout.Position.xy -= float2(pixelwidth, -pixelheight);
  #endif
  vsout.Tex = vsin.Tex;
  return vsout;
}

#ifdef HALFSIZEBUFFERS
	#define MAXDEPTH 300.0
#else
	#define MAXDEPTH 1000.0
#endif

struct PSOutput
{
  float4 Color : COLOR0;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;

  float4 DensityCounter = tex2D(NormalTextureSampler,psin.Tex);

  float4 ColorMinDepth = tex2D(ColorTextureSampler,psin.Tex);
  ColorMinDepth.rgb = saturate(ColorMinDepth.rgb / DensityCounter.b);

  // apply computation in case of rendering to a lower resolution
  #if defined(LOWRES) && !defined(NOLOWRES) && !defined(NOLOWRESFILLING)

    float SceneDepth = tex2D(VariableTexture2Sampler,psin.Tex).a;
    SceneDepth = (SceneDepth==0)?1000.0:SceneDepth;
    float ParticleFrontDepth = MAXDEPTH-ColorMinDepth.w;

    #ifdef DRAWLOWRESEDGES
      pso.Color.a = 1;
      pso.Color.rgb = saturate((SceneDepth-(MAXDEPTH-DensityCounter.a))-Aliasingrange*SceneDepth);
      return pso;
    #endif

    // filter values at upsampling
    #ifndef NOLOWRESFILTERING
      // build coords for bilinear quad
      float2 uv = trunc(psin.Tex*float2(width,height))/float2(width,height);
      uv = (psin.Tex-uv)/float2(pixelwidth,pixelheight);

      float2 offset = round(uv)*2-1.0;

      uv=offset*(uv-0.5);
	  
	    float4x2 texCoords = float4x2(
                                psin.Tex,
                                psin.Tex+float2(offset.x*pixelwidth,0),
                                psin.Tex+float2(0,offset.y*pixelheight),
                                psin.Tex+float2(offset.x*pixelwidth,offset.y*pixelheight));

      // (a,rgb) = (density in front of scene, lightingintensity)
      float4x4 NeighbourLighting = float4x4(
                                     tex2D(VariableTexture1Sampler,texCoords[0]),
                                     tex2D(VariableTexture1Sampler,texCoords[1]),
                                     tex2D(VariableTexture1Sampler,texCoords[2]),
                                     tex2D(VariableTexture1Sampler,texCoords[3]));

      // (a,r) = (expanded edge depth, density in front of expanded edge scene)
      float4x3 NeighbourDensity = float4x3(
                                     DensityCounter.arb,
                                     tex2D(NormalTextureSampler,texCoords[1]).arb,
                                     tex2D(NormalTextureSampler,texCoords[2]).arb,
                                     tex2D(NormalTextureSampler,texCoords[3]).arb);
									 
	  float4x3 NeighbourColor = float4x3(
                                     ColorMinDepth.rgb,
                                     saturate(tex2D(ColorTextureSampler,texCoords[1]).rgb/NeighbourDensity[1].b),
                                     saturate(tex2D(ColorTextureSampler,texCoords[2]).rgb/NeighbourDensity[2].b),
                                     saturate(tex2D(ColorTextureSampler,texCoords[3]).rgb/NeighbourDensity[3].b));

      #if !(defined(NOWEIGHTEDALPHA) || defined(NOADDBUFFER))
        // (a,r) = written fragment count in front of (scene, expanded edge scene)
        float4x2 NeighbourCount = float4x2(
                                     tex2D(MaterialTextureSampler,texCoords[0]).rb,
                                     tex2D(MaterialTextureSampler,texCoords[1]).rb,
                                     tex2D(MaterialTextureSampler,texCoords[2]).rb,
                                     tex2D(MaterialTextureSampler,texCoords[3]).rb);
        // compute resulting alpha with weighted alpha - algorithm
        NeighbourDensity._12_22_32_42 = saturate((1-pow(1-NeighbourDensity._12_22_32_42/Solidness/NeighbourCount._12_22_32_42,NeighbourCount._12_22_32_42)));
        NeighbourLighting._14_24_34_44 = saturate((1-pow(1-NeighbourLighting._14_24_34_44/Solidness/NeighbourCount._11_21_31_41,NeighbourCount._11_21_31_41)));
      #endif

	  // filter lighting and scenefront-density, prevent filtering non written values
	  if (!any(NeighbourLighting[0].rgb)) NeighbourLighting[0].rgb = NeighbourLighting[1].rgb;
	  if (!any(NeighbourLighting[1].rgb)) NeighbourLighting[1].rgb = NeighbourLighting[0].rgb;
    float4 x1 = lerp(NeighbourLighting[0],NeighbourLighting[1],uv.x);
	  if (!any(NeighbourLighting[2].rgb)) NeighbourLighting[2].rgb = NeighbourLighting[3].rgb;
	  if (!any(NeighbourLighting[3].rgb)) NeighbourLighting[3].rgb = NeighbourLighting[2].rgb;
    float4 x2 = lerp(NeighbourLighting[2],NeighbourLighting[3],uv.x);
	  if (!any(NeighbourLighting[2].rgb+NeighbourLighting[3].rgb)) x2.rgb = x1.rgb;
	  if (!any(NeighbourLighting[0].rgb+NeighbourLighting[1].rgb)) x1.rgb = x2.rgb;
    float4 Lighting = lerp(x1,x2,uv.y);

    // eliminate Halos
    float4 NeighbourDensities = ((SceneDepth-(MAXDEPTH-NeighbourDensity._11_21_31_41))>Aliasingrange*SceneDepth?Lighting.aaaa:NeighbourDensity._12_22_32_42);

    float d1 = lerp(NeighbourDensities[0],NeighbourDensities[1],uv.x);
	  float d2 = lerp(NeighbourDensities[2],NeighbourDensities[3],uv.x);
    DensityCounter.r = lerp(d1,d2,uv.y);
	  
	  //fill color for outer edge
	  if (!any(ColorMinDepth.rgb)) ColorMinDepth.rgb = max(NeighbourColor[1],max(NeighbourColor[2],NeighbourColor[3]));

    #ifdef DRAWFILTERUVS
      pso.Color = float4(uv,0,DensityCounter.r);
      return pso;
    #endif

    #else
      float4 Lighting = tex2D(VariableTexture1Sampler,psin.Tex);
      float2 n = tex2D(MaterialTextureSampler,psin.Tex).rb;
      Lighting.a = saturate((1-pow(1-Lighting.a/Solidness/n.x,n.x)));
      DensityCounter.r = saturate((1-pow(1-DensityCounter.r/Solidness/n.y,n.y)));
    #endif

    //fill in inner edges
    float Aliasingweight = lerp(DensityCounter.r,Lighting.a,saturate((SceneDepth-(MAXDEPTH-DensityCounter.a))-Aliasingrange*SceneDepth));

    pso.Color.a = saturate(Aliasingweight);

  #else
    float3 Lighting = tex2D(VariableTexture1Sampler,psin.Tex).rgb;
    #if defined(NOWEIGHTEDALPHA) || defined(NOADDBUFFER)
      pso.Color.a = saturate(DensityCounter.r/Solidness);
    #else
      float n = tex2D(MaterialTextureSampler,psin.Tex).r;
      pso.Color.a = saturate((1-pow(saturate(1-DensityCounter.r/n/Solidness),n)));
    #endif
  #endif

  // for testing apply lighting only depending of the transparency
  #ifndef SOFTSCATTERING
    pso.Color.rgb = ColorMinDepth.rgb*Lighting.rgb;
  #else
    pso.Color.rgb = ColorMinDepth.rgb*(Lighting.rgb*pso.Color.a+1-pso.Color.a);
  #endif


  return pso;
}

technique MegaTec
{
   pass p0
   {
      VertexShader = compile vs_3_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
   }
}
�  X   ��
 P A R T I C L E D E F E R R E D P O I N T L I G H T . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

cbuffer local : register(b1)
{
  float3 CornerLT;
  float width;
  float3 CornerRT;
  float height;
  float3 CornerLB;
  float testvalue;
  float3 CornerRB;
  float ScatteringStrength;
  float4x4 OnlyView;
};

struct VSInput
{
  float3 Position : POSITION0;
  float4 Color : COLOR0;
  float3 WorldPositionCenter : TEXCOORD0;
  float3 Range : TEXCOORD1;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD1;
  float3 WorldPositionCenter : TEXCOORD2;
  float3 Range : TEXCOORD3;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = mul(Projection, mul(View, float4(vsin.Position, 1)));
  vsout.Tex = ((float2(vsout.Position.x,-vsout.Position.y)/vsout.Position.w)+1)/2;
  #ifdef DX9
    vsout.Tex -= 0.5/viewport_size;
  #endif
  vsout.WorldPositionCenter = vsin.WorldPositionCenter;
  vsout.Color = vsin.Color;
  vsout.Range = vsin.Range;
  return vsout;
}

struct PSOutput
{
  float4 Color : COLOR0;
};

/*
  Calculates the minimal distance between a line and a point. LineDir expected to be normalized.
*/
float DistanceLinePoint(float3 Linestart, float3 LineDir, float3 Point){
  return length(cross(LineDir,Point-Linestart));
}

#ifdef HALFSIZEBUFFERS
	#define MAXDEPTH 300.0
#else
	#define MAXDEPTH 1000.0
#endif

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  // discard fragment if no particles has drawn to this pixel
  float4 DensityCounter = tex2D(VariableTexture1Sampler,psin.Tex);
  clip(DensityCounter.g - 0.0001);
  float4 NormalMaxDepth = tex2D(ColorTextureSampler,psin.Tex);
  float4 ColorMinDepth = tex2D(NormalTextureSampler,psin.Tex);
  ColorMinDepth.a = MAXDEPTH - ColorMinDepth.a;
  float3 Normal = normalize(NormalMaxDepth.rgb/DensityCounter.b);

  // calculate the intersection of particlecloud and pointlight on the viewray
  float3 ViewDir = normalize(lerp(lerp(CornerLT,CornerRT,psin.Tex.x),lerp(CornerLB,CornerRB,psin.Tex.x),psin.Tex.y));
  float3 Position = ViewDir * ColorMinDepth.a + CameraPosition;

  float ViewSegDepth = dot(ViewDir,psin.WorldPositionCenter-CameraPosition);
  float DistanceViewSegSphere = clamp(DistanceLinePoint(CameraPosition,ViewDir,psin.WorldPositionCenter),0 , psin.Range.x);
  float ViewSegThickness = sqrt((psin.Range.x*psin.Range.x)-(DistanceViewSegSphere*DistanceViewSegSphere));

  float EnlightedSegFront = clamp(ViewSegDepth-ViewSegThickness,ColorMinDepth.a,NormalMaxDepth.a);
  float EnlightedSegBack = clamp(ViewSegDepth+ViewSegThickness,ColorMinDepth.a,NormalMaxDepth.a);
  float VolumeThickness = NormalMaxDepth.a-ColorMinDepth.a;
  float Scattering = 0;
  // approximate light intensity scattered on the segment, horizontal and longitudinal
  float horizontal = (1 - pow(saturate(DistanceViewSegSphere / psin.Range.x), psin.Range.y + 1)) * (psin.Range.z + 1);
  float longitudinal = saturate((EnlightedSegBack - EnlightedSegFront)/(2 * ViewSegThickness));
  float LightIntensity = horizontal * longitudinal;

  // branch the use of linear density
  /*
  #if !defined(NOADDBUFFER) && !defined(NOLINEARDENSITY)
    float2 MiddleDepth = tex2D(VariableTexture2Sampler,psin.Tex).rg;
    MiddleDepth.g /= MiddleDepth.r;
    float DistanceFrontMiddle = abs(MiddleDepth.g - ColorMinDepth.a);
    float DistanceBackMiddle = abs(NormalMaxDepth.a - MiddleDepth.g);
    float MiddleDensity = 2;
    //  front Segment
    float DistanceLightMiddle = MiddleDepth.g - EnlightedSegFront;
    float LightDensity = MiddleDensity * (1-DistanceLightMiddle/(DistanceFrontMiddle>=0?DistanceFrontMiddle:DistanceBackMiddle));
    float LightSeg = abs(DistanceLightMiddle);
    float EnlightedDensity = sign(DistanceLightMiddle)*(LightSeg*(LightDensity+MiddleDensity))/2;
    //  attenuating Front
    float AttenuatingDensity = clamp((DistanceFrontMiddle/VolumeThickness)-EnlightedDensity + 1,1,MAXDEPTH);
    //  back Segment
    DistanceLightMiddle = EnlightedSegBack - MiddleDepth.g;
    LightDensity = MiddleDensity * (1-DistanceLightMiddle/(DistanceBackMiddle>=0?DistanceBackMiddle:DistanceFrontMiddle));
    LightSeg = abs(DistanceLightMiddle);
    EnlightedDensity += sign(DistanceLightMiddle)*(LightSeg*(LightDensity+MiddleDensity))/2;

    Scattering = (1-saturate(AttenuatingDensity/EnlightedDensity)) * LightIntensity;
  #else
  */
    float EnlightedSegThickness = EnlightedSegBack - EnlightedSegFront;
    float AttenuatingFrontThickness = EnlightedSegFront - ColorMinDepth.a;
    Scattering = (EnlightedSegThickness/(EnlightedSegThickness+AttenuatingFrontThickness)) * LightIntensity;
  //#endif

  // branch if no direct illumination should be used
  #ifndef ONLYSCATTERING
    float3 Light = mul((float3x3)OnlyView, normalize(psin.WorldPositionCenter - Position));
	// compute pointlight intensity
    float dist = distance(psin.WorldPositionCenter,Position);
    float intensity = (1 - pow(saturate(dist / psin.Range.x), psin.Range.y + 1)) * (psin.Range.z + 1);
    float3 Beleuchtung = BeleuchtungsBerechnung(Normal,Light) * intensity;

    pso.Color.rgb = (0.85 * Beleuchtung + saturate(ScatteringStrength * Scattering)) * psin.Color.rgb * psin.Color.a;
  #else
    pso.Color.rgb = ScatteringStrength * Scattering * psin.Color.rgb * psin.Color.a;
  #endif
  pso.Color.a = 0;
  return pso;
}

technique MegaTec
{
    pass p0
    {
      VertexShader = compile vs_3_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
    }
}
  �
  H   ��
 D E F E R R E D S P O T L I G H T . F X         0 	        #include Shaderglobals.fx
#include Shadertextures.fx

struct VSInput
{
  float3 Position : POSITION0;
  float4 Color : COLOR0;
  float3 Direction : TEXCOORD0;
  float3 SourcePosition : TEXCOORD1;
  float3 RangeThetaPhi : TEXCOORD2;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float3 ScreenTex : TEXCOORD0;
  float3 Direction : TEXCOORD1;
  float3 SourcePosition : TEXCOORD2;
  float3 RangeThetaPhi : TEXCOORD3;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = mul(Projection, mul(View, float4(vsin.Position, 1)));
  vsout.ScreenTex = float3(vsout.Position.x,-vsout.Position.y,vsout.Position.w);
  vsout.SourcePosition = vsin.SourcePosition;
  vsout.Color = vsin.Color;
  vsout.Direction = vsin.Direction;
  vsout.RangeThetaPhi = vsin.RangeThetaPhi;
  return vsout;
}

struct PSOutput
{
  float4 Color : COLOR0;
  #ifdef LIGHTBUFFER
    float4 Lightbuffer : COLOR1;
  #endif
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  psin.ScreenTex.xy = ((psin.ScreenTex.xy/psin.ScreenTex.z)+1)/2;
  #ifdef DX9
    psin.ScreenTex.xy -= 0.5/viewport_size;
  #endif
  float4 Color = tex2D(ColorTextureSampler,psin.ScreenTex.xy);
  clip(Color.a-0.001);
  float3 Position = (tex2D(VariableTexture1Sampler,psin.ScreenTex.xy).rgb);
  float3 Light = normalize(psin.SourcePosition-Position);
  float3 Halfway = normalize(normalize(CameraPosition-Position)+Light);
  float3 Normal = normalize(tex2D(NormalTextureSampler,psin.ScreenTex.xy).rgb);
  float3 Beleuchtung = BeleuchtungsBerechnung(Normal,Light)*saturate(1-(distance(psin.SourcePosition,Position)/psin.RangeThetaPhi.x));
  float4 Material = tex2D(VariableTexture2Sampler,psin.ScreenTex.xy);
  float Spotlightfactor = saturate((dot(-Light,psin.Direction)-psin.RangeThetaPhi.z)/(psin.RangeThetaPhi.y-psin.RangeThetaPhi.z));
  float3 Specular = lerp(psin.Color.rgb, Color.rgb, Material.b) * pow(saturate(dot(Normal,Halfway)),(Material.g*255)) * Material.r;
  pso.Color.rgb = (Color.rgb+Specular)*(Beleuchtung*psin.Color.rgb)*psin.Color.a;// + (Color.rgb * Material.a); Shading Reduction only for Directional light and Ambient
  pso.Color.a = Color.a * Spotlightfactor;
  #ifdef LIGHTBUFFER
    pso.Lightbuffer = float4((1+Specular)*(Beleuchtung*psin.Color.rgb)*psin.Color.a, 1);// + (Color.rgb * Material.a),1);
  #endif
  return pso;
}

technique MegaTec
{
    pass p0
    {
        #ifdef LIGHTBUFFER
          VertexShader = compile vs_3_0 MegaVertexShader();
          PixelShader = compile ps_3_0 MegaPixelShader();
        #else
          VertexShader = compile vs_2_0 MegaVertexShader();
          PixelShader = compile ps_2_0 MegaPixelShader();
        #endif
    }
}
   �  X   ��
 P A R T I C L E D E F E R R E D S P O T L I G H T . F X         0 	        #include Shaderglobals.fx
#include Shadertextures.fx

cbuffer local : register(b1)
{
  float3 CornerLT;
  float width;
  float3 CornerRT;
  float height;
  float3 CornerLB;
  float testvalue;
  float3 CornerRB;
  float ScatteringStrength;
  float4x4 OnlyView;
};

struct VSInput
{
  float3 Position : POSITION0;
  float4 Color : COLOR0;
  float3 Direction : TEXCOORD0;
  float3 SourcePosition : TEXCOORD1;
  float3 RangeThetaPhi : TEXCOORD2;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float3 ScreenTex : TEXCOORD0;
  float3 Direction : TEXCOORD1;
  float3 SourcePosition : TEXCOORD2;
  float3 RangeThetaPhi : TEXCOORD3;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = mul(Projection, mul(View, float4(vsin.Position, 1)));
  vsout.ScreenTex = float3(vsout.Position.x,-vsout.Position.y,vsout.Position.w);
  vsout.SourcePosition = vsin.SourcePosition;
  vsout.Color = vsin.Color;
  vsout.Direction = vsin.Direction;
  vsout.RangeThetaPhi = vsin.RangeThetaPhi;
  return vsout;
}

struct PSOutput
{
  float4 Color : COLOR0;
  #ifdef LIGHTBUFFER
    float4 Lightbuffer : COLOR1;
  #endif
};

/*
  Calculates the minimal distance between a line and a point. LineDir expected to be normalized.
*/
float DistanceLinePoint(float3 Linestart, float3 LineDir, float3 Point){
  return length(cross(LineDir,Point-Linestart));
}

#ifdef HALFSIZEBUFFERS
	#define MAXDEPTH 300.0
#else
	#define MAXDEPTH 1000.0
#endif

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  psin.ScreenTex.xy = ((psin.ScreenTex.xy/psin.ScreenTex.z)+1)/2;
  #ifdef DX9
    psin.ScreenTex.xy -= 0.5/viewport_size;
  #endif

  // discard fragment if no particles has drawn to this pixel
  float4 DensityCounter = tex2D(VariableTexture1Sampler,psin.ScreenTex.xy);
  clip(DensityCounter.g-0.0001);
  float4 NormalMaxDepth = tex2D(ColorTextureSampler,psin.ScreenTex.xy);
  float4 ColorMinDepth = tex2D(NormalTextureSampler,psin.ScreenTex.xy);
  ColorMinDepth.a = MAXDEPTH - ColorMinDepth.a;
  float3 Normal = normalize(NormalMaxDepth.rgb/DensityCounter.b);

  float3 ViewDir = normalize(lerp(lerp(CornerLT,CornerRT,psin.ScreenTex.x),lerp(CornerLB,CornerRB,psin.ScreenTex.x),psin.ScreenTex.y));
  float3 Position = ViewDir * ColorMinDepth.a + CameraPosition;

  float Scattering = 0;
  // calculate the intersectionpoints of viewdir and cone
  float3 CamCone = (psin.SourcePosition-CameraPosition);
  float3 n = normalize(cross(ViewDir,CamCone));
  n = n*(dot(n,psin.Direction)>0?-1:1);

  float cosphi = sqrt(1-dot(n,psin.Direction)*dot(n,psin.Direction));
  
  if (cosphi<psin.RangeThetaPhi.z) discard;
  
  float tanphi = tan(acos(cosphi));
  float tanalpha = tan(acos(psin.RangeThetaPhi.z));

  float3 u = normalize(cross(psin.Direction,n));
  float3 w = normalize(cross(u,psin.Direction));

  float3 temp = sqrt(tanalpha*tanalpha-tanphi*tanphi)*u;
  float3 delta1 = (psin.Direction + (tanphi*w) + temp);
  float3 delta2 = (psin.Direction + (tanphi*w) - temp);

  float3 crossvec = cross(ViewDir,delta1);
  float r1 = (dot(cross(CamCone,delta1),crossvec)/dot(crossvec,crossvec));
  crossvec = cross(ViewDir,delta2);
  float r2 = (dot(cross(CamCone,delta2),crossvec)/dot(crossvec,crossvec));
  
  float3 intersect1 = r1 * ViewDir + CameraPosition;
  float3 intersect2 = r2 * ViewDir + CameraPosition;

  float3 ConeBottom = (psin.RangeThetaPhi.x*psin.Direction)+psin.SourcePosition;
  float conebottomintersectdepth =(dot((ConeBottom-CameraPosition),psin.Direction)/dot(psin.Direction,ViewDir));
  float3 conebottomintersection=conebottomintersectdepth*ViewDir+CameraPosition;

  r1 = dot((intersect1-psin.SourcePosition),psin.Direction)<0?conebottomintersectdepth:r1;
  r2 = dot((intersect2-psin.SourcePosition),psin.Direction)<0?conebottomintersectdepth:r2;
  
  r1 = dot((intersect1-conebottomintersection),psin.Direction)>0?conebottomintersectdepth:r1;
  r2 = dot((intersect2-conebottomintersection),psin.Direction)>0?conebottomintersectdepth:r2;
  
  float rtemp=r1;
  r1=min(r1,r2);
  r2=max(rtemp,r2);
  
  intersect1 = r1 * ViewDir + CameraPosition;
  intersect2 = r2 * ViewDir + CameraPosition;

  // compute attenuation of the scattered light
  float3 middlepos = (0.5*(r1+r2))*ViewDir+CameraPosition;
  float middlerange = distance(middlepos,psin.SourcePosition);
  float3 linecross = cross(psin.Direction,normalize(ViewDir));
  float middleangle = (abs(dot((CameraPosition - psin.SourcePosition),linecross)) / length(linecross)) /middlerange;
  middleangle = sqrt(1-middleangle*middleangle);// derived of the formula: cos(asin(x))=sqrt(1-x�)

  float3 tempPlane = cross(psin.Direction,ViewDir);
  float distanceFromMiddle = abs(dot(tempPlane,CameraPosition-psin.SourcePosition));

  float Spotlightfactor = saturate((middleangle-psin.RangeThetaPhi.z)/(psin.RangeThetaPhi.y-psin.RangeThetaPhi.z));
  float Rangefactor = saturate(1-(min(distance(intersect1,psin.SourcePosition),distance(intersect2,psin.SourcePosition))/psin.RangeThetaPhi.x));

  // calculate the intersection of particlecloud and spotlight on the viewray
  float EnlightedSegFront = clamp(r1,ColorMinDepth.a,NormalMaxDepth.a);
  float EnlightedSegBack = clamp(r2,ColorMinDepth.a,NormalMaxDepth.a);
  float VolumeThickness = NormalMaxDepth.a-ColorMinDepth.a;
  float LightAttenuation = saturate(Spotlightfactor * Rangefactor * saturate(EnlightedSegBack-EnlightedSegFront));

  // branch the use of linear density
  #if !defined(NOADDBUFFER) && !defined(NOLINEARDENSITY)
    float2 MiddleDepth = tex2D(VariableTexture2Sampler,psin.ScreenTex.xy).rg;
    MiddleDepth.g /= MiddleDepth.r;
    float DistanceFrontMiddle = abs(MiddleDepth.g - ColorMinDepth.a);
    float DistanceBackMiddle = abs(NormalMaxDepth.a - MiddleDepth.g);
    float MiddleDensity = 2;
    //  front Segment
    float DistanceLightMiddle = MiddleDepth.g - EnlightedSegFront;
    float LightDensity = MiddleDensity * (1-DistanceLightMiddle/(DistanceFrontMiddle>=0?DistanceFrontMiddle:DistanceBackMiddle));
    float LightSeg = abs(DistanceLightMiddle);
    float EnlightedDensity = sign(DistanceLightMiddle)*(LightSeg*(LightDensity+MiddleDensity))/2;
    //  attenuating Front
    float AttenuatingDensity = clamp((DistanceFrontMiddle/VolumeThickness)-EnlightedDensity,0,MAXDEPTH);
    //  back Segment
    DistanceLightMiddle = EnlightedSegBack - MiddleDepth.g;
    LightDensity = MiddleDensity * (1-DistanceLightMiddle/(DistanceBackMiddle>=0?DistanceBackMiddle:DistanceFrontMiddle));
    LightSeg = abs(DistanceLightMiddle);
    EnlightedDensity += sign(DistanceLightMiddle)*(LightSeg*(LightDensity+MiddleDensity))/2;

    Scattering = saturate((EnlightedDensity/(EnlightedDensity+AttenuatingDensity)) * LightAttenuation);
  #else
    float EnlightedSegThickness = EnlightedSegBack - EnlightedSegFront;
    float AttenuatingFrontThickness = EnlightedSegFront - ColorMinDepth.a;
    Scattering = saturate((EnlightedSegThickness/(EnlightedSegThickness+AttenuatingFrontThickness)) * LightAttenuation);
  #endif

  // branch if no direct illumination should be used
  #ifndef ONLYSCATTERING
    float3 Lightdirection = normalize(psin.SourcePosition-Position);
    float3 Light = mul((float3x3)OnlyView, Lightdirection);
    float3 Beleuchtung = BeleuchtungsBerechnung(Normal,Light)*saturate(1-(distance(psin.SourcePosition,Position)/psin.RangeThetaPhi.x));
    float Spotlightfactor2 = saturate((dot(-Lightdirection,psin.Direction)-psin.RangeThetaPhi.z)/(psin.RangeThetaPhi.y-psin.RangeThetaPhi.z));
    pso.Color.rgb = (0.85*Beleuchtung*Spotlightfactor2+ScatteringStrength*Scattering)*psin.Color.rgb*psin.Color.a;
  #else
    pso.Color.rgb = ScatteringStrength*Scattering*psin.Color.rgb*psin.Color.a;
  #endif
  pso.Color.a = 0;

  return pso;
}

technique MegaTec
{
    pass p0
    {
        VertexShader = compile vs_3_0 MegaVertexShader();
        PixelShader = compile ps_3_0 MegaPixelShader();
    }
}
 �  <   ��
 P A R T I C L E V B A O . F X       0 	        #include Shaderglobals.fx

//Texturslots
texture ColorTexture;//Slot0
texture NormalTexture;   //Slot1
texture MaterialTexture;  //Slot2
texture VariableTexture1;  //Slot3
texture VariableTexture2;  //Slot4
texture VariableTexture3;  //Slot5
texture VariableTexture4;  //Slot6

//Sampler f�r Texturzugriff
sampler ColorTextureSampler = sampler_state
{
  texture = <ColorTexture>;
  MipFilter = FILTERART;
  MagFilter = FILTERART;
  MinFilter = FILTERART;
  AddressU = Border;
  AddressV = Border;
  BorderColor = {0,0,0,0};
};

sampler NormalTextureSampler = sampler_state
{
  texture = <NormalTexture>;
  MipFilter = FILTERART;
  MagFilter = FILTERART;
  MinFilter = FILTERART;
  AddressU = Border;
  AddressV = Border;
  BorderColor = {0,0,0,0};
};

sampler VariableTexture1Sampler = sampler_state
{
  texture = <VariableTexture1>;
  MipFilter = FILTERART;
  MagFilter = FILTERART;
  MinFilter = FILTERART;
  AddressU = Border;
  AddressV = Border;
  BorderColor = {0,0,0,0};
};

sampler VariableTexture2Sampler = sampler_state
{
  texture = <VariableTexture2>;
  MipFilter = FILTERART;
  MagFilter = FILTERART;
  MinFilter = FILTERART;
};

sampler SpecularSampler = sampler_state
{
  texture = <MaterialTexture>;
  MipFilter = POINT;
  MagFilter = POINT;
  MinFilter = POINT;
};

sampler VariableTexture3Sampler = sampler_state
{
  texture = <VariableTexture3>;
  MipFilter = POINT;
  MagFilter = POINT;
  MinFilter = POINT;
};
sampler VariableTexture4Sampler = sampler_state
{
  texture = <VariableTexture4>;
  MipFilter = POINT;
  MagFilter = POINT;
  MinFilter = POINT;
};

struct VSInput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct PSOutput
{
  float4 Color : COLOR0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = mul(Projection, vsin.Position);
  vsout.Tex = vsin.Tex;
  return vsout;
}

cbuffer local : register(b1)
{
  float4x4 ViewProjection, Proj;
  float range, width, height, JumpMax, ParticleInfluence;
  float4 Kernel[KERNELSIZE];
};

#define BIAS 0.1
#define EPSILON 0.000001

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float occlusion = 0.0;
  float4 normalDepth = tex2D(NormalTextureSampler,psin.Tex);
  normalDepth.xyz=normalize(normalDepth.xyz);
  clip(normalDepth.w-0.01);
  float4 position = float4(tex2D(ColorTextureSampler,psin.Tex).rgb,1);
  position.xyz += normalDepth.xyz*(range/2.0);
  normalDepth.w = length(position-CameraPosition);
  position = mul(ViewProjection, position);
  position.xy /= position.w;
  position.xy = position.xy*float2(0.5,-0.5)+0.5;
  float3 noise = tex2D(VariableTexture2Sampler,psin.Tex*float2(width,height)).rgb;
  float normalization = EPSILON;
  for(int i=0;i<KERNELSIZE;++i){
     float4 sampleCoord = mul(Proj, float4(Kernel[i].xy,normalDepth.w,1));
     sampleCoord.xy /= sampleCoord.w;
     sampleCoord.xy = float2(sampleCoord.x*noise.x-sampleCoord.y*noise.y,sampleCoord.x*noise.y+sampleCoord.y*noise.x)+position.xy;
     float sampleZ = tex2D(NormalTextureSampler,sampleCoord.xy).a;
     //background is 0.0 but must be infinite far away
     sampleZ = (sampleZ==0.0)?1000.0:sampleZ;
     float zEntry = normalDepth.w - Kernel[i].z;
     //x - Back; y - Front
     float2 ParticleDepth = float2(tex2D(VariableTexture3Sampler,sampleCoord.xy).a,1000.0-tex2D(VariableTexture4Sampler,sampleCoord.xy).a);
     // compute intersection of ssao-sphere with particlecloud
     if (ParticleDepth.y<999.0) {
       float4 DensityCounter = tex2D(SpecularSampler,sampleCoord.xy);
       float EnlightedSegFront = max(zEntry,ParticleDepth.y);
       float EnlightedSegBack = min(sampleZ,ParticleDepth.x);
       float2 MiddleDepth = tex2D(VariableTexture1Sampler,psin.Tex).rg;
       MiddleDepth.g /= MiddleDepth.r;
       float DistanceFrontMiddle = abs(MiddleDepth.g - ParticleDepth.y);
       float DistanceBackMiddle = abs(ParticleDepth.x - MiddleDepth.g);
       float MiddleDensity = DensityCounter.g * 2;
       //front Segment
       float DistanceLightMiddle = MiddleDepth.g - EnlightedSegFront;
       float LightDensity = MiddleDensity * (1-DistanceLightMiddle/(DistanceFrontMiddle>=0?DistanceFrontMiddle:DistanceBackMiddle));
       float LightSeg = abs(DistanceLightMiddle);
       float EnlightedDensity = sign(DistanceLightMiddle)*(LightSeg*(LightDensity+MiddleDensity))/2;
       //back Segment
       DistanceLightMiddle = EnlightedSegBack - MiddleDepth.g;
       LightDensity = MiddleDensity * (1-DistanceLightMiddle/(DistanceBackMiddle>=0?DistanceBackMiddle:DistanceFrontMiddle));
       LightSeg = abs(DistanceLightMiddle);
       EnlightedDensity += sign(DistanceLightMiddle)*(LightSeg*(LightDensity+MiddleDensity))/2;

       sampleZ = sampleZ-abs(EnlightedDensity)*(ParticleInfluence/100);
     }
     float deltaZ = sampleZ-zEntry;
     float range_check = ((deltaZ<=0)?saturate(1+deltaZ/range):1.0);
     deltaZ = clamp(deltaZ,0,2.0*Kernel[i].z);
     occlusion+=deltaZ;
     normalization+=Kernel[i].z*2.0*range_check;
  }
  pso.Color.rgb = ((occlusion/normalization*(1+BIAS)))+(normalization<=EPSILON?1.0:0.0);
  pso.Color.a = 1.0;
  return pso;
}

technique MegaTec
{
   pass p0
   {
      VertexShader = compile vs_3_0 MegaVertexShader();
      PixelShader = compile ps_3_0 MegaPixelShader();
   }
}  �   \   ��
 S C R E E N T O B A C K B U F F E R W I T H A L P H A . F X         0 	        #include FullscreenQuadHeader.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color = tex2D(ColorTextureSampler,psin.Tex);
  return pso;
}

#include FullscreenQuadFooter.fx   @   ��
 M A K E S H A D O W M A S K . F X       0 	        #include FullscreenQuadHeader.fx
#include Shadowmapping.fx

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float3 PixelPos = tex2Dlod(VariableTexture1Sampler, float4(psin.Tex,0,0)).rgb;
  float3 PixelNormal = normalize(tex2Dlod(NormalTextureSampler, float4(psin.Tex,0,0)).rgb);
  float ShadowStrength = GetShadowStrength(PixelPos, PixelNormal, ColorTextureSampler
  #ifdef DX11
    ,ColorTexture
  #endif
  );
  pso.Color = float4(0, 0, 0, ShadowStrength);
  return pso;
}

#include FullscreenQuadFooter.fx
#  D   ��
 S H A D O W M A P Z S H A D E R . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

#block defines
#endblock

#undef LIGHTING

cbuffer local : register(b1)
{
  float4x4 World, WorldInverseTranspose;
  float3 LightPosition;
  float AlphaTestRef;

  #ifdef MORPH
    float4 Morphweights[2];
  #endif

  #block custom_parameters
  #endblock
};

cbuffer bones : register(b2)
{
  float4x3 BoneTransforms[MAX_BONES];
};

#block custom_methods
#endblock

#ifdef SKINNING
  // number of influencing bones per vertex in range [1, 4]
  #define NumBoneInfluences 4
#endif

struct VSInput
{
  #block vs_input_override
    float3 Position : POSITION0;
    #ifdef MORPH
      #if MORPH_COUNT > 0
        float3 Position_Morph_1 : POSITION1;
      #endif
      #if MORPH_COUNT > 1
        float3 Position_Morph_2 : POSITION2;
      #endif
      #if MORPH_COUNT > 2
        float3 Position_Morph_3 : POSITION3;
      #endif
      #if MORPH_COUNT > 3
        float3 Position_Morph_4 : POSITION4;
      #endif
      #if MORPH_COUNT > 4
        float3 Position_Morph_5 : POSITION5;
      #endif
      #if MORPH_COUNT > 5
        float3 Position_Morph_6 : POSITION6;
      #endif
      #if MORPH_COUNT > 6
        float3 Position_Morph_7 : POSITION7;
      #endif
      #if MORPH_COUNT > 7
        float3 Position_Morph_8 : POSITION8;
      #endif
    #endif
    #ifdef VERTEXCOLOR
      float4 Color : COLOR0;
    #endif
    #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL) || defined(FORCE_TEXCOORD_INPUT)
      float2 Tex : TEXCOORD0;
    #endif
    #if defined(LIGHTING) || defined(FORCE_NORMALMAPPING_INPUT)
      float3 Normal : NORMAL0;
      #if defined(NORMALMAPPING) || defined(FORCE_NORMALMAPPING_INPUT)
        float3 Tangent : TANGENT0;
        float3 Binormal : BINORMAL0;
      #endif
    #endif

    #if defined(SKINNING) || defined(FORCE_SKINNING_INPUT)
      float4 BoneWeights : BLENDWEIGHT0;
      float4 BoneIndices : BLENDINDICES0;
    #endif
    #ifdef SMOOTHED_NORMAL
      float3 SmoothedNormal : TEXCOORD7;
    #endif
  #endblock

  #block vs_input
  #endblock
};

struct VSOutput
{
  float4 Position : POSITION0;
  float3 WorldPosition : TEXCOORD0;
  #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL)
    float2 Tex : TEXCOORD1;
  #endif
  #ifdef SMOOTHED_NORMAL
    float3 SmoothedNormal : TEXCOORD7;
  #endif

  #block vs_output
  #endblock
};

struct PSInput
{
  float4 Position : POSITION0;
  float3 WorldPosition : TEXCOORD0;
  #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL)
    float2 Tex : TEXCOORD1;
  #endif
  #ifdef SMOOTHED_NORMAL
    float3 SmoothedNormal : TEXCOORD7;
  #endif

  #block ps_input
  #endblock
};

struct PSOutput
{
  float4 Color : COLOR0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;

  #block pre_vertexshader
  #endblock

  float4 pos = float4(vsin.Position, 1.0);
  #ifdef MORPH
    #if MORPH_COUNT > 0
      pos.xyz += vsin.Position_Morph_1 * Morphweights[0][0];
    #endif
    #if MORPH_COUNT > 1
      pos.xyz += vsin.Position_Morph_2 * Morphweights[0][1];
    #endif
    #if MORPH_COUNT > 2
      pos.xyz += vsin.Position_Morph_3 * Morphweights[0][2];
    #endif
    #if MORPH_COUNT > 3
      pos.xyz += vsin.Position_Morph_4 * Morphweights[0][3];
    #endif
    #if MORPH_COUNT > 4
      pos.xyz += vsin.Position_Morph_5 * Morphweights[1][0];
    #endif
    #if MORPH_COUNT > 5
      pos.xyz += vsin.Position_Morph_6 * Morphweights[1][1];
    #endif
    #if MORPH_COUNT > 6
      pos.xyz += vsin.Position_Morph_7 * Morphweights[1][2];
    #endif
    #if MORPH_COUNT > 7
      pos.xyz += vsin.Position_Morph_8 * Morphweights[1][3];
    #endif
  #endif

  #ifdef SKINNING
    float4x3 skinning = 0;

    [unroll]
    for (int i = 0; i < NumBoneInfluences; i++) {
      skinning += vsin.BoneWeights[i] * BoneTransforms[vsin.BoneIndices[i]];
    }

    pos.xyz = mul((float3x3)skinning, pos.xyz) + skinning._41_42_43;
  #endif

  #ifdef SMOOTHED_NORMAL
    #ifdef SKINNING
      float3 SmoothedNormal = mul((float3x3)skinning, vsin.SmoothedNormal);
    #else
      float3 SmoothedNormal = vsin.SmoothedNormal;
    #endif
    SmoothedNormal = normalize(mul((float3x3)WorldInverseTranspose, normalize(SmoothedNormal)));
  #endif

  #block vs_worldposition
  float4 Worldposition = mul(World, pos);
  #endblock

  #if defined(DIFFUSETEXTURE) || defined(NORMALMAPPING) || defined(MATERIAL)
    vsout.Tex = vsin.Tex;
  #endif

  vsout.Position = mul(Projection, mul(View, Worldposition));
  vsout.WorldPosition = Worldposition.xyz;

  #ifdef SMOOTHED_NORMAL
    vsout.SmoothedNormal = SmoothedNormal;
  #endif

  #block after_vertexshader
  #endblock

  return vsout;
}

PSOutput MegaPixelShader(PSInput psin){
  PSOutput pso;

  #if defined(ALPHATEST) && defined(DIFFUSETEXTURE)
    clip(tex2D(ColorTextureSampler, psin.Tex).a - AlphaTestRef);
  #endif

  #block shadow_clip_test
  #endblock

  float distance = dot(DirectionalLightDir, LightPosition - psin.WorldPosition);
  pso.Color = float4(0, 0, 1000.0 - distance, 0);

  return pso;
}

technique MegaTec
{
  pass p0
  {
    VertexShader=compile vs_3_0 MegaVertexShader();
    PixelShader=compile ps_3_0 MegaPixelShader();
  }
} M  X   ��
 P O S T E F F E C T D R A W D E P T H B U F F E R . F X         0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float near, far;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  float depth = (1000.0-tex2D(ColorTextureSampler,psin.Tex).r)-near;
  pso.Color.rgb = depth/(far-near);
  return pso;
}

#include FullscreenQuadFooter.fx   �  @   ��
 S H A D O W M A P P I N G . F X         0 	        
#define TRANSLUCENT

cbuffer shadow : register(b3)
{
  float4x4 ShadowView, ShadowProj;
  float3 ShadowcameraPosition;
  float Shadowbias, Slopebias, Shadowpixelwidth, ShadowStrength;
};

float2 WorldPositionToShadowtexture(float3 position)
{
    float4 pos = mul(ShadowProj, mul(ShadowView, float4(position,1)));
    return (float2(pos.x,-pos.y)/pos.w+1)/2;
}

float ComputeShadowStrength(float2 tex,	float ReferenceDepth, float Slope, sampler ShadowmasktextureSampler
#ifdef DX11
  ,Texture2D Shadowmasktexture
#endif
)
{
  #ifdef DX11
    float4 shadow_texel = Shadowmasktexture.Load(float3(tex / Shadowpixelwidth,0));
  #else
	  float4 shadow_texel = tex2Dlod(ShadowmasktextureSampler,float4(tex,0,0));
  #endif
  ReferenceDepth -= Shadowbias + Slope * Slopebias;
  float fix_shadow_depth = 1000.0 - shadow_texel.b;
  #ifdef TRANSLUCENT
    float min_translucent_shadow_depth = 1000-shadow_texel.r;
    float max_translucent_shadow_depth = shadow_texel.g;
    float translucent_shadow_part = max(0.01, max_translucent_shadow_depth - min_translucent_shadow_depth);
    float factor_in_translucent_part = saturate(translucent_shadow_part / (ReferenceDepth - min_translucent_shadow_depth));
    float translucent_shadow_factor = lerp(0, saturate(shadow_texel.a), factor_in_translucent_part);
    return 1-((1-translucent_shadow_factor) * step(ReferenceDepth, fix_shadow_depth));
  #else
    return saturate(ReferenceDepth - fix_shadow_depth);
  #endif
}

// PCF Shadow Maps, optimized with SAT and interpolation
// self mix of techniques from:
// http://http.developer.nvidia.com/GPUGems3/gpugems3_ch08.html
float GetShadowStrength(float3 fragmentposition, float3 fragmentnormal, sampler shadowmasktexturesampler
#ifdef DX11
  ,Texture2D shadowmasktexture
#endif
){
  float2 ShadowTex = WorldPositionToShadowtexture(fragmentposition);
  float SceneDepth = (dot(DirectionalLightDir, ShadowcameraPosition - fragmentposition));
  float Slope = 1-dot(DirectionalLightDir, fragmentnormal);

  // build coords for bilinear quad
  float width = 1.0/Shadowpixelwidth;
  float2 uv = trunc(ShadowTex*width)/width;
  float2 ShadowTex2 = uv + (Shadowpixelwidth/2);
  uv = (ShadowTex-uv)/Shadowpixelwidth;

  // move a half block
  float2 offset = round(uv);
  uv = uv - offset + 0.5;

  #define RANGE SHADOW_SAMPLING_RANGE
  #define MIDDLE RANGE
  #define SIZE (RANGE*2+2)
  #define HALFSIZE (SIZE/2)
  float Shadow[SIZE][SIZE];
  for(float x = 0 ; x<SIZE ; ++x){Shadow[x][0]=0;}
  for(float y = 0 ; y<SIZE ; ++y){
    float xsum = 0;
	  for(float x = 0 ; x<SIZE ; ++x){
		  float2 tex = ShadowTex2+((float2(x,y)-float2(HALFSIZE,HALFSIZE)+offset-float2(0.5,0.5))*Shadowpixelwidth);
		  xsum += ComputeShadowStrength(tex, SceneDepth, Slope, shadowmasktexturesampler
		  #ifdef DX11
			,shadowmasktexture
		  #endif
		  );
	    Shadow[x][y]=xsum+Shadow[x][max(0,y-1)];
	  }
  }
  float lt = Shadow[MIDDLE+RANGE][MIDDLE+RANGE];
  float rt = Shadow[MIDDLE+1+RANGE][MIDDLE+RANGE] - Shadow[MIDDLE-RANGE][MIDDLE+RANGE];
  float lb = Shadow[MIDDLE+RANGE][MIDDLE+1+RANGE] - Shadow[MIDDLE+RANGE][MIDDLE-RANGE];
  float rb = Shadow[MIDDLE+1+RANGE][MIDDLE+1+RANGE] - Shadow[MIDDLE+1+RANGE][MIDDLE-RANGE] - Shadow[MIDDLE-RANGE][MIDDLE+1+RANGE] + Shadow[MIDDLE-RANGE][MIDDLE-RANGE];
  float x1 = lerp(lt,rt,uv.x);
  float x2 = lerp(lb,rb,uv.x);
  float ResultingShadow = lerp(x1,x2,uv.y);
  ResultingShadow /= sqr(HALFSIZE);

  return saturate(ResultingShadow * ShadowStrength);
}

 �&  <   ��
 W A T E R S H A D E R . F X         0 	        #include Shaderglobals.fx
#include Shadertextures.fx

cbuffer local : register(b1)
{
  float4x4 World;
  float TimeTickVS;
  float SizeVS;
  float2 TextureNormalizationVS;
  float WaveHeightVS;
  float WaveTexelsize;
  float WaveTexelworldsize;

  float WaveHeight;
  float3 WaterColor;
  float3 SkyColor;
  float TimeTick;
  float Size;
  float Exposure;
  float Specularpower;
  float Specularintensity;
  float Roughness;
  float FresnelOffset;
  float2 TextureNormalization;
  float Transparency;
  #ifdef DEFERRED_SHADING
    float RefractionIndex;
    float DepthTransparencyRange;
    float RefractionSteps;
    float RefractionStepLength;
  #endif
  float4 MinMax;
  float ColorExtinctionRange;
  float CausticsRange;
  float CausticsScale;
};

struct VSInput
{
  float3 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float3 Normal : NORMAL0;
  float2 Tex : TEXCOORD0;
  float3 WorldPosition : TEXCOORD1;
};

struct PSInput
{
  float2 vPos : VPOS;
  float4 Position : POSITION0;
  float3 Normal : NORMAL0;
  float2 Tex : TEXCOORD0;
  float3 WorldPosition : TEXCOORD1;
};

float2 vPos2Coord(float2 vPos){
  return vPos / viewport_size;
}

struct PSOutput
{
  float4 Color : COLOR0;
};

#ifdef DX9
float4 lookup(float2 Tex){
  float2 dtex = (trunc(frac(Tex)/WaveTexelsize)) * WaveTexelsize;
  float4 lt = tex2Dlod(MaterialTextureSampler,float4(dtex + float2(0,0), 0, 0));
  float4 rt = tex2Dlod(MaterialTextureSampler,float4(dtex + float2(WaveTexelsize,0), 0, 0));
  float4 lb = tex2Dlod(MaterialTextureSampler,float4(dtex + float2(0,WaveTexelsize), 0, 0));
  float4 rb = tex2Dlod(MaterialTextureSampler,float4(dtex + float2(WaveTexelsize,WaveTexelsize), 0, 0));
  float2 s = (Tex - dtex) / WaveTexelsize;
  return lerp(lerp(lt, rt, s.x), lerp(lb, rb, s.x), s.y);
}
#endif

#ifdef DX11
float4 lookup(float2 Tex){
  return tex2Dlod(MaterialTextureSampler,float4(Tex, 0, 0));
}
#endif

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;

  float4 WorldPosition = mul(World, float4(vsin.Position, 1));

  vsout.Tex = vsin.Tex;
  float speed = TimeTickVS / 10.0 / 3.0 / SizeVS / max(TextureNormalizationVS.x,TextureNormalizationVS.y);
  float2 scale = 0.45 * SizeVS * TextureNormalizationVS;

  float2 Tex = ((vsout.Tex + (float2(0.4, 1.0) * speed)) * scale);

  float4 center = lookup(Tex);

  Tex = ((vsout.Tex - (float2(0.4, 1.0) * speed)) * scale);

  float4 center2 = lookup(Tex);
  WorldPosition.y += lerp(center.a, center2.a, 0.5) * WaveHeightVS - WaveHeightVS * 0.5;

  vsout.Position = mul(Projection, mul(View, WorldPosition));
  vsout.WorldPosition = WorldPosition.xyz;

  float height_norm = 1.2 / max(WaveHeightVS, 0.0001);
  vsout.Normal = normalize(lerp(center.gbr * 2 - 1, center2.gbr * 2 - 1, 0.5));
  vsout.Normal.y *= height_norm;
  vsout.Normal = normalize(vsout.Normal);
   
  return vsout;
}

float3 hdr(float3 color, float exposure){
  return 1.0 - exp(-color * exposure);
}

PSOutput MegaPixelShader(PSInput psin){
  PSOutput pso;

  float speed = TimeTick / 10 / 3 / Size / max(TextureNormalization.x,TextureNormalization.y);
  float2 scale = 0.45 * Size * TextureNormalization;

  float3 Normal = normalize(psin.Normal);
  float3 Tangent = normalize(cross(float3(1,-0.1,0), Normal));
  float3 Binormal = normalize(cross(Normal, Tangent));

  float2 Tex = (psin.Tex + (normalize(float2(1.0, 0.6)) * speed * 1.35)) * scale * 4;
  float3 normal = normalize(tex2D(ColorTextureSampler, Tex).gbr*2-1);

  Tex = (psin.Tex - (normalize(float2(1.0, 0.6)) * speed * 1.35)) * scale * 3.5;
  float3 normal2 = normalize(tex2D(ColorTextureSampler, Tex).gbr*2-1);

  normal = normalize(lerp(float3(0,1,0), normalize(normal + normal2), Roughness));

  normal = normalize(mul(float3x3(Tangent, Normal, Binormal), normal));

  float3 view = normalize(psin.WorldPosition - CameraPosition);
  float fresnel = saturate(lerp(pow(1.0 - dot(normal,-view), 5), 1, FresnelOffset));
  // other methods for fresnel term: https://habibs.wordpress.com/lake/
  float transparency = 1;

  #ifdef DEFERRED_SHADING
    float2 screen_tex;
    float3 initial_scenepos = tex2Dlod(VariableTexture1Sampler, float4(vPos2Coord(psin.vPos.xy), 0, 0)).rgb;
    float3 scenepos = initial_scenepos;
    float3 scene_color = tex2Dlod(NormalTextureSampler, float4(vPos2Coord(psin.vPos.xy), 0, 0)).rgb;
    float3 raydirection;
    float4 raypos;

    #ifdef REFRACTION
      raydirection = normalize(refract(view, normal, RefractionIndex)) * RefractionStepLength;
      raypos = float4(psin.WorldPosition+raydirection,1);
      for(float i = 0; i < RefractionSteps; ++i){
        float4 projpoint = mul(mul(Projection, View), raypos);
        screen_tex = saturate((projpoint.xy/projpoint.w)*float2(0.5,-0.5)+0.5) - float2(0,1/viewport_size.y);
        scenepos = tex2Dlod(VariableTexture1Sampler, float4(screen_tex, 0, 0)).rgb;
        if (distance(scenepos, CameraPosition) <= distance(raypos.xyz, CameraPosition)) {
          // hit the surface, refine ray cast
          raypos.xyz -= raydirection;
          raydirection *= 0.5;
        }
        raypos.xyz += raydirection;
      }
      // due precision errors take 4 times upper target screen pixel to sample always behind obstacles
      float4 projpoint = mul(mul(Projection, View), raypos);
      screen_tex = saturate(saturate((projpoint.xy/projpoint.w)*float2(0.5,-0.5)+0.5) - float2(0,4/viewport_size.y));
      scenepos = tex2Dlod(VariableTexture1Sampler, float4(screen_tex, 0, 0)).rgb;

      scene_color = tex2Dlod(NormalTextureSampler, float4(screen_tex, 0, 0)).rgb;
    #endif

    float depth = distance(psin.WorldPosition, scenepos);
    transparency = lerp(0.0, 1 - Transparency, saturate((depth-0.1) / DepthTransparencyRange));

    // color extinction
    // from http://www.gamedev.net/page/resources/_/technical/graphics-programming-and-theory/rendering-water-as-a-post-process-effect-r2642

    float3 water_color = WaterColor;
    float3 extinction = saturate(water_color);
    float3 resulting_color = lerp(scene_color, water_color, depth / ColorExtinctionRange / extinction);

    float3 reflection = reflect(view, normal);
    #ifdef REFLECTIONS
      // reflection
      raydirection = reflection * depth;
      raypos = float4(psin.WorldPosition+raydirection,1);
      float hit = 0;
      float3 current_scenepos;
      for(float j = 0; j < RefractionSteps; ++j){
        float4 projpoint = mul(mul(Projection, View), raypos);
        screen_tex = (projpoint.xy / projpoint.w) * float2(0.5, -0.5) + 0.5;
        if (any(screen_tex < 0) || any(screen_tex > 1)){
          break;
        }
        current_scenepos = tex2Dlod(VariableTexture1Sampler, float4(screen_tex,0,0)).rgb;

        #ifdef SCENE_MAY_CONTAIN_BACKBUFFER
          //float out_of_scene = tex2Dlod(VariableTexture4Sampler, float4(screen_tex,0,0)).a;
          //if (out_of_scene <= 0.5) break;
        #endif

        if (distance(current_scenepos, CameraPosition) <= distance(raypos.xyz, CameraPosition)) {
          // hit the surface, refine ray cast
          hit = 1;
          if (distance(current_scenepos,raypos.xyz)<0.1) break;
          raypos.xyz -= raydirection;
          raydirection *= 0.5;
        }
        raypos.xyz += raydirection;
      }
    #endif

    #ifdef SKY_REFLECTION
      float2 sky_tex = float2(atan2(reflection.x,reflection.z)/(2*3.141592654) + 0.5,(asin(-reflection.y)/3.141592654 + 0.5));
      float3 sky = tex2Dlod(VariableTexture2Sampler, float4(sky_tex, 0.0, 0.0));
    #else
      float3 sky = SkyColor;
    #endif

    #ifdef REFLECTIONS
      sky = lerp(sky, tex2Dlod(NormalTextureSampler, float4(screen_tex, 0, 0)).rgb, hit);
    #endif

    resulting_color = lerp(resulting_color, sky, fresnel);

    #ifdef CAUSTICS
      // caustics
      float3 scene_normal = tex2Dlod(VariableTexture4Sampler, float4(vPos2Coord(psin.vPos.xy), 0, 0)).rgb;
      float2 caustic_tex = (initial_scenepos.xz-MinMax.xy)/(MinMax.zw-MinMax.xy);
      float2 temoTex = (caustic_tex + (float2(0.4,1.0) * speed)) * scale * CausticsScale;
      float caustic1 = tex2Dlod(VariableTexture3Sampler, float4(temoTex,0,0)).a;
      temoTex = (caustic_tex + (float2(-0.4,-1.0) * speed)) * scale * CausticsScale;
      float caustic2 = tex2Dlod(VariableTexture3Sampler, float4(temoTex,0,0)).a;
      float resulting_caustic = saturate(transparency * caustic1 * caustic2 * (1-((psin.WorldPosition.y - scenepos.y)/CausticsRange)) * scene_normal.y);
      resulting_color = resulting_color + resulting_caustic;
    #endif

    // borders
    resulting_color = lerp(scene_color, resulting_color, transparency);

    pso.Color = float4(resulting_color, 1.0);
  #else
    #ifdef SKY_REFLECTION
      float3 reflection = reflect(view, normal);
      float2 sky_tex = float2(atan2(reflection.x,reflection.z)/(2*3.141592654) + 0.5,(asin(-reflection.y)/3.141592654 + 0.5));
      float3 sky = tex2Dlod(VariableTexture2Sampler, float4(sky_tex, 0.0, 0.0));
    #else
      float3 sky = SkyColor;
    #endif
    float3 scolor = sky;
    float3 wcolor = saturate(WaterColor);

    float3 resulting_color = lerp(wcolor, scolor, fresnel);

    pso.Color = float4(resulting_color, Transparency);
  #endif

  // specular
  float3 halfway = normalize(-view+DirectionalLightDir);
  float3 Specular =  saturate(pow(saturate(dot(normal,halfway)),Specularpower)-0.8)/0.2;

  pso.Color.rgb = lerp(pso.Color.rgb, DirectionalLightColor.rgb, Specular * Specularintensity * transparency);

  return pso;
}

technique MegaTec
{
  pass p0
  {
    VertexShader = compile vs_3_0 MegaVertexShader();
    PixelShader = compile ps_3_0 MegaPixelShader();
  }
}
  p  <   ��
 M E T A L S H A D E R . F X         0 	        #block defines
  #inherited
  #define NEEDWORLD
#endblock

#block color_adjustment
  #ifdef LIGHTING
    #ifdef MATERIAL
      #ifdef GBUFFER
        #ifdef DRAW_MATERIAL
          float metal = pso.MaterialBuffer.r;
          float tinting = pso.MaterialBuffer.b;
          pso.MaterialBuffer.rgb = 0;
        #else
          float metal = 1;
          float tinting = 0;
        #endif
      #else
        float metal = Specularintensity;
        float tinting = Speculartint;
        #ifdef MATERIALTEXTURE
          metal *= Material.r;
          tinting *= Material.b;
        #endif
      #endif

    #else
      float metal = 0;
      float tinting = 0;
    #endif

    float3 look_dir = normalize(psin.WorldPosition - CameraPosition);
    #ifdef GBUFFER
      float3 reflection_vector = normalize(reflect(look_dir, normalize(pso.NormalBuffer.xyz)));
    #else
      float3 reflection_vector = normalize(reflect(look_dir, normalize(psin.Normal)));
    #endif
    float3 reflected_color = tex2Dlod(VariableTexture2Sampler, float4(SphereMap(reflection_vector), 0, 0)).rgb;

    pso.Color.rgb = lerp(pso.Color.rgb, lerp(reflected_color, pso.Color.rgb * (reflected_color * 1.5 + 0.25), tinting), metal);
  #endif

  #inherited
#endblock

#block shader_version
  #define ps_shader_version ps_3_0
  #define vs_shader_version vs_3_0
#endblock
�  <   ��
 M A T C A P S H A D E R . F X       0 	        #block defines
  #inherited
  #define NEEDWORLD
#endblock

#block custom_methods
   #inherited
  /*
    Converts a Normal to a texturecoordinate for a screen aligned half sphere with only a normal 2D-Texture.
  */
  float2 MatcapMap(float3 Normal)
  {
     float x = dot(CameraLeft, Normal);
     float y = dot(CameraUp, Normal);
     return float2(x, y) * -0.5 + 0.5;
  }
#endblock

#block color_adjustment
  #ifdef LIGHTING
    #ifdef MATERIAL
      #ifdef GBUFFER
        #ifdef DRAW_MATERIAL
          float metal = pso.MaterialBuffer.r;
          float tinting = pso.MaterialBuffer.b;
          pso.MaterialBuffer.rgb = 0;
        #else
          float metal = 1;
          float tinting = 0;
        #endif
      #else
        float metal = Specularintensity;
        float tinting = Speculartint;
        #ifdef MATERIALTEXTURE
          metal *= Material.r;
          tinting *= Material.b;
        #endif
      #endif
    #else
      float metal = 0;
      float tinting = 0;
    #endif

    float3 look_dir = normalize(psin.WorldPosition - CameraPosition);
    #ifdef GBUFFER
      float3 reflection_vector = normalize(pso.NormalBuffer.xyz);
    #else
      float3 reflection_vector = normalize(psin.Normal);
    #endif
    float4 reflected_color = tex2Dlod(VariableTexture2Sampler, float4(MatcapMap(reflection_vector), 0, 0)).rgba;

    pso.Color.rgb = lerp(pso.Color.rgb, lerp(reflected_color.rgb, pso.Color.rgb * reflected_color.rgb, tinting), metal);
    pso.Color.a *= reflected_color.a;
  #endif

  #inherited
#endblock

#block shader_version
  #define ps_shader_version ps_3_0
  #define vs_shader_version vs_3_0
#endblock
   �  D   ��
 V E G E T A T I O N S H A D E R . F X       0 	        #block custom_parameters
  float time;
  float3 WindDirection;
#endblock

#block vs_input
  float4 Wind : TEXCOORD1;
#endblock

#block pre_vertexshader
  float x = time / 15 + vsin.Wind.y + dot(WindDirection, vsin.Position.xyz) / 10 * vsin.Wind.x;
  float supersin = cos(x * PI) * cos(x * 3 * PI) * cos(x * 5 * PI) * cos(x * 7 * PI) + sin(x * 25 * PI) * 0.1;
  vsin.Position.xyz += supersin * vsin.Wind.z * WindDirection;
#endblock
    P   ��
 F O R W A R D P A R T I C L E S H A D E R . F X         0 	        #block vs_input_override
  float3 Position : POSITION0;
  float3 Normal : NORMAL0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float3 Size : TEXCOORD1;
#endblock

#block pixelshader_diffuse
  #inherited
  clip(pso.Color.a-0.001);
#endblock
   �  X   ��
 F O R W A R D S O F T P A R T I C L E S H A D E R . F X         0 	        #block custom_parameters
  float Softparticlerange;
#endblock

#block vs_output
  float3 Worldposition : TEXCOORD5;
#endblock

#block after_vertexshader
  vsout.Worldposition = Worldposition.xyz;
#endblock

#block ps_input
  float3 Worldposition : TEXCOORD5;
  float2 vPos : VPOS;
#endblock

#block after_pixelshader
  float2 pixel_tex = (psin.vPos.xy + float2(0.5, 0.5)) / viewport_size;
  float particle_depth = distance(psin.Worldposition, CameraPosition);
  float Depth = tex2Dlod(VariableTexture1Sampler, float4(pixel_tex, 0, 0)).a;
  pso.Color.a = pso.Color.a * saturate((Depth - particle_depth) / Softparticlerange);
#endblock

#block shader_version
  #define ps_shader_version ps_3_0
  #define vs_shader_version vs_3_0
#endblock
     L   ��
 P A R T I C L E S H A D O W S H A D E R . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

struct VSInput
{
  float3 Position : POSITION0;
  float3 Normal : NORMAL0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float3 Size : TEXCOORD1;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float2 DepthSize : TEXCOORD1;
};

struct PSInput
{
  float4 Position : POSITION0;
  float4 Color : COLOR0;
  float2 Tex : TEXCOORD0;
  float2 DepthSize : TEXCOORD1;
};

struct PSOutput
{
  float4 Color : COLOR0;
};

VSOutput MegaVertexShader(VSInput vsin) {
  VSOutput vsout;

  float4 Worldposition = float4(vsin.Position, 1);
  float distance = abs(dot(normalize(CameraDirection), Worldposition.xyz - CameraPosition));
  vsout.DepthSize = float2(distance, min(vsin.Size.x, vsin.Size.y));
  float4 ViewPos = mul(View, Worldposition);
  vsout.Position = mul(Projection, ViewPos);
  vsout.Tex = vsin.Tex;
  vsout.Color = vsin.Color;

  return vsout;
}

PSOutput MegaPixelShader(PSInput psin) {
  PSOutput pso;

  float4 Color = tex2D(ColorTextureSampler, psin.Tex) * psin.Color;

  float4 NormalDepth = tex2D(NormalTextureSampler, psin.Tex);
  float3 Normal = normalize(NormalDepth.rgb * 2 - 1);

  // apply depthadjustment
  float DepthOffset = NormalDepth.a * psin.DepthSize.y / 2;

  psin.DepthSize.x -= DepthOffset;

  // minimal particledepth
  pso.Color.r = 1000 - psin.DepthSize.x;
  // maxmimal particledepth
  pso.Color.g = psin.DepthSize.x + 2 * DepthOffset;

  pso.Color.a = Color.a * 0.4;
  // no fix shadow wall
  pso.Color.b = 0;

  return pso;
}

technique MegaTec {
  pass p0 {
    VertexShader = compile vs_3_0 MegaVertexShader();
    PixelShader = compile ps_3_0 MegaPixelShader();
  }
}
�  4   ��
 G U I B L U R . F X         0 	        #block pixelshader_diffuse
  #if defined(VERTEXCOLOR) && defined(DIFFUSETEXTURE)
    pso.Color = tex2D(ColorTextureSampler, psin.Tex);
  #else
    #inherited
  #endif
#endblock

#block color_adjustment
  #if defined(VERTEXCOLOR) && defined(DIFFUSETEXTURE)
    float3 origColor = RGBToHSV(pso.Color.rgb);
    float3 targetColor = RGBToHSV(psin.Color.rgb);
    pso.Color.rgb = HSVToRGB(float3(targetColor.xy, (0.5*origColor.z+0.2) * targetColor.z));
  #endif
#endblock


  1�  ,   ��
 F X A A . F X       0 	        #include Shaderglobals.fx
#include Shadertextures.fx

#define FXAA_PC 1
#define FXAA_HLSL_4 1
#define FXAA_GREEN_AS_LUMA 1
#define FXAA_DISCARD 1

/*============================================================================

                             INTEGRATION KNOBS

============================================================================*/
#ifndef FXAA_PC
    //
    // FXAA Quality
    // The high quality PC algorithm.
    //
    #define FXAA_PC 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_GLSL_120
    #define FXAA_GLSL_120 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_GLSL_130
    #define FXAA_GLSL_130 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_HLSL_3
    #define FXAA_HLSL_3 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_HLSL_4
    #define FXAA_HLSL_4 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_HLSL_5
    #define FXAA_HLSL_5 0
#endif
/*==========================================================================*/
#ifndef FXAA_GREEN_AS_LUMA
    //
    // For those using non-linear color,
    // and either not able to get luma in alpha, or not wanting to,
    // this enables FXAA to run using green as a proxy for luma.
    // So with this enabled, no need to pack luma in alpha.
    //
    // This will turn off AA on anything which lacks some amount of green.
    // Pure red and blue or combination of only R and B, will get no AA.
    //
    // Might want to lower the settings for both,
    //    fxaaConsoleEdgeThresholdMin
    //    fxaaQualityEdgeThresholdMin
    // In order to insure AA does not get turned off on colors 
    // which contain a minor amount of green.
    //
    // 1 = On.
    // 0 = Off.
    //
    #define FXAA_GREEN_AS_LUMA 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_EARLY_EXIT
    //
    // Controls algorithm's early exit path.
    // On PS3 turning this ON adds 2 cycles to the shader.
    // On 360 turning this OFF adds 10ths of a millisecond to the shader.
    // Turning this off on console will result in a more blurry image.
    // So this defaults to on.
    //
    // 1 = On.
    // 0 = Off.
    //
    #define FXAA_EARLY_EXIT 1
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_DISCARD
    //
    // Only valid for PC OpenGL currently.
    // Probably will not work when FXAA_GREEN_AS_LUMA = 1.
    //
    // 1 = Use discard on pixels which don't need AA.
    //     For APIs which enable concurrent TEX+ROP from same surface.
    // 0 = Return unchanged color on pixels which don't need AA.
    //
    #define FXAA_DISCARD 0
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_FAST_PIXEL_OFFSET
    //
    // Used for GLSL 120 only.
    //
    // 1 = GL API supports fast pixel offsets
    // 0 = do not use fast pixel offsets
    //
    #ifdef GL_EXT_gpu_shader4
        #define FXAA_FAST_PIXEL_OFFSET 1
    #endif
    #ifdef GL_NV_gpu_shader5
        #define FXAA_FAST_PIXEL_OFFSET 1
    #endif
    #ifdef GL_ARB_gpu_shader5
        #define FXAA_FAST_PIXEL_OFFSET 1
    #endif
    #ifndef FXAA_FAST_PIXEL_OFFSET
        #define FXAA_FAST_PIXEL_OFFSET 0
    #endif
#endif
/*--------------------------------------------------------------------------*/
#ifndef FXAA_GATHER4_ALPHA
    //
    // 1 = API supports gather4 on alpha channel.
    // 0 = API does not support gather4 on alpha channel.
    //
    #if (FXAA_HLSL_5 == 1)
        #define FXAA_GATHER4_ALPHA 1
    #endif
    #ifdef GL_ARB_gpu_shader5
        #define FXAA_GATHER4_ALPHA 1
    #endif
    #ifdef GL_NV_gpu_shader5
        #define FXAA_GATHER4_ALPHA 1
    #endif
    #ifndef FXAA_GATHER4_ALPHA
        #define FXAA_GATHER4_ALPHA 0
    #endif
#endif

/*============================================================================
                        FXAA QUALITY - TUNING KNOBS
------------------------------------------------------------------------------
NOTE the other tuning knobs are now in the shader function inputs!
============================================================================*/
#ifndef FXAA_QUALITY__PRESET
    //
    // Choose the quality preset.
    // This needs to be compiled into the shader as it effects code.
    // Best option to include multiple presets is to 
    // in each shader define the preset, then include this file.
    // 
    // OPTIONS
    // -----------------------------------------------------------------------
    // 10 to 15 - default medium dither (10=fastest, 15=highest quality)
    // 20 to 29 - less dither, more expensive (20=fastest, 29=highest quality)
    // 39       - no dither, very expensive 
    //
    // NOTES
    // -----------------------------------------------------------------------
    // 12 = slightly faster then FXAA 3.9 and higher edge quality (default)
    // 13 = about same speed as FXAA 3.9 and better than 12
    // 23 = closest to FXAA 3.9 visually and performance wise
    //  _ = the lowest digit is directly related to performance
    // _  = the highest digit is directly related to style
    // 
    #define FXAA_QUALITY__PRESET 12
#endif


/*============================================================================

                           FXAA QUALITY - PRESETS

============================================================================*/

/*============================================================================
                     FXAA QUALITY - MEDIUM DITHER PRESETS
============================================================================*/
#if (FXAA_QUALITY__PRESET == 10)
    #define FXAA_QUALITY__PS 3
    #define FXAA_QUALITY__P0 1.5
    #define FXAA_QUALITY__P1 3.0
    #define FXAA_QUALITY__P2 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 11)
    #define FXAA_QUALITY__PS 4
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 3.0
    #define FXAA_QUALITY__P3 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 12)
    #define FXAA_QUALITY__PS 5
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 4.0
    #define FXAA_QUALITY__P4 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 13)
    #define FXAA_QUALITY__PS 6
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 4.0
    #define FXAA_QUALITY__P5 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 14)
    #define FXAA_QUALITY__PS 7
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 4.0
    #define FXAA_QUALITY__P6 12.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 15)
    #define FXAA_QUALITY__PS 8
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 4.0
    #define FXAA_QUALITY__P7 12.0
#endif

/*============================================================================
                     FXAA QUALITY - LOW DITHER PRESETS
============================================================================*/
#if (FXAA_QUALITY__PRESET == 20)
    #define FXAA_QUALITY__PS 3
    #define FXAA_QUALITY__P0 1.5
    #define FXAA_QUALITY__P1 2.0
    #define FXAA_QUALITY__P2 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 21)
    #define FXAA_QUALITY__PS 4
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 22)
    #define FXAA_QUALITY__PS 5
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 23)
    #define FXAA_QUALITY__PS 6
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 24)
    #define FXAA_QUALITY__PS 7
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 3.0
    #define FXAA_QUALITY__P6 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 25)
    #define FXAA_QUALITY__PS 8
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 4.0
    #define FXAA_QUALITY__P7 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 26)
    #define FXAA_QUALITY__PS 9
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 4.0
    #define FXAA_QUALITY__P8 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 27)
    #define FXAA_QUALITY__PS 10
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 4.0
    #define FXAA_QUALITY__P9 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 28)
    #define FXAA_QUALITY__PS 11
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 4.0
    #define FXAA_QUALITY__P10 8.0
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_QUALITY__PRESET == 29)
    #define FXAA_QUALITY__PS 12
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.5
    #define FXAA_QUALITY__P2 2.0
    #define FXAA_QUALITY__P3 2.0
    #define FXAA_QUALITY__P4 2.0
    #define FXAA_QUALITY__P5 2.0
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 2.0
    #define FXAA_QUALITY__P10 4.0
    #define FXAA_QUALITY__P11 8.0
#endif

/*============================================================================
                     FXAA QUALITY - EXTREME QUALITY
============================================================================*/
#if (FXAA_QUALITY__PRESET == 39)
    #define FXAA_QUALITY__PS 12
    #define FXAA_QUALITY__P0 1.0
    #define FXAA_QUALITY__P1 1.0
    #define FXAA_QUALITY__P2 1.0
    #define FXAA_QUALITY__P3 1.0
    #define FXAA_QUALITY__P4 1.0
    #define FXAA_QUALITY__P5 1.5
    #define FXAA_QUALITY__P6 2.0
    #define FXAA_QUALITY__P7 2.0
    #define FXAA_QUALITY__P8 2.0
    #define FXAA_QUALITY__P9 2.0
    #define FXAA_QUALITY__P10 4.0
    #define FXAA_QUALITY__P11 8.0
#endif

/*============================================================================

                                API PORTING

============================================================================*/
#if (FXAA_GLSL_120 == 1) || (FXAA_GLSL_130 == 1)
    #define FxaaBool bool
    #define FxaaDiscard discard
    #define FxaaFloat float
    #define FxaaFloat2 vec2
    #define FxaaFloat3 vec3
    #define FxaaFloat4 vec4
    #define FxaaHalf float
    #define FxaaHalf2 vec2
    #define FxaaHalf3 vec3
    #define FxaaHalf4 vec4
    #define FxaaInt2 ivec2
    #define FxaaSat(x) clamp(x, 0.0, 1.0)
    #define FxaaTex sampler2D
#else
    #define FxaaBool bool
    #define FxaaDiscard clip(-1)
    #define FxaaFloat float
    #define FxaaFloat2 float2
    #define FxaaFloat3 float3
    #define FxaaFloat4 float4
    #define FxaaHalf half
    #define FxaaHalf2 half2
    #define FxaaHalf3 half3
    #define FxaaHalf4 half4
    #define FxaaSat(x) saturate(x)
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_GLSL_120 == 1)
    // Requires,
    //  #version 120
    // And at least,
    //  #extension GL_EXT_gpu_shader4 : enable
    //  (or set FXAA_FAST_PIXEL_OFFSET 1 to work like DX9)
    #define FxaaTexTop(t, p) texture2DLod(t, p, 0.0)
    #if (FXAA_FAST_PIXEL_OFFSET == 1)
        #define FxaaTexOff(t, p, o, r) texture2DLodOffset(t, p, 0.0, o)
    #else
        #define FxaaTexOff(t, p, o, r) texture2DLod(t, p + (o * r), 0.0)
    #endif
    #if (FXAA_GATHER4_ALPHA == 1)
        // use #extension GL_ARB_gpu_shader5 : enable
        #define FxaaTexAlpha4(t, p) textureGather(t, p, 3)
        #define FxaaTexOffAlpha4(t, p, o) textureGatherOffset(t, p, o, 3)
        #define FxaaTexGreen4(t, p) textureGather(t, p, 1)
        #define FxaaTexOffGreen4(t, p, o) textureGatherOffset(t, p, o, 1)
    #endif
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_GLSL_130 == 1)
    // Requires "#version 130" or better
    #define FxaaTexTop(t, p) textureLod(t, p, 0.0)
    #define FxaaTexOff(t, p, o, r) textureLodOffset(t, p, 0.0, o)
    #if (FXAA_GATHER4_ALPHA == 1)
        // use #extension GL_ARB_gpu_shader5 : enable
        #define FxaaTexAlpha4(t, p) textureGather(t, p, 3)
        #define FxaaTexOffAlpha4(t, p, o) textureGatherOffset(t, p, o, 3)
        #define FxaaTexGreen4(t, p) textureGather(t, p, 1)
        #define FxaaTexOffGreen4(t, p, o) textureGatherOffset(t, p, o, 1)
    #endif
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_HLSL_3 == 1) || (FXAA_360 == 1) || (FXAA_PS3 == 1)
    #define FxaaInt2 float2
    #define FxaaTex SamplerState
    #define FxaaTexTop(t, p) tex2Dlod(t, float4(p, 0.0, 0.0))
    #define FxaaTexOff(t, p, o, r) tex2Dlod(t, float4(p + (o * r), 0, 0))
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_HLSL_4 == 1)
    #define FxaaInt2 int2
    struct FxaaTex { SamplerState smpl; Texture2D tex; };
    #define FxaaTexTop(t, p) t.tex.SampleLevel(t.smpl, p, 0.0)
    #define FxaaTexOff(t, p, o, r) t.tex.SampleLevel(t.smpl, p, 0.0, o)
#endif
/*--------------------------------------------------------------------------*/
#if (FXAA_HLSL_5 == 1)
    #define FxaaInt2 int2
    struct FxaaTex { SamplerState smpl; Texture2D tex; };
    #define FxaaTexTop(t, p) t.tex.SampleLevel(t.smpl, p, 0.0)
    #define FxaaTexOff(t, p, o, r) t.tex.SampleLevel(t.smpl, p, 0.0, o)
    #define FxaaTexAlpha4(t, p) t.tex.GatherAlpha(t.smpl, p)
    #define FxaaTexOffAlpha4(t, p, o) t.tex.GatherAlpha(t.smpl, p, o)
    #define FxaaTexGreen4(t, p) t.tex.GatherGreen(t.smpl, p)
    #define FxaaTexOffGreen4(t, p, o) t.tex.GatherGreen(t.smpl, p, o)
#endif


/*============================================================================
                   GREEN AS LUMA OPTION SUPPORT FUNCTION
============================================================================*/
#if (FXAA_GREEN_AS_LUMA == 0)
    FxaaFloat FxaaLuma(FxaaFloat4 rgba) { return rgba.w; }
#else
    FxaaFloat FxaaLuma(FxaaFloat4 rgba) { return rgba.y; }
#endif    




/*============================================================================

                             FXAA3 QUALITY - PC

============================================================================*/
#if (FXAA_PC == 1)
/*--------------------------------------------------------------------------*/
FxaaFloat4 FxaaPixelShader(
    //
    // Use noperspective interpolation here (turn off perspective interpolation).
    // {xy} = center of pixel
    FxaaFloat2 pos,
    //
    // Used only for FXAA Console, and not used on the 360 version.
    // Use noperspective interpolation here (turn off perspective interpolation).
    // {xy__} = upper left of pixel
    // {__zw} = lower right of pixel
    FxaaFloat4 fxaaConsolePosPos,
    //
    // Input color texture.
    // {rgb_} = color in linear or perceptual color space
    // if (FXAA_GREEN_AS_LUMA == 0)
    //     {___a} = luma in perceptual color space (not linear)
    FxaaTex tex,
    //
    // Only used on FXAA Quality.
    // This must be from a constant/uniform.
    // {x_} = 1.0/screenWidthInPixels
    // {_y} = 1.0/screenHeightInPixels
    FxaaFloat2 fxaaQualityRcpFrame,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__SUBPIX define.
    // It is here now to allow easier tuning.
    // Choose the amount of sub-pixel aliasing removal.
    // This can effect sharpness.
    //   1.00 - upper limit (softer)
    //   0.75 - default amount of filtering
    //   0.50 - lower limit (sharper, less sub-pixel aliasing removal)
    //   0.25 - almost off
    //   0.00 - completely off
    FxaaFloat fxaaQualitySubpix,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__EDGE_THRESHOLD define.
    // It is here now to allow easier tuning.
    // The minimum amount of local contrast required to apply algorithm.
    //   0.333 - too little (faster)
    //   0.250 - low quality
    //   0.166 - default
    //   0.125 - high quality 
    //   0.063 - overkill (slower)
    FxaaFloat fxaaQualityEdgeThreshold,
    //
    // Only used on FXAA Quality.
    // This used to be the FXAA_QUALITY__EDGE_THRESHOLD_MIN define.
    // It is here now to allow easier tuning.
    // Trims the algorithm from processing darks.
    //   0.0833 - upper limit (default, the start of visible unfiltered edges)
    //   0.0625 - high quality (faster)
    //   0.0312 - visible limit (slower)
    // Special notes when using FXAA_GREEN_AS_LUMA,
    //   Likely want to set this to zero.
    //   As colors that are mostly not-green
    //   will appear very dark in the green channel!
    //   Tune by looking at mostly non-green content,
    //   then start at zero and increase until aliasing is a problem.
    FxaaFloat fxaaQualityEdgeThresholdMin
) {
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posM;
    posM.x = pos.x;
    posM.y = pos.y;
    #if (FXAA_GATHER4_ALPHA == 1)
        #if (FXAA_DISCARD == 0)
            FxaaFloat4 rgbyM = FxaaTexTop(tex, posM);
            #if (FXAA_GREEN_AS_LUMA == 0)
                #define lumaM rgbyM.w
            #else
                #define lumaM rgbyM.y
            #endif
        #endif
        #if (FXAA_GREEN_AS_LUMA == 0)
            FxaaFloat4 luma4A = FxaaTexAlpha4(tex, posM);
            FxaaFloat4 luma4B = FxaaTexOffAlpha4(tex, posM, FxaaInt2(-1, -1));
        #else
            FxaaFloat4 luma4A = FxaaTexGreen4(tex, posM);
            FxaaFloat4 luma4B = FxaaTexOffGreen4(tex, posM, FxaaInt2(-1, -1));
        #endif
        #if (FXAA_DISCARD == 1)
            #define lumaM luma4A.w
        #endif
        #define lumaE luma4A.z
        #define lumaS luma4A.x
        #define lumaSE luma4A.y
        #define lumaNW luma4B.w
        #define lumaN luma4B.z
        #define lumaW luma4B.x
    #else
        FxaaFloat4 rgbyM = FxaaTexTop(tex, posM);
        #if (FXAA_GREEN_AS_LUMA == 0)
            #define lumaM rgbyM.w
        #else
            #define lumaM rgbyM.y
        #endif
        FxaaFloat lumaS = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 0, 1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 1, 0), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaN = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 0,-1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 0), fxaaQualityRcpFrame.xy));
    #endif
/*--------------------------------------------------------------------------*/
    FxaaFloat maxSM = max(lumaS, lumaM);
    FxaaFloat minSM = min(lumaS, lumaM);
    FxaaFloat maxESM = max(lumaE, maxSM);
    FxaaFloat minESM = min(lumaE, minSM);
    FxaaFloat maxWN = max(lumaN, lumaW);
    FxaaFloat minWN = min(lumaN, lumaW);
    FxaaFloat rangeMax = max(maxWN, maxESM);
    FxaaFloat rangeMin = min(minWN, minESM);
    FxaaFloat rangeMaxScaled = rangeMax * fxaaQualityEdgeThreshold;
    FxaaFloat range = rangeMax - rangeMin;
    FxaaFloat rangeMaxClamped = max(fxaaQualityEdgeThresholdMin, rangeMaxScaled);
    FxaaBool earlyExit = range < rangeMaxClamped;
/*--------------------------------------------------------------------------*/
    if(earlyExit)
        #if (FXAA_DISCARD == 1)
            FxaaDiscard;
        #else
            return rgbyM;
        #endif
/*--------------------------------------------------------------------------*/
    #if (FXAA_GATHER4_ALPHA == 0)
        FxaaFloat lumaNW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1,-1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaSE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 1, 1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaNE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2( 1,-1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaSW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 1), fxaaQualityRcpFrame.xy));
    #else
        FxaaFloat lumaNE = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(1, -1), fxaaQualityRcpFrame.xy));
        FxaaFloat lumaSW = FxaaLuma(FxaaTexOff(tex, posM, FxaaInt2(-1, 1), fxaaQualityRcpFrame.xy));
    #endif
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNS = lumaN + lumaS;
    FxaaFloat lumaWE = lumaW + lumaE;
    FxaaFloat subpixRcpRange = 1.0/range;
    FxaaFloat subpixNSWE = lumaNS + lumaWE;
    FxaaFloat edgeHorz1 = (-2.0 * lumaM) + lumaNS;
    FxaaFloat edgeVert1 = (-2.0 * lumaM) + lumaWE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNESE = lumaNE + lumaSE;
    FxaaFloat lumaNWNE = lumaNW + lumaNE;
    FxaaFloat edgeHorz2 = (-2.0 * lumaE) + lumaNESE;
    FxaaFloat edgeVert2 = (-2.0 * lumaN) + lumaNWNE;
/*--------------------------------------------------------------------------*/
    FxaaFloat lumaNWSW = lumaNW + lumaSW;
    FxaaFloat lumaSWSE = lumaSW + lumaSE;
    FxaaFloat edgeHorz4 = (abs(edgeHorz1) * 2.0) + abs(edgeHorz2);
    FxaaFloat edgeVert4 = (abs(edgeVert1) * 2.0) + abs(edgeVert2);
    FxaaFloat edgeHorz3 = (-2.0 * lumaW) + lumaNWSW;
    FxaaFloat edgeVert3 = (-2.0 * lumaS) + lumaSWSE;
    FxaaFloat edgeHorz = abs(edgeHorz3) + edgeHorz4;
    FxaaFloat edgeVert = abs(edgeVert3) + edgeVert4;
/*--------------------------------------------------------------------------*/
    FxaaFloat subpixNWSWNESE = lumaNWSW + lumaNESE;
    FxaaFloat lengthSign = fxaaQualityRcpFrame.x;
    FxaaBool horzSpan = edgeHorz >= edgeVert;
    FxaaFloat subpixA = subpixNSWE * 2.0 + subpixNWSWNESE;
/*--------------------------------------------------------------------------*/
    if(!horzSpan) lumaN = lumaW;
    if(!horzSpan) lumaS = lumaE;
    if(horzSpan) lengthSign = fxaaQualityRcpFrame.y;
    FxaaFloat subpixB = (subpixA * (1.0/12.0)) - lumaM;
/*--------------------------------------------------------------------------*/
    FxaaFloat gradientN = lumaN - lumaM;
    FxaaFloat gradientS = lumaS - lumaM;
    FxaaFloat lumaNN = lumaN + lumaM;
    FxaaFloat lumaSS = lumaS + lumaM;
    FxaaBool pairN = abs(gradientN) >= abs(gradientS);
    FxaaFloat gradient = max(abs(gradientN), abs(gradientS));
    if(pairN) lengthSign = -lengthSign;
    FxaaFloat subpixC = FxaaSat(abs(subpixB) * subpixRcpRange);
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posB;
    posB.x = posM.x;
    posB.y = posM.y;
    FxaaFloat2 offNP;
    offNP.x = (!horzSpan) ? 0.0 : fxaaQualityRcpFrame.x;
    offNP.y = ( horzSpan) ? 0.0 : fxaaQualityRcpFrame.y;
    if(!horzSpan) posB.x += lengthSign * 0.5;
    if( horzSpan) posB.y += lengthSign * 0.5;
/*--------------------------------------------------------------------------*/
    FxaaFloat2 posN;
    posN.x = posB.x - offNP.x * FXAA_QUALITY__P0;
    posN.y = posB.y - offNP.y * FXAA_QUALITY__P0;
    FxaaFloat2 posP;
    posP.x = posB.x + offNP.x * FXAA_QUALITY__P0;
    posP.y = posB.y + offNP.y * FXAA_QUALITY__P0;
    FxaaFloat subpixD = ((-2.0)*subpixC) + 3.0;
    FxaaFloat lumaEndN = FxaaLuma(FxaaTexTop(tex, posN));
    FxaaFloat subpixE = subpixC * subpixC;
    FxaaFloat lumaEndP = FxaaLuma(FxaaTexTop(tex, posP));
/*--------------------------------------------------------------------------*/
    if(!pairN) lumaNN = lumaSS;
    FxaaFloat gradientScaled = gradient * 1.0/4.0;
    FxaaFloat lumaMM = lumaM - lumaNN * 0.5;
    FxaaFloat subpixF = subpixD * subpixE;
    FxaaBool lumaMLTZero = lumaMM < 0.0;
/*--------------------------------------------------------------------------*/
    lumaEndN -= lumaNN * 0.5;
    lumaEndP -= lumaNN * 0.5;
    FxaaBool doneN = abs(lumaEndN) >= gradientScaled;
    FxaaBool doneP = abs(lumaEndP) >= gradientScaled;
    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P1;
    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P1;
    FxaaBool doneNP = (!doneN) || (!doneP);
    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P1;
    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P1;
/*--------------------------------------------------------------------------*/
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P2;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P2;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P2;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P2;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 3)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P3;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P3;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P3;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P3;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 4)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P4;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P4;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P4;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P4;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 5)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P5;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P5;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P5;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P5;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 6)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P6;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P6;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P6;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P6;
/*--------------------------------------------------------------------------*/
                        #if (FXAA_QUALITY__PS > 7)
                        if(doneNP) {
                            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                            doneN = abs(lumaEndN) >= gradientScaled;
                            doneP = abs(lumaEndP) >= gradientScaled;
                            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P7;
                            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P7;
                            doneNP = (!doneN) || (!doneP);
                            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P7;
                            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P7;
/*--------------------------------------------------------------------------*/
    #if (FXAA_QUALITY__PS > 8)
    if(doneNP) {
        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
        doneN = abs(lumaEndN) >= gradientScaled;
        doneP = abs(lumaEndP) >= gradientScaled;
        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P8;
        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P8;
        doneNP = (!doneN) || (!doneP);
        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P8;
        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P8;
/*--------------------------------------------------------------------------*/
        #if (FXAA_QUALITY__PS > 9)
        if(doneNP) {
            if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
            if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
            if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
            if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
            doneN = abs(lumaEndN) >= gradientScaled;
            doneP = abs(lumaEndP) >= gradientScaled;
            if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P9;
            if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P9;
            doneNP = (!doneN) || (!doneP);
            if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P9;
            if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P9;
/*--------------------------------------------------------------------------*/
            #if (FXAA_QUALITY__PS > 10)
            if(doneNP) {
                if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                doneN = abs(lumaEndN) >= gradientScaled;
                doneP = abs(lumaEndP) >= gradientScaled;
                if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P10;
                if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P10;
                doneNP = (!doneN) || (!doneP);
                if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P10;
                if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P10;
/*--------------------------------------------------------------------------*/
                #if (FXAA_QUALITY__PS > 11)
                if(doneNP) {
                    if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                    if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                    if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                    if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                    doneN = abs(lumaEndN) >= gradientScaled;
                    doneP = abs(lumaEndP) >= gradientScaled;
                    if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P11;
                    if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P11;
                    doneNP = (!doneN) || (!doneP);
                    if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P11;
                    if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P11;
/*--------------------------------------------------------------------------*/
                    #if (FXAA_QUALITY__PS > 12)
                    if(doneNP) {
                        if(!doneN) lumaEndN = FxaaLuma(FxaaTexTop(tex, posN.xy));
                        if(!doneP) lumaEndP = FxaaLuma(FxaaTexTop(tex, posP.xy));
                        if(!doneN) lumaEndN = lumaEndN - lumaNN * 0.5;
                        if(!doneP) lumaEndP = lumaEndP - lumaNN * 0.5;
                        doneN = abs(lumaEndN) >= gradientScaled;
                        doneP = abs(lumaEndP) >= gradientScaled;
                        if(!doneN) posN.x -= offNP.x * FXAA_QUALITY__P12;
                        if(!doneN) posN.y -= offNP.y * FXAA_QUALITY__P12;
                        doneNP = (!doneN) || (!doneP);
                        if(!doneP) posP.x += offNP.x * FXAA_QUALITY__P12;
                        if(!doneP) posP.y += offNP.y * FXAA_QUALITY__P12;
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
    #endif
/*--------------------------------------------------------------------------*/
                        }
                        #endif
/*--------------------------------------------------------------------------*/
                    }
                    #endif
/*--------------------------------------------------------------------------*/
                }
                #endif
/*--------------------------------------------------------------------------*/
            }
            #endif
/*--------------------------------------------------------------------------*/
        }
        #endif
/*--------------------------------------------------------------------------*/
    }
/*--------------------------------------------------------------------------*/
    FxaaFloat dstN = posM.x - posN.x;
    FxaaFloat dstP = posP.x - posM.x;
    if(!horzSpan) dstN = posM.y - posN.y;
    if(!horzSpan) dstP = posP.y - posM.y;
/*--------------------------------------------------------------------------*/
    FxaaBool goodSpanN = (lumaEndN < 0.0) != lumaMLTZero;
    FxaaFloat spanLength = (dstP + dstN);
    FxaaBool goodSpanP = (lumaEndP < 0.0) != lumaMLTZero;
    FxaaFloat spanLengthRcp = 1.0/spanLength;
/*--------------------------------------------------------------------------*/
    FxaaBool directionN = dstN < dstP;
    FxaaFloat dst = min(dstN, dstP);
    FxaaBool goodSpan = directionN ? goodSpanN : goodSpanP;
    FxaaFloat subpixG = subpixF * subpixF;
    FxaaFloat pixelOffset = (dst * (-spanLengthRcp)) + 0.5;
    FxaaFloat subpixH = subpixG * fxaaQualitySubpix;
/*--------------------------------------------------------------------------*/
    FxaaFloat pixelOffsetGood = goodSpan ? pixelOffset : 0.0;
    FxaaFloat pixelOffsetSubpix = max(pixelOffsetGood, subpixH);
    if(!horzSpan) posM.x += pixelOffsetSubpix * lengthSign;
    if( horzSpan) posM.y += pixelOffsetSubpix * lengthSign;
    #if (FXAA_DISCARD == 1)
        return FxaaTexTop(tex, posM);
    #else
        return FxaaFloat4(FxaaTexTop(tex, posM).xyz, lumaM);
    #endif
}
/*==========================================================================*/
#endif

struct VSInput
{
  float3 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct VSOutput
{
  float4 Position : POSITION0;
  float2 Tex : TEXCOORD0;
};

struct PSOutput
{
  float4 Color : COLOR0;
};

VSOutput MegaVertexShader(VSInput vsin){
  VSOutput vsout;
  vsout.Position = float4(vsin.Position, 1.0);
  #ifdef DX9
    vsout.Position.xy -= float2(1.0, -1.0) / viewport_size;
  #endif
  vsout.Tex = vsin.Tex;
  return vsout;
}

cbuffer local : register(b1) {
  float pixelwidth, pixelheight, SubPixelQuality, EdgeThreshold, EdgeThresholdMin;
};

PSOutput MegaPixelShader(VSOutput psin) {
  PSOutput pso;
  // build fxaa data ------------------------------------------------------------
  FxaaFloat2 pos = psin.Tex;
  FxaaFloat4 fxaaConsolePosPos = float4(psin.Tex - float2(pixelwidth/2, pixelheight/2), psin.Tex + float2(pixelwidth/2, pixelheight/2));
  FxaaTex tex = {ColorTextureSampler, ColorTexture};
  FxaaFloat2 fxaaQualityRcpFrame = float2(pixelwidth, pixelheight);
  FxaaFloat fxaaQualitySubpix = SubPixelQuality;
  FxaaFloat fxaaQualityEdgeThreshold = EdgeThreshold;
  FxaaFloat fxaaQualityEdgeThresholdMin = EdgeThresholdMin;

  // apply fxaa -----------------------------------------------------------------
  pso.Color = FxaaPixelShader(
    pos,
    fxaaConsolePosPos,
    tex,
    fxaaQualityRcpFrame,
    fxaaQualitySubpix,
    fxaaQualityEdgeThreshold,
    fxaaQualityEdgeThresholdMin
  );

  return pso;
}

#include FullscreenQuadFooter.fx
   �  8   ��
 F U R S H A D E R . F X         0 	        #block defines
  #inherited
  #define SMOOTHED_NORMAL
#endblock

#block custom_parameters
  float3 fur_move;
  float fur_shell_factor, fur_thickness, fur_gravitation_factor;
#endblock

#block vs_worldposition
  #inherited
  float fur_mask_length = tex2Dlod(VariableTexture1Sampler, float4(vsin.Tex, 0, 0)).g;
  float final_fur_thickness = fur_thickness * (1 - fur_mask_length);
  float3 outset = SmoothedNormal * final_fur_thickness * fur_shell_factor;
  float3 move_vector = fur_move * final_fur_thickness * fur_shell_factor * (dot(fur_move, SmoothedNormal) + 1) * 0.5;
  Worldposition.xyz += outset + move_vector;
  // gravitation
  Worldposition.y -= sin(fur_shell_factor * 3.14 * 0.5) * final_fur_thickness * (-(SmoothedNormal.y - 1) * 0.5 + 0.5) * fur_gravitation_factor;
#endblock

#block after_pixelshader
  float4 fur_mask = tex2D(VariableTexture1Sampler, psin.Tex);
  float fur_mask_shadow = tex2D(VariableTexture1Sampler, psin.Tex + float2(0.02, 0.02)).a;
  pso.Color.rgb = pso.Color.rgb*0.6 * fur_mask_shadow + pso.Color.rgb * (1-fur_mask_shadow);
  pso.Color.a *= fur_mask.a * (1-fur_shell_factor) * fur_mask.r;
#endblock
   |  D   ��
 P O S T E F F E C T B L O O M . F X         0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float3 threshold, threshold_width;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  pso.Color.a = 1;
  pso.Color.rgb = tex2D(ColorTextureSampler, psin.Tex).rgb;
  #ifdef THRESHOLD_RGB
    float3 rgb_factor = ((threshold - pso.Color.rgb) / threshold_width);
    float bloom_factor = max(rgb_factor.x, max(rgb_factor.y, rgb_factor.z));
  #endif
  #ifdef THRESHOLD_LUMA
    float luma = dot(pso.Color.rgb, float3(0.299, 0.587, 0.114));
    float bloom_factor = (threshold.x - luma) / threshold_width.x;
  #endif
  #ifdef THRESHOLD_HSV
    float3 hsv = RGBToHSV(pso.Color.rgb);
    float bloom_factor = ((threshold.x - hsv.z) / threshold_width.x);
  #endif
  pso.Color.rgb = lerp(pso.Color.rgb, float3(0, 0, 0), saturate(bloom_factor));
  return pso;
}

#include FullscreenQuadFooter.fx
�  x   ��
 F O R W A R D S O F T P A R T I C L E W I T H O U T B A C K G R O U N D S H A D E R . F X       0 	        #block after_pixelshader
  float2 pixel_tex = (psin.vPos.xy + float2(0.5, 0.5)) / viewport_size;
  float particle_depth = distance(psin.Worldposition, CameraPosition);
  float Depth = tex2Dlod(VariableTexture1Sampler, float4(pixel_tex, 0, 0)).a;
  Depth = (Depth == 0) ? 1000.0 : Depth;
  pso.Color.a = pso.Color.a * saturate((Depth - particle_depth) / Softparticlerange);
#endblock

�   <   ��
 M E S H O U T L I N E . F X         0 	        #block custom_parameters
  float4 outline_color;
#endblock

#block after_pixelshader
  pso.Color = float4(outline_color.rgb, pso.Color.a * outline_color.a);
#endblock
  �  X   ��
 P O S T E F F E C T C O L O R C O R R E C T I O N . F X         0 	        #include FullscreenQuadHeader.fx

cbuffer local : register(b1)
{
  float shadows, midtones, lights;
};

PSOutput MegaPixelShader(VSOutput psin){
  PSOutput pso;
  float3 scene_color = tex2D(ColorTextureSampler,psin.Tex).rgb;
  // rescale linear color scale
  scene_color = saturate((scene_color - shadows) / lights);
  // gamma correct
  scene_color = pow(scene_color, midtones);
  pso.Color = float4(scene_color, 1.0);
  return pso;
}

#include FullscreenQuadFooter.fx �  p   ��
 F O R W A R D P A R T I C L E S H A D E R A L P H A S U B T R A C T I O N . F X         0 	        #block pixelshader_diffuse
  #ifdef VERTEXCOLOR
    #ifdef DIFFUSETEXTURE
      pso.Color = tex2D(ColorTextureSampler,psin.Tex);
      pso.Color.rgb *= psin.Color.rgb;
      pso.Color.a *= 2;
      pso.Color.a -= psin.Color.a * 2;
    #else
      pso.Color = psin.Color;
    #endif
  #else
    #ifdef DIFFUSETEXTURE
      pso.Color = tex2D(ColorTextureSampler, psin.Tex);
    #else
      pso.Color = float4(0.5, 0.5, 0.5, 1.0);
    #endif
  #endif
#endblock
