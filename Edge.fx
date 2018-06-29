
float PixelScaleminus : CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "EdgeScale-"; >;
float PixelScaleplus : CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "EdgeScale+"; >;
float EdgeShadowColor : CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "EdgeColor"; >;
float Shadowdisable : CONTROLOBJECT < string name = "PixelStyleController.pmx"; string item = "ShadowDisable"; >;


static float ShadowCol = 0.2 * EdgeShadowColor;
static float EdgeScale = 0.2*(1+PixelScaleplus)-PixelScaleminus*0.1;


float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;


float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;

float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   
bool     transp;   
bool	 spadd;   
#define SKII1    1500
#define SKII2    8000
#define Toon     3


texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;    
    float4 ZCalcTex : TEXCOORD0;   
    float2 Tex      : TEXCOORD1;   
    float3 Normal   : TEXCOORD2;   
    float3 Eye      : TEXCOORD3;  
    float2 SpTex    : TEXCOORD4;	
    float4 Color    : COLOR0;     
};


BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;


    Out.Pos = mul( Pos, WorldViewProjMatrix );
    

    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );

    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    

    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    

    Out.Tex = Tex;
    
    if ( useSphereMap ) {

        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}


float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{

    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);
    if ( useTexture ) {

        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {

        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color.rgb *= TexColor.rgb;
            ShadowColor.rgb *= TexColor.rgb;
        }
    }

    Color.rgb += Specular;


	
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        return Color;
    } else {
        float comp;
        if(parthf) {

            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {

            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        if ( useToon ) {
 
            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
        
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
		if (Shadowdisable) {
		ans   = Color;
		}
        return ans;
    }
}

BufferShadow_OUTPUT BufferShadow_VS2(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	float len = length(CameraPosition - mul(Pos,WorldMatrix));
	EdgeScale *= len*0.01;

	Pos.xyz += normalize(Normal)*EdgeScale;


    Out.Pos = mul( Pos, WorldViewProjMatrix );
    

    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );

    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    

    Out.Color.rgb = saturate( max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb + AmbientColor );
    Out.Color.a = DiffuseColor.a;
    

    Out.Tex = Tex;
    
    return Out;
}


float4 BufferShadow_PS2(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{

    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  
    if ( useTexture ) {

        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {

        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color.rgb *= TexColor.rgb;
            ShadowColor.rgb *= TexColor.rgb;
        }
    }

    Color.rgb += Specular;
    
    Color.rgb *= ShadowCol;
    ShadowColor.rgb *= ShadowCol;
    

    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
	
	Color = ShadowColor;
	
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        return Color;
    } else {
        float comp;
        if(parthf) {

            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
   
            comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
        }
        if ( useToon ) {

            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
        
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
        return ans;
    }
}

technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
     pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
     pass DrawObject2 {
     	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(false, false, false);
    }
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
     pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
     pass DrawObject2 {
     	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
    pass DrawObject2 {
    	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
    pass DrawObject2 {
    	CULLMODE =CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(true, true, false);
    }
}


technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true;string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
    pass DrawObject2 {
    	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
	pass DrawObject2 {
    	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true;string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
	pass DrawObject2 {
    	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject2;"
	    "Pass=DrawObject;"
    ;
 >{
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
    pass DrawObject2 {
    	CULLMODE = CW;
        VertexShader = compile vs_3_0 BufferShadow_VS2(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS2(true, true, true);
    }
}

