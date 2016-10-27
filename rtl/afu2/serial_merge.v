`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:        University of Southern California
// Engineer:       Ren Chen
// 
// Create Date:    14:06:11 11/01/2015 
// Design Name:    Serial_merge_node
// Module Name:    serial_merge 
// Project Name:   ANCS
// Target Devices: Intel-Harp
// Tool versions:  
// Description:  
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////


//////////////////////Serial Merge Node//////////////////////////
module serial_merge_top(inputA
                           ,inputB
				           ,start_in
						   ,start_out
				           ,clk
				           ,rst
				           ,outA
						   ,outB
						   ,in_ctrl_addr
						   ,out_ctrl_addr
    );
	
	parameter BLOCK_NUM = 1;
	parameter DATA_WIDTH = 32;
	parameter DATA_PARALLELSIM = 16 * BLOCK_NUM;
	parameter SEQ_SIZE = 512 * BLOCK_NUM;                //The size of the output merged sequence
	//parameter ADDR_WIDTH_RAM = $clog2(SEQ_SIZE)+1; //2N
	parameter NUM_STAGES = $clog2(DATA_PARALLELSIM);
	
	input  [DATA_WIDTH-1:0] inputA, inputB;
	input  start_in;
	input  in_ctrl_addr;
	input  clk, rst;
	output out_ctrl_addr;
	output start_out;
	output [DATA_WIDTH-1:0] outA, outB;
	
    wire start_out_w_i [NUM_STAGES-1:0];
	wire [DATA_WIDTH-1:0] outA_i [NUM_STAGES-1:0];
	wire [DATA_WIDTH-1:0] outB_i [NUM_STAGES-1:0];
	wire out_ctrl_addr_i [NUM_STAGES-1:0];
	
	serial_merge_stage #(DATA_WIDTH, 2) sms0(.inputA(inputA)
                                            ,.inputB(inputB)
				                            ,.start_in(start_in)
						                    ,.start_out(start_out_w_i[0])
				                            ,.clk(clk)
				                            ,.rst(rst)
				                            ,.outA(outA_i[0])
						                    ,.outB(outB_i[0])
						                    ,.in_ctrl_addr(out_ctrl_addr_i[0])
						                    ,.out_ctrl_addr(out_ctrl_addr)
											);						
	
	genvar i;
	generate
	for(i=0; i<NUM_STAGES-2; i=i+1)
	begin: SERIAL_MERGE
	serial_merge_stage #(DATA_WIDTH, 1<<(i+2)) sms_i(.inputA(outA_i[i])
                                            ,.inputB(outB_i[i])
				                            ,.start_in(start_out_w_i[i])
						                    ,.start_out(start_out_w_i[i+1])
				                            ,.clk(clk)
				                            ,.rst(rst)
				                            ,.outA(outA_i[i+1])
						                    ,.outB(outB_i[i+1])
						                    ,.in_ctrl_addr(out_ctrl_addr_i[i+1])
						                    ,.out_ctrl_addr(out_ctrl_addr_i[i])
											);	
    end
	endgenerate
	
	serial_merge_stage #(DATA_WIDTH, 1<<NUM_STAGES) sms_n(.inputA(outA_i[NUM_STAGES-2])
                                                         ,.inputB(outB_i[NUM_STAGES-2])
				                                         ,.start_in(start_out_w_i[NUM_STAGES-2])
						                                 ,.start_out(start_out)
				                                         ,.clk(clk)
				                                         ,.rst(rst)
				                                         ,.outA(outA)
						                                 ,.outB(outB)
						                                 ,.in_ctrl_addr(in_ctrl_addr)
						                                 ,.out_ctrl_addr(out_ctrl_addr_i[NUM_STAGES-2])
						   );
	
endmodule



//////////////////////Serial Merge Node//////////////////////////
module serial_merge(inputA
                   ,inputB
				   ,clk
				   ,rst
				   ,ctrl_addr
				   ,out
    );
	parameter DATA_WIDTH = 32;
	parameter SEQ_SIZE = 64;
	
	input[DATA_WIDTH-1:0] inputA;
	input[DATA_WIDTH-1:0] inputB;
	input clk;
	input rst;
	
	output ctrl_addr;
	output reg[DATA_WIDTH-1:0] out;
	
	wire ctrl_addr_w;
	
	assign ctrl_addr_w = (inputA > inputB);
	always@(posedge clk or posedge rst)
	begin
	  if(rst)
	  begin
		out <= 0;
	  end
	  else
	  begin
		  out <= (ctrl_addr_w ? inputB: inputA);
	  end
	end

	assign ctrl_addr = ctrl_addr_w;
endmodule

//////////////////////demux_1_to_2////////////////////////////////
module demux_1_to_2 #(parameter DATA_WIDTH = 32) (
    input ctrl,
    input [DATA_WIDTH-1:0] in,
    output reg [DATA_WIDTH-1:0] out0,
    output reg [DATA_WIDTH-1:0] out1
    );
    always @(*)
    begin
      if(!ctrl)
          begin out0 <= in; out1 <= 32'h0000_0000; end
      else
          begin out0 <= 32'h0000_0000; out1 <= in; end
    end

endmodule

//////////////////////Serial Merge Stage//////////////////////////
module serial_merge_stage(inputA
                         ,inputB
				         ,start_in
						 ,start_out
				         ,clk
				         ,rst
				         ,outA
						 ,outB
						 ,in_ctrl_addr
						 ,out_ctrl_addr
    );
	parameter DATA_WIDTH = 32;
	parameter SEQ_SIZE = 64;                       //The size of the output merged sequence
	parameter ADDR_WIDTH_RAM = $clog2(SEQ_SIZE)+1; //2N
	
	input  [DATA_WIDTH-1:0] inputA, inputB;
	input  start_in;
	input  in_ctrl_addr;
	input  clk, rst;
	output out_ctrl_addr;
	output reg start_out;	
	output [DATA_WIDTH-1:0] outA, outB;
	
	reg start_out_r;
	reg [ADDR_WIDTH_RAM-1:0] addrAR, addrAW, addrBR, addrBW;
	reg wenA, wenB;   
	
	wire [DATA_WIDTH-1:0] doutA, doutB;		 
    wire [DATA_WIDTH-1:0] dinA, dinB;	
	wire [ADDR_WIDTH_RAM-1:0]  addrAR_w, addrBR_w;
	
	///////////////////////Datapath//////////////////////
	generate
	if(SEQ_SIZE > 128)
	begin: mem_gen
	  bram_dp #(DATA_WIDTH,ADDR_WIDTH_RAM) output_bufferA(.clk(clk)
                                                     ,.wen(wenA)
                                                     ,.en(1'b1)
                                                     ,.addrR(addrAR_w)
													 ,.addrW(addrAW)
                                                     ,.din(dinA)
                                                     ,.dout(doutA));
	 bram_dp #(DATA_WIDTH,ADDR_WIDTH_RAM) output_bufferB(.clk(clk)
                                                     ,.wen(wenB)
                                                     ,.en(1'b1)
                                                     ,.addrR(addrBR_w)
													 ,.addrW(addrBW)
                                                     ,.din(dinB)
                                                     ,.dout(doutB));
	end
	else
	begin: mem_gen
	  wire [DATA_WIDTH-1:0] doutA_w,doutB_w;
	  reg [DATA_WIDTH-1:0] doutA_r,doutB_r;
	  
	  dist_ram_dp #(DATA_WIDTH,ADDR_WIDTH_RAM) output_bufferA(.clk(clk)
                                                          ,.wen(wenA)
                                                          ,.addrR(addrAR_w)
													      ,.addrW(addrAW)
                                                          ,.din(dinA)
                                                          ,.dout(doutA_w));
      dist_ram_dp #(DATA_WIDTH,ADDR_WIDTH_RAM) output_bufferB(.clk(clk)
                                                          ,.wen(wenB)
                                                          ,.addrR(addrBR_w)
													      ,.addrW(addrBW)
                                                          ,.din(dinB)
                                                          ,.dout(doutB_w));
      
	  always@(posedge clk)
	  begin
	    doutA_r <= doutA_w;
		doutB_r <= doutB_w;
	  end
	  assign doutA = doutA_r;
	  assign doutB = doutB_r;
	end
	endgenerate
	
	wire[DATA_WIDTH-1:0] merged_num;
	wire out_ctrl_addr_w;
	reg ctrl_demux;
	
	serial_merge #(DATA_WIDTH,SEQ_SIZE) sm_node(.inputA(inputA)
                                               ,.inputB(inputB)
				                               ,.clk(clk)
				                               ,.rst(rst)
											   ,.ctrl_addr(out_ctrl_addr_w)
				                               ,.out(merged_num)
	);
	
	assign out_ctrl_addr = out_ctrl_addr_w;
	
	demux_1_to_2 #(DATA_WIDTH) mux_inst(.ctrl(ctrl_demux)
                                     ,.in(merged_num)
                                     ,.out0(dinA)
                                     ,.out1(dinB)
    );
	
	
	///////////////////////Control Unit///////////////////////////
    reg [4:0] state;	
	reg A_P1_empty, A_P2_empty, B_P1_empty, B_P2_empty;
	wire in_ctrl_addr_w;
	reg start_rAB;
	wire finish_wr_P1_or_P2;
	
	//////Check if P1 or P2 in A or B is all accessed or not/////	
	assign finish_wr_P1_or_P2 = ((addrBW == (1<<(ADDR_WIDTH_RAM-1)) -1 ) || (addrBW == (1<<(ADDR_WIDTH_RAM)) -1 ));
	
	always@(posedge clk or posedge rst)
	begin
	  if(rst)
	  begin
	    start_rAB <= 0;
		A_P1_empty <= 0;
		A_P2_empty <= 0;
		B_P1_empty <= 0;
		B_P2_empty <= 0;
	  end
	  else
	  begin
	    start_rAB <= finish_wr_P1_or_P2;
		
		//////Reach top of A.P1 and its element is smaller
	    A_P1_empty <= ((addrAR == ((1<<(ADDR_WIDTH_RAM-1)) - 1) ) &  (!in_ctrl_addr_w) | (addrAR == 1<<(ADDR_WIDTH_RAM-1) & addrBR < 1<<(ADDR_WIDTH_RAM-1) & (state[3] | state[4])));
	    A_P2_empty <= ((addrAR == ((1<<ADDR_WIDTH_RAM) -1 )  )  &   (!in_ctrl_addr_w) | (addrAR == 0 & addrBR >= 1<<(ADDR_WIDTH_RAM-1) & (state[1] | state[2])));
		
	    //////Reach top of B.P1 and its element is smaller
	    B_P1_empty <= ((addrBR == ((1<<(ADDR_WIDTH_RAM-1)) - 1))  & in_ctrl_addr_w | (addrBR == 1<<(ADDR_WIDTH_RAM-1) & addrAR < 1<<(ADDR_WIDTH_RAM-1) & (state[3] | state[4])));
	    B_P2_empty <= ((addrBR == ((1<<ADDR_WIDTH_RAM) -1 ) )  &  in_ctrl_addr_w | (addrBR == 0 & addrAR >= 1<<(ADDR_WIDTH_RAM-1) & (state[1] | state[2]) ));
	  end
	end
	
	//Note that the start_rAB requires to be a pulse
	//assign start_rAB = ((addrBW == (1<<(ADDR_WIDTH_RAM-1)) ) || (addrBW == (1<<(ADDR_WIDTH_RAM))));
	
	/////Stop to increase addr if A or B P1 or P2 is empty///////
	assign addrAR_w = addrAR + ( (A_P1_empty || A_P2_empty || start_rAB)	                             
	                           ? 0
							   : (!in_ctrl_addr_w));
	assign addrBR_w = addrBR + ( (B_P1_empty || B_P2_empty || start_rAB)                             
	                           ? 0
							   : in_ctrl_addr_w);
	assign in_ctrl_addr_w = (rst ? 0 : in_ctrl_addr); //(in_ctrl_addr ? in_ctrl_addr: 1'b0);
								
	assign outA = ((A_P1_empty || A_P2_empty) ? {DATA_WIDTH{1'b1}} : doutA);
	assign outB = ((B_P1_empty || B_P2_empty) ? {DATA_WIDTH{1'b1}} : doutB);
	
	//////////State bits/////////////////////
	localparam
	INITIAL =    5'b00001,
	WRITE_A_P1 = 5'b00010,
	WRITE_B_P1 = 5'b00100,
	WRITE_A_P2 = 5'b01000,
	WRITE_B_P2 = 5'b10000;
	
	always@(posedge clk or posedge rst)
	begin
	if(rst)
	  begin
	      state <= INITIAL;
	  	  start_out_r <= 0;
		  addrAR <= 0;
		  addrBR <= 0;
		  addrAW <= 0;  			 
	  	  addrBW <= 0;
	  end
	else
	  begin
		start_out <= start_out_r;
	    case(state)
	  	INITIAL:
	  	begin
	  	    if(start_in)
	  	    begin
	  		  ////////Start to Write Memory A Part 1////////////////////
	  	      state <= WRITE_A_P1;		   
	  		  addrAW <= 0;  			 
	  		  addrBW <= 0;
	  		  wenA <= 1; 
	  		  wenB <= 0;
	  		  ctrl_demux <= 0;
	  		  ////////Start to Read Memory A and Memory B Part 2/////////
	  		  addrAR <= (1<<(ADDR_WIDTH_RAM-1)); 
	  		  addrBR <= (1<<(ADDR_WIDTH_RAM-1));  
	  		  start_out_r <= 0;  //
	  	    end
	  	end
	  	WRITE_A_P1:
	  	begin
	  		addrAW <= addrAW + 1;
	  	    if(addrAW == (1<<(ADDR_WIDTH_RAM-1)) - 1)
	  		////////Start to Write Memory B Part 1//////////////
	  		begin
	  		  state <= WRITE_B_P1;
	  		  wenA <= 0;
	  		  wenB <= 1;
	  		  ctrl_demux <= 1;
	  		end
	  		////////Read Memory A and Memory B Part 2//////////			
	  		addrAR <= addrAR_w;
	  		addrBR <= addrBR_w;
	  	end
	  	WRITE_B_P1:
	  	begin
	  		addrBW <= addrBW + 1;
	  	    if(addrBW == (1<<(ADDR_WIDTH_RAM-1)) - 1)
	  		////////Start to Write Memory A Part 2//////////////
	  		begin
	  		  state <= WRITE_A_P2;
	  		  wenA <= 1;
	  		  wenB <= 0;
	  		  ctrl_demux <= 0;
			  start_out_r <= 1;
			  addrAR <= 0;
			  addrBR <= 0;
	  		end
	  		////////Read Memory A and Memory B Part 2//////////
	  		////////If A.P1.previous has been all read/////////			
	  		else
			begin
			  addrAR <= addrAR_w;
	  		  addrBR <= addrBR_w;
			end
	  	end
	  	WRITE_A_P2:
	  	begin
	  	    addrAW <= addrAW + 1;
	  	    if(addrAW == (1<<(ADDR_WIDTH_RAM))-1)
	  		////////Start to Write Memory A Part 1//////////////
	  		begin
	  		  state <= WRITE_B_P2;
	  		  wenA <= 0;
	  		  wenB <= 1;
	  		  ctrl_demux <= 1;
	  		end
	  		////////Read Memory A and Memory B Part 1/////////
	  		addrAR <= addrAR_w;
	  		addrBR <= addrBR_w;
	  	end
	  	WRITE_B_P2:
	  	begin
	  	    addrBW <= addrBW + 1;
	  	    if(addrBW == (1<<(ADDR_WIDTH_RAM))-1)
	  		////////Start to Write Memory A Part 2//////////////
	  		begin
	  		  state <= WRITE_A_P1;
	  		  wenA <= 1;
	  		  wenB <= 0;
	  		  ctrl_demux <= 0;
	  		  start_out_r <= 1;
			  //addrAR <= (1<<(ADDR_WIDTH_RAM-1));
			  //addrBR <= (1<<(ADDR_WIDTH_RAM-1));			  
	  		  addrAW <= 0;  			 
	  		  addrBW <= 0;
	  		  ////////Start to Read Memory A and Memory B Part 2/////////
	  		  addrAR <= (1<<(ADDR_WIDTH_RAM-1)); 
	  		  addrBR <= (1<<(ADDR_WIDTH_RAM-1));  
			  
	  		end
	  		////////Read Memory A and Memory B Part 1//////////
	  		////////If A.P1.previous has been all read/////////	
            else			
	  		begin
			  addrAR <= addrAR_w;
	  		  addrBR <= addrBR_w;
			end
	  	end
	  	endcase
	  end
	end
	
	//assign start_out = start_out_r;
	
endmodule




