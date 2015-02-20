`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Module Name: TextGraphic  ( by Giacomazzi Riccardo 19-02-2015 )
//
// Description: 
// - Video Mode: 960x540@60Hz
// - Text Mode: 120x60 16 Color
// - Char Matrix: 8x9
// - 3 Blink Modes: Foreground / Background / Both
//
//////////////////////////////////////////////////////////////////////////////////

module TextGraphic
( input clk50,
  output [3:0] tmds_out_p,
  output [3:0] tmds_out_n,
  input [12:0] WAddr,
  input [17:0] WData,
  input WClk,
  input Write
);

  parameter integer H_sync_start = 0;        
  parameter integer H_sync_stop = 152;       // HSync 152 Pixel (3,8us)
  parameter integer H_img_start = 152+44;    // Front Porch 44 Pixel
  parameter integer H_img_stop = 959+152+44; // Image Width 960 
  parameter integer H_screen_stop = 1200;    // Image + Front Porch + HSync + Back Porch
  parameter integer V_sync_start = 0;        
  parameter integer V_sync_stop = 5;         // VSync 5 Row (150us)
  parameter integer V_img_start = 12+5;      // Front Porch 12 Row
  parameter integer V_img_stop = 539+12+5;   // Image Height 540
  parameter integer V_screen_stop = 567;     // Image + Front Porch + VSync + Back Porch

  // DCM Derivated Clocks
  wire SEQ_IN_0;    // PixClk shift 90

  reg [23:0] Palette[15:0];
  integer SynRow;
  integer SynCol;
  reg [3:0] CharLine;
  reg [15:0] BaseAddr;
  reg [15:0] TextAddr;
  reg [9:0] VideoRow;
  reg [9:0] VideoCol;
  reg HSync;
  reg VSync;
  reg VideoEnable;
  reg [13:0] ADDRA;
  wire [31:0] DOA[7:0];
  wire [3:0] DOPA[7:0];
  reg [15:0] VideoData;
  wire [31:0] G_DOA;
  wire [3:0] G_DOPA;
  reg [13:0] G_ADDRA;
  reg Pixel;
  reg [7:0] Red;
  reg [7:0] Green;
  reg [7:0] Blue;
  reg [3:0] Foreground;
  reg [3:0] Background;
  reg BlinkStatus;
  reg [1:0] Blink;
  integer BlinkCounter;

  initial
    begin
	   Palette[0] = 24'h000000;     // Standard CGA Palette
	   Palette[1] = 24'h0000AA;
	   Palette[2] = 24'h00AA00;
	   Palette[3] = 24'h00AAAA;
	   Palette[4] = 24'hAA0000;
	   Palette[5] = 24'hAA00AA;
	   Palette[6] = 24'hAA5500;
	   Palette[7] = 24'hAAAAAA;
	   Palette[8] = 24'h555555;
	   Palette[9] = 24'h5555FF;
	   Palette[10] = 24'h55FF55;
	   Palette[11] = 24'h55FFFF;
	   Palette[12] = 24'hFF5555;
	   Palette[13] = 24'hFF55FF;
	   Palette[14] = 24'hFFFF55;
	   Palette[15] = 24'hFFFFFF;
      SynRow = 0;
      SynCol = 0;
		HSync = 1'b0;
		VSync = 1'b0;
		VideoEnable = 1'b0;
		CharLine = 4'h0;
		BaseAddr = 16'h0000;
		BlinkStatus = 1'b0;
		BlinkCounter = 0;
		Blink = 2'b00;
    end

// ************************************************************************************************
// * Position Beam Update
// ************************************************************************************************

  always @(posedge PixClk)
    begin
	   if (SynCol < H_screen_stop) SynCol = SynCol + 1;
		else
		  begin
		    SynCol = 0;
			 if (SynRow < V_screen_stop) 
			   begin 
				  SynRow = SynRow + 1;
				  if (SynRow > V_img_start)
				    begin
					   if (CharLine < 8)
						  begin
  				          CharLine = CharLine + 1;
						  end
						else
                    begin
						    CharLine = 4'h0;
							 BaseAddr = BaseAddr + 960;
                    end						  
					 end
				  else
				    begin
					 end
				end
			 else
            begin			 
			     SynRow = 0;
		        CharLine = 4'h0;
				  BaseAddr = 16'h0000;
				end
		  end
		if (BlinkCounter < 20000000)
		  begin
		    BlinkCounter = BlinkCounter + 1;
		  end
		else
		  begin
		    BlinkCounter = 0;
			 BlinkStatus = (BlinkStatus == 1'b0) ? 1'b1 : 1'b0;
		  end
    end

  always @(negedge SEQ_IN_0)
    begin
      HSync = ((SynCol < H_sync_start) || (SynCol > H_sync_stop)) ? 1'b0 : 1'b1;
		VSync = ((SynRow < V_sync_start) || (SynRow > V_sync_stop)) ? 1'b0 : 1'b1;
		VideoEnable = ((SynCol < H_img_start) || (SynRow < V_img_start) || (SynCol > H_img_stop) || (SynRow > V_img_stop)) ? 1'b0 : 1'b1;
      VideoCol = ((SynCol < H_img_start) || (SynCol > H_img_stop)) ? 10'h000 : SynCol - H_img_start;
      VideoRow = ((SynRow < V_img_start) || (SynRow > V_img_stop)) ? 10'h000 : SynRow - V_img_start;
		TextAddr = BaseAddr + VideoCol;
		ADDRA = {TextAddr[12:3], 4'h0};
      VideoData = DOA[TextAddr[15:13]][15:0];
		Blink = DOPA[TextAddr[15:13]][1:0];
      G_ADDRA = {VideoData[7:0], VideoCol[2:0], 3'b000};
		Foreground = VideoData[11:8];
		Background = VideoData[15:12];
      Pixel = (CharLine < 8) ? G_DOA[CharLine] : G_DOPA[0];
      case(Blink)
        2'b01: if (BlinkStatus == 0)
		           begin
		             Red = (Pixel == 0) ? Palette[Background][23:16] : Palette[Foreground][23:16];
                   Green = (Pixel == 0) ? Palette[Background][15:8] : Palette[Foreground][15:8];
                   Blue = (Pixel == 0) ? Palette[Background][7:0] : Palette[Foreground][7:0];
					  end	 
					else
					  begin
		             Red = Palette[Background][23:16];
                   Green = Palette[Background][15:8];
                   Blue = Palette[Background][7:0];
					  end
        2'b10: if (BlinkStatus == 0)
		           begin
		             Red = (Pixel == 0) ? Palette[Background][23:16] : Palette[Foreground][23:16];
                   Green = (Pixel == 0) ? Palette[Background][15:8] : Palette[Foreground][15:8];
                   Blue = (Pixel == 0) ? Palette[Background][7:0] : Palette[Foreground][7:0];
					  end	 
					else
					  begin
		             Red = Palette[Foreground][23:16];
                   Green = Palette[Foreground][15:8];
                   Blue = Palette[Foreground][7:0];
					  end
        2'b11: if (BlinkStatus == 0)
		           begin
		             Red = (Pixel == 0) ? Palette[Background][23:16] : Palette[Foreground][23:16];
                   Green = (Pixel == 0) ? Palette[Background][15:8] : Palette[Foreground][15:8];
                   Blue = (Pixel == 0) ? Palette[Background][7:0] : Palette[Foreground][7:0];
					  end	 
					else
					  begin
		             Red = (Pixel == 0) ? Palette[Foreground][23:16] : Palette[Background][23:16];
                   Green = (Pixel == 0) ? Palette[Foreground][15:8] : Palette[Background][15:8];
                   Blue = (Pixel == 0) ? Palette[Foreground][7:0] : Palette[Background][7:0];
					  end
        default: begin
		             Red = (Pixel == 0) ? Palette[Background][23:16] : Palette[Foreground][23:16];
                   Green = (Pixel == 0) ? Palette[Background][15:8] : Palette[Foreground][15:8];
                   Blue = (Pixel == 0) ? Palette[Background][7:0] : Palette[Foreground][7:0];
					  end	 
		endcase
    end  

// ************************************************************************************************
// * TMDS Encoding & Serialization
// ************************************************************************************************

  wire PixClk;
  wire PixClk_2;
  wire PixClk_10;
  wire SerDesStrobe;
  wire [9:0] EncRed;
  wire [9:0] EncGreen;
  wire [9:0] EncBlue;
  wire SerOutRed;
  wire SerOutGreen;
  wire SerOutBlue;
  wire SerOutClock;

  Component_encoder CE_Red(.Data(Red), .C0(1'b0), .C1(1'b0), .DE(VideoEnable), .PixClk(PixClk), .OutEncoded(EncRed));
  Component_encoder CE_Green(.Data(Green), .C0(1'b0), .C1(1'b0), .DE(VideoEnable), .PixClk(PixClk), .OutEncoded(EncGreen));
  Component_encoder CE_Blue(.Data(Blue), .C0(HSync), .C1(VSync), .DE(VideoEnable), .PixClk(PixClk), .OutEncoded(EncBlue));

  Serializer_10_1 SER_Red(.Data(EncRed), .Clk_10(PixClk_10), .Clk_2(PixClk_2), .Strobe(SerDesStrobe), .Out(SerOutRed));
  Serializer_10_1 SER_Green(.Data(EncGreen), .Clk_10(PixClk_10), .Clk_2(PixClk_2), .Strobe(SerDesStrobe), .Out(SerOutGreen));
  Serializer_10_1 SER_Blue(.Data(EncBlue), .Clk_10(PixClk_10), .Clk_2(PixClk_2), .Strobe(SerDesStrobe), .Out(SerOutBlue));
  Serializer_10_1 SER_Clock(.Data(10'b0000011111), .Clk_10(PixClk_10), .Clk_2(PixClk_2), .Strobe(SerDesStrobe), .Out(SerOutClock));
  
  OBUFDS OutBufDif_B(.I(SerOutBlue), .O(tmds_out_p[0]), .OB(tmds_out_n[0]));
  OBUFDS OutBufDif_G(.I(SerOutGreen), .O(tmds_out_p[1]), .OB(tmds_out_n[1]));
  OBUFDS OutBufDif_R(.I(SerOutRed), .O(tmds_out_p[2]), .OB(tmds_out_n[2]));
  OBUFDS OutBufDif_C(.I(SerOutClock), .O(tmds_out_p[3]), .OB(tmds_out_n[3]));

// ************************************************************************************************
// * Text MAP RAM Port B: Write MAP Data by external usage
// ************************************************************************************************
  
  wire [13:0] ADDRB;
  wire [31:0] DIB0;
  wire [31:0] DIB1;
  wire [31:0] DIB2;
  wire [31:0] DIB3;
  wire [31:0] DIB4;
  wire [31:0] DIB5;
  wire [31:0] DIB6;
  wire [31:0] DIB7;
  wire [3:0] DIPB0;
  wire [3:0] DIPB1;
  wire [3:0] DIPB2;
  wire [3:0] DIPB3;
  wire [3:0] DIPB4;
  wire [3:0] DIPB5;
  wire [3:0] DIPB6;
  wire [3:0] DIPB7;
  
  wire [3:0] WEB0;
  wire [3:0] WEB1;
  wire [3:0] WEB2;
  wire [3:0] WEB3;
  wire [3:0] WEB4;
  wire [3:0] WEB5;
  wire [3:0] WEB6;
  wire [3:0] WEB7;

  assign ADDRB = {WAddr[9:0],4'h0};
  assign DIB0 = {16'h0000, WData[15:0]};
  assign DIB1 = {16'h0000, WData[15:0]};
  assign DIB2 = {16'h0000, WData[15:0]};
  assign DIB3 = {16'h0000, WData[15:0]};
  assign DIB4 = {16'h0000, WData[15:0]};
  assign DIB5 = {16'h0000, WData[15:0]};
  assign DIB6 = {16'h0000, WData[15:0]};
  assign DIB7 = {16'h0000, WData[15:0]};
  assign DIPB0 = {2'b00, WData[17:16]};
  assign DIPB1 = {2'b00, WData[17:16]};
  assign DIPB2 = {2'b00, WData[17:16]};
  assign DIPB3 = {2'b00, WData[17:16]};
  assign DIPB4 = {2'b00, WData[17:16]};
  assign DIPB5 = {2'b00, WData[17:16]};
  assign DIPB6 = {2'b00, WData[17:16]};
  assign DIPB7 = {2'b00, WData[17:16]};
  
  assign WEB0 = ((WAddr[12:10] == 3'b000) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB1 = ((WAddr[12:10] == 3'b001) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB2 = ((WAddr[12:10] == 3'b010) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB3 = ((WAddr[12:10] == 3'b011) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB4 = ((WAddr[12:10] == 3'b100) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB5 = ((WAddr[12:10] == 3'b101) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB6 = ((WAddr[12:10] == 3'b110) && (Write == 1)) ? 4'hF : 4'h0;
  assign WEB7 = ((WAddr[12:10] == 3'b111) && (Write == 1)) ? 4'hF : 4'h0;

// ************************************************************************************************
// * Graphic ROM Primitive
// ************************************************************************************************
  
  RAMB16BWER #(.DATA_WIDTH_A(9),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.SIM_DEVICE("SPARTAN6"),
               .INIT_00(256'h00F8A888001F111F00B8A8E8001F111F0080F890001F111F00F888F8001F111F),
               .INIT_01(256'h0018E808001F111F00E8A8F8001F111F00E8A8B8001F111F00F82038001F111F),
               .INIT_02(256'h0050A8F8001F111F00F828F8001F111F00F8A8B8001F111F00F8A8F8001F111F),
               .INIT_03(256'h000828F8001F111F0088A8F8001F111F007088F8001F111F008888F8001F111F),
               .INIT_04(256'h00F8A88800101F1200B8A8E800101F120080F89000101F1200F888F800101F12),
               .INIT_05(256'h0018E80800101F1200E8A8F800101F1200E8A8B800101F1200F8203800101F12),
               .INIT_06(256'h0050A8F800101F1200F828F800101F1200F8A8B800101F1200F8A8F800101F12),
               .INIT_07(256'h000828F800101F120088A8F800101F12007088F800101F12008888F800101F12),
               .INIT_08(256'h00147F14147F14000000070000070000000000065F0600000000000000000000),
               .INIT_09(256'h0000000003040000004848324D454A30006264081026460000122A6B6B2A2400),
               .INIT_0A(256'h000008083E08080000082A1C1C1C2A080000001C224100000000000041221C00),
               .INIT_0B(256'h0002040810204000000000006000000000080808080808000000000060800000),
               .INIT_0C(256'h00364949494122000066494951516200000040407F424400003E454951613E00),
               .INIT_0D(256'h000305097101030000304949494A3C0000394545454527000010507F52141810),
               .INIT_0E(256'h00000000668000000000000066000000001E2949494906000036494949493600),
               .INIT_0F(256'h0006095101010200000814224100000000242424242424000000004122140800),
               .INIT_10(256'h0022414141221C0000364949497F4100007C121111127C00001E55555D413E00),
               .INIT_11(256'h0072515141221C000003011D497F41000063415D497F4100001C2241417F4100),
               .INIT_12(256'h40412214087F410000013F4140403000000000417F410000007F080808087F00),
               .INIT_13(256'h001C224141221C00007F080402017F007F01020402017F0000604040417F4100),
               .INIT_14(256'h003249494949260000462919497F4100405E213121211E0000060909497F4100),
               .INIT_15(256'h3F40403840403F000F10204020100F00003F404040403F000301417F41010300),
               .INIT_16(256'h0000004141417F00614345495161430001024478440201004122140814224100),
               .INIT_17(256'h808080808080808000080402010204080000007F414141000040201008040201),
               .INIT_18(256'h002844444444380030484848307F010040785454545420000000000403000000),
               .INIT_19(256'h0478A4A4A4A49800000201497E4800000018545454543800407F314848483000),
               .INIT_1A(256'h00404428107F0100007D848080806000000000407D44000000780404087F4100),
               .INIT_1B(256'h00384444444438000078040404087C007804047804047C00000000407F410000),
               .INIT_1C(256'h002454545454480000180404487C44000084FC98242418000018242498FC8400),
               .INIT_1D(256'h3C40403840403C000C10204020100C00007C204040403C00002044443F040400),
               .INIT_1E(256'h00004141360808000000444C54644400007CA0A0A0A09C000000442810284400),
               .INIT_1F(256'h7048444244487000000102020101020000080836414100000000000077000000),
               .INIT_20(256'h0042795555552200001855555454380000407A4040403A00004AB1B191910E00),
               .INIT_21(256'h0040E4A4A4241800004078545554200000407854555520000041785454542100),
               .INIT_22(256'h0000417C4401000000185454555538000019545454543900001A555555553A00),
               .INIT_23(256'h0070282B2B28700000791412121479000000407C45010000000201417D450102),
               .INIT_24(256'h00304A49494A300049497F09090A7C00545438585454200000004555547C4400),
               .INIT_25(256'h00384040424138000038424141423800003048484A4930000032484848483200),
               .INIT_26(256'h002424E724241800003D404040403D000019244242241900007AA0A0A0A01A00),
               .INIT_27(256'h000209097F8888405090FA170585FF81000015167C16150000204241495E6800),
               .INIT_28(256'h00384244404038000030494A484830000000417D440000000040795554542000),
               .INIT_29(256'h000026292929260000282F29292926000078432211097A0000710A0A09097A00),
               .INIT_2A(256'hB0A9CAD488182F4A003808080808080000080808080838000020404045483000),
               .INIT_2B(256'h00081422081422000022140822140800000000007A00000020FD2A3428182F4A),
               .INIT_2C(256'h00000000FF00000077FFAADD77AAFFDD55AA55AA55AA55AA005500AA005500AA),
               .INIT_2D(256'h0000F010F01010100000FF00FF10101000000000FF14141400000000FF101010),
               .INIT_2E(256'h0000FC04F41414140000FF00FF0000000000FF00F714141400000000FC141414),
               .INIT_2F(256'h00000000F0101010000000001F14141400001F101F10101000001F1017141414),
               .INIT_30(256'h10101010FF00000010101010F0101010101010101F101010101010101F000000),
               .INIT_31(256'h1010FF00FF00000014141414FF00000010101010FF1010101010101010101010),
               .INIT_32(256'h1414F404F414141414141710171414141414F404FC000000141417101F000000),
               .INIT_33(256'h14141414171414141414F700F714141414141414141414141414F700FF000000),
               .INIT_34(256'h10101F101F0000001010F010F010101014141414F414141410101F101F101010),
               .INIT_35(256'h1010FF10FF1010101010F010F000000014141414FC000000141414141F000000),
               .INIT_36(256'hFFFFFFFFFFFFFFFF10101010F0000000000000001F10101014141414FF141414),
               .INIT_37(256'h0F0F0F0F0F0F0F0FFFFFFFFF0000000000000000FFFFFFFFF0F0F0F0F0F0F0F0),
               .INIT_38(256'h02027E027E0204000006020202027E0000142A2A2A2AFC004428102844443800),
               .INIT_39(256'h0202047C0202040000100E1010107E800004043C444438000063414949556300),
               .INIT_3A(256'h0030494D4D4A3000004C720101724C00001C2A49492A1C00000099A5E7A59900),
               .INIT_3B(256'h007E010101017E00000049492A1C00000019262C342458801C2214081422221C),
               .INIT_3C(256'h004040514A4440000040444A51404000000044445F444400002A2A2A2A2A2A00),
               .INIT_3D(256'h00122424121224000008086B6B080800000000007F80806000060101FE000000),
               .INIT_3E(256'h010101FF80402020000000101000000000000018180000000000000609090600),
               .INIT_3F(256'h000000000000000000003C3C3C3C0000000000121519120000001E0101011F00),
               .INITP_00(256'h0000000000000000000000000000000000000000000000000000000000000000),
               .INITP_01(256'h0000000000000000000000000000000000000000000000000000000000000000),
               .INITP_02(256'h0000000000000000000000000000000000000000000000000000000000000000),
               .INITP_03(256'h0000000000000000000000000000000000000000000000000000000000000000),
               .INITP_04(256'h0000000000000000000000000000000000000000000000000000000000000000),
               .INITP_05(256'h040000001414140414140404046D552200000000000000000000000000000000),
               .INITP_06(256'h0078077F7F040004141404000014040000140014140014001404040004040000),
               .INITP_07(256'h0000000000000000000000000000000000000000000000000000000000000000)
				  ) GraphROM (.DOA(G_DOA), 
                          .DOPA(G_DOPA),
                          .DOB(),
                          .DOPB(),
                          .ADDRA(G_ADDRA),
                          .CLKA(SEQ_IN_0),
                          .ENA(1'b1),
                          .REGCEA(1'b0),
                          .RSTA(1'b0),
                          .WEA(4'h0),
                          .DIA(32'h00000000),
                          .DIPA(4'h0),
                          .ADDRB(14'h0000),
                          .CLKB(1'b0),
                          .ENB(1'b0),
                          .REGCEB(1'b0),
                          .RSTB(1'b0),
                          .WEB(4'h0),
                          .DIB(32'h00000000),
                          .DIPB(4'h0));

// ************************************************************************************************
// * Text MAP RAM Primitive
// ************************************************************************************************

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM0 (.DOA(DOA[0]), 
                      .DOPA(DOPA[0]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB0),
                      .DIB(DIB0),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM1 (.DOA(DOA[1]), 
                      .DOPA(DOPA[1]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB1),
                      .DIB(DIB1),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM2 (.DOA(DOA[2]), 
                      .DOPA(DOPA[2]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB2),
                      .DIB(DIB2),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM3 (.DOA(DOA[3]), 
                      .DOPA(DOPA[3]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB3),
                      .DIB(DIB3),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM4 (.DOA(DOA[4]), 
                      .DOPA(DOPA[4]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB4),
                      .DIB(DIB4),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM5 (.DOA(DOA[5]), 
                      .DOPA(DOPA[5]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB5),
                      .DIB(DIB5),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM6 (.DOA(DOA[6]), 
                      .DOPA(DOPA[6]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB6),
                      .DIB(DIB6),
                      .DIPB(DIPB0));

  RAMB16BWER #(.DATA_WIDTH_A(18),
               .DATA_WIDTH_B(18),
               .DOA_REG(0),
					.EN_RSTRAM_A("FALSE"),
					.EN_RSTRAM_B("FALSE"),
					.SIM_DEVICE("SPARTAN6")
				  ) RAM7 (.DOA(DOA[7]), 
                      .DOPA(DOPA[7]),
                      .DOB(),
                      .DOPB(),
                      .ADDRA(ADDRA),
                      .CLKA(SEQ_IN_0),
                      .ENA(1'b1),
                      .REGCEA(1'b0),
                      .RSTA(1'b0),
                      .WEA(4'h0),
                      .DIA(32'h00000000),
                      .DIPA(4'h0),
                      .ADDRB(ADDRB),
                      .CLKB(WClk),
                      .ENB(1'b1),
                      .REGCEB(1'b0),
                      .RSTB(1'b0),
                      .WEB(WEB7),
                      .DIB(DIB7),
                      .DIPB(DIPB0));

// ************************************************************************************************
// * DCM Primitive used by Sequencer
// ************************************************************************************************

  DCM_SP #(.CLKIN_DIVIDE_BY_2("FALSE"),
           .CLKIN_PERIOD(12.5),                  // 12.5ns = 80MHz
           .CLKOUT_PHASE_SHIFT("NONE"),
           .CLK_FEEDBACK("1X"),
           .DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"),
           .STARTUP_WAIT("FALSE")
          ) DCM_Sequencer(.CLK0(DCM_FB),         // Used for DCM Feedback
                          .CLK180(),             
                          .CLK270(),             
                          .CLK2X(SEQ_IN_0),      // PixClk * 4 = 160MHz
                          .CLK2X180(),
                          .CLK90(),              
                          .CLKDV(),
                          .CLKFX(),
                          .CLKFX180(),
                          .LOCKED(),
                          .PSDONE(),
                          .STATUS(),
                          .CLKFB(DCM_FB),        // From CLK0 for DCM Feedback
                          .CLKIN(PixClk_2),      // Pixel Clock * 2: 80MHz from PLL
                          .DSSEN(1'b0),
                          .PSCLK(1'b0),
                          .PSEN(1'b0),
                          .PSINCDEC(1'b0),
                          .RST(1'b0));

// ************************************************************************************************
// * PLL VCO:400MHz  PixClk:40MHz
// ************************************************************************************************

  wire pll_fbout;      // PLL Feedback
  wire pll_clk10x;     // From PLL to BUFPLL
  wire pll_clk2x;      // From PLL to BUFG
  wire pll_clk1x;      // From PLL to BUFG
  wire pll_locked;
  
  PLL_BASE #(.CLKOUT0_DIVIDE(1),  // IO clock 400MHz (VCO)
             .CLKOUT1_DIVIDE(5),  // Intermediate clock 80MHz (VCO / 5)
             .CLKOUT2_DIVIDE(10), // Pixle Clock 40MHz (VCO / 10)
             .CLKFBOUT_MULT(8),   // VCO = 50MHz * 8 = 400MHz ...
             .DIVCLK_DIVIDE(1),   // ... 400MHz / 1 = 400MHz
             .CLKIN_PERIOD(20.00) // 20ns = 50MHz
            ) ClockGenPLL(.CLKIN(clk50),
                          .CLKFBIN(pll_fbout),
                          .RST(1'b0),
                          .CLKOUT0(pll_clk10x),
                          .CLKOUT1(pll_clk2x),
                          .CLKOUT2(pll_clk1x),
                          .CLKOUT3(),
                          .CLKOUT4(),
                          .CLKOUT5(),
                          .CLKFBOUT(pll_fbout),
                          .LOCKED(pll_locked));

  BUFG Clk1x_buf(.I(pll_clk1x), .O(PixClk));
  BUFG Clk2x_buf(.I(pll_clk2x), .O(PixClk_2));
  
  BUFPLL #(.DIVIDE(5),
           .ENABLE_SYNC("TRUE")
          ) Clk10x_buf(.PLLIN(pll_clk10x),
                       .GCLK(PixClk_2),
                       .LOCKED(pll_locked),
                       .IOCLK(PixClk_10),
                       .SERDESSTROBE(SerDesStrobe),
                       .LOCK());

endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////

// ************************************************************************************************
// * TMDS Component Encoder - Data:8/10  Control:2/10
// ************************************************************************************************

module Component_encoder
( input [7:0] Data,
  input C0,
  input C1,
  input DE,
  input PixClk,
  output [9:0] OutEncoded
);

  integer Cnt;
  integer NewCnt;
  reg [8:0] q_m;
  integer N1_Data;
  integer N1_qm;
  integer N0_qm;
  reg [9:0] Encoded;

  initial
    begin
      Cnt = 0;
      NewCnt = 0;
    end

  assign OutEncoded = Encoded;
  
  always @(posedge PixClk)
    begin
      N1_Data = Data[0] + Data[1] + Data[2] + Data[3] + Data[4] + Data[5] + Data[6] + Data[7];
      if ((N1_Data > 4) || ((N1_Data == 4) && (Data[0] == 0)))
        begin
          q_m[0] = Data[0];
          q_m[1] = ~(q_m[0] ^ Data[1]);
          q_m[2] = ~(q_m[1] ^ Data[2]);
          q_m[3] = ~(q_m[2] ^ Data[3]);
          q_m[4] = ~(q_m[3] ^ Data[4]);
          q_m[5] = ~(q_m[4] ^ Data[5]);
          q_m[6] = ~(q_m[5] ^ Data[6]);
          q_m[7] = ~(q_m[6] ^ Data[7]);
          q_m[8] = 0;
        end
      else
        begin
          q_m[0] = Data[0];
          q_m[1] = q_m[0] ^ Data[1];
          q_m[2] = q_m[1] ^ Data[2];
          q_m[3] = q_m[2] ^ Data[3];
          q_m[4] = q_m[3] ^ Data[4];
          q_m[5] = q_m[4] ^ Data[5];
          q_m[6] = q_m[5] ^ Data[6];
          q_m[7] = q_m[6] ^ Data[7];
          q_m[8] = 1;
        end
      N1_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7]; 
      N0_qm = 8 - N1_qm;
      if (DE == 1)
        begin
          if ((Cnt == 0) || (N1_qm == 4))
            begin
              if (q_m[8] == 0)
                begin
                  Encoded[9] = 1;
                  Encoded[8] = 0;
                  Encoded[7:0] = ~q_m[7:0];
                  NewCnt = Cnt + N0_qm - N1_qm;
                end
              else
                begin
                  Encoded[9] = 0;
                  Encoded[8] = 1;
                  Encoded[7:0] = q_m[7:0];
                  NewCnt = Cnt + N1_qm - N0_qm;
                end
            end
          else
            begin
              if (((Cnt > 0) && (N1_qm > 4)) || ((Cnt < 0) && (N1_qm < 4)))
                begin
                  if (q_m[8] == 0)
                    begin
                      Encoded[9] = 1;
                      Encoded[8] = 0;
                      Encoded[7:0] = ~q_m[7:0];
                      NewCnt = Cnt + N0_qm - N1_qm;
                    end
                  else
                    begin
                      Encoded[9] = 1;
                      Encoded[8] = 1;
                      Encoded[7:0] = ~q_m[7:0];
                      NewCnt = Cnt + N0_qm - N1_qm + 2;
                    end
                end
              else
                begin
                  if (q_m[8] == 0)
                    begin
                      Encoded[9] = 0;
                      Encoded[8] = 0;
                      Encoded[7:0] = q_m[7:0];
                      NewCnt = Cnt + N1_qm - N0_qm - 2;
                    end
                  else
                    begin
                      Encoded[9] = 0;
                      Encoded[8] = 1;
                      Encoded[7:0] = q_m[7:0];
                      NewCnt = Cnt + N1_qm - N0_qm;
                    end
                end                                           
            end
        end
      else
        begin
          NewCnt = 0;
          case({C0,C1})
            2'b10:   Encoded = 10'b0010101011;
            2'b01:   Encoded = 10'b0101010100;
            2'b11:   Encoded = 10'b1010101011;
            default: Encoded = 10'b1101010100;
          endcase        
        end                    
    end
  
  always @(negedge PixClk)
    begin
      Cnt = NewCnt;
    end  

endmodule

///////////////////////////////////////////////////////////////////////////////////////////////////

// ************************************************************************************************
// * TMDS Serializer 10/1
// ************************************************************************************************

module Serializer_10_1
( input [9:0] Data,
  input Clk_10,
  input Clk_2,
  input Strobe,
  output Out
);

  reg Status;
  reg [9:0] FullData;  // Buffered Data in
  reg [4:0] HalfData;  // Buffered Data out
  wire cascade_in;
  wire cascade_out;
  
  initial
    begin
      Status = 1'b0;
      FullData[4:0] = 5'h000;
      HalfData[4:0] = 5'h00;
    end

  always @(posedge Clk_2)
    begin
      if (Status == 1'b0)
        begin
          FullData[4:0] = Data[9:5];
          HalfData[4:0] = Data[4:0];
          Status = 1'b1;
        end
      else
        begin
          HalfData[4:0] = FullData[4:0];
          Status = 1'b0;
        end
    end

  OSERDES2 #(.DATA_RATE_OQ("SDR"),
             .DATA_RATE_OT("SDR"),
             .DATA_WIDTH(5),
             .SERDES_MODE("MASTER")
            ) MasterSerDes(.CLK0(Clk_10),
                           .CLK1(1'b0),
                           .CLKDIV(Clk_2),
                           .IOCE(Strobe),
                           .D4(1'b0),
                           .D3(1'b0),
                           .D2(1'b0),
                           .D1(HalfData[4]),
                           .OCE(1'b1),
                           .RST(1'b0),
                           .T4(1'b0),
                           .T3(1'b0),
                           .T2(1'b0),
                           .T1(1'b0),
                           .TCE(1'b0),
                           .SHIFTIN1(1'b0),
                           .SHIFTIN2(1'b0),
                           .SHIFTIN3(cascade_in),
                           .SHIFTIN4(1'b0),
                           .TRAIN(1'b0),
                           .OQ(Out),
                           .TQ(),
                           .SHIFTOUT1(cascade_out),
                           .SHIFTOUT2(),
                           .SHIFTOUT3(),
                           .SHIFTOUT4());

  OSERDES2 #(.DATA_RATE_OQ("SDR"),
             .DATA_RATE_OT("SDR"),
             .DATA_WIDTH(5),
             .SERDES_MODE("SLAVE")
            ) SlaveSerDes(.CLK0(Clk_10),
                          .CLK1(1'b0),
                          .CLKDIV(Clk_2),
                          .IOCE(Strobe),
                          .D4(HalfData[3]),
                          .D3(HalfData[2]),
                          .D2(HalfData[1]),
                          .D1(HalfData[0]),
                          .OCE(1'b1),
                          .RST(1'b0),
                          .T4(1'b0),
                          .T3(1'b0),
                          .T2(1'b0),
                          .T1(1'b0),
                          .TCE(1'b0),
                          .SHIFTIN1(cascade_out),
                          .SHIFTIN2(1'b0),
                          .SHIFTIN3(1'b0),
                          .SHIFTIN4(1'b0),
                          .TRAIN(1'b0),
                          .OQ(),
                          .TQ(),
                          .SHIFTOUT1(),
                          .SHIFTOUT2(),
                          .SHIFTOUT3(cascade_in),
                          .SHIFTOUT4());

endmodule
