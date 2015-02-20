`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Module Name: Hello  ( by Giacomazzi Riccardo 19-02-2015 )
//
// Description: Demo for TextGraphic module
//
//////////////////////////////////////////////////////////////////////////////////

module Hello
( input clk50,
  output [3:0] tmds_out_p,
  output [3:0] tmds_out_n
);

  reg [12:0] WAddr;
  reg [17:0] WData;
  reg Write;
  reg [7:0] String[14:0];
  reg [3:0] Status;
  reg [3:0] Index;
  reg [3:0] BG;
  reg [3:0] FG;
  reg [1:0] BL;
  integer Row;
  integer Col;
  
  wire Clock;
  
  BUFG ClockBuf(.I(clk50), .O(Clock));

  TextGraphic TEXT(.clk50(Clock), .tmds_out_p(tmds_out_p), .tmds_out_n(tmds_out_n), 
                   .WAddr(WAddr), .WData(WData), .WClk(Clock), .Write(Write));
						
  initial
    begin
	   String[0] = 8'h20;  // 
	   String[1] = 8'h48;  // H
	   String[2] = 8'h65;  // e
	   String[3] = 8'h6C;  // l
	   String[4] = 8'h6C;  // l
	   String[5] = 8'h6F;  // o
	   String[6] = 8'h2C;  // ,
	   String[7] = 8'h20;  //
	   String[8] = 8'h57;  // W
	   String[9] = 8'h6F;  // o
	   String[10] = 8'h72; // r
	   String[11] = 8'h6C; // l
	   String[12] = 8'h64; // d
	   String[13] = 8'h21; // !
	   String[14] = 8'h20; // 
		Status = 4'h0;
		Index = 4'h0;
		Write = 1'b0;
		WAddr = 13'h0000;
		WData = 18'h00000;
		Row = 0;
		Col = 0;
    end	 

  always @(negedge Clock)
    begin
	   case(Status)
		  4'h0: begin
		          Index = 4'h0;
					 WAddr = 0;
					 Row = 0;
					 Col = 0;
                Status = 4'h1;
				  end
		  4'h1: begin
		          if ((Col < 15) || ((Col > 29) && (Col < 45)) || ((Col > 59)&&(Col < 75)) || ((Col > 89)&&(Col < 105)))
					   begin
						  FG = Row[3:0];
						  BG = 4'hF - Row;
						end
				    else
					   begin
						  BG = Row[3:0];
						  FG = 4'hF - Row;
						end
					 if (Col < 30) BL = 2'b00;
					 else if (Col < 60) BL = 2'b01;
					      else if (Col < 90) BL = 2'b10;
							     else BL = 2'b11;
					 Status = 4'h2;
				  end
        4'h2: begin								  
		          WData = {BL, BG, FG, String[Index]};
					 Status = 4'h3;
				  end
		  4'h3: begin
                Write = 1'b1;
					 Status = 4'h4;
				  end
		  4'h4: begin
                Write = 1'b0;
					 Status = 4'h5;
				  end
		  4'h5: begin
		          if (Col < 119)
					   begin
						  Col = Col + 1;
						  if (Index < 14) Index = Index + 1;
						  else Index = 0;
						  WAddr = WAddr + 1;
						  Status = 4'h1;
						end
					 else
					   begin
						  Col = 0;
						  Index = 0;
						  WAddr = WAddr + 1;
						  if (Row < 15)
						    begin
							   Row = Row + 1;
								Status = 4'h1;
							 end
						  else
						    begin
							   Status = 4'h6;
							 end
						end
				  end
	     4'h6: Status = 4'h6;
		  default: Status = 4'h6;
		endcase
	 end

endmodule
