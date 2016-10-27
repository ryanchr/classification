`timescale 1ns / 1ps

// dual port ram, both ports for read

module tree_bram(
	Addr_in,	// R
	clk,
	//rst,
	Data_out		
	);
//`include "common_func.v"
parameter level = 4;
parameter init_file = "input.hex";
localparam DEPTH =2**level;
parameter DATA_WIDTH = 16;

input [level-1:0] Addr_in;
input clk;
//input rst;
output [15:0] Data_out;

//(* ram_style="block" *) reg [15:0] ram [DEPTH-1:0];

 bram_dp #(DATA_WIDTH,level,init_file) output_bufferB(.clk(clk)
                                                     ,.wen(1'b0)
                                                     ,.en(1'b1)
                                                     ,.addrR(Addr_in)
													 ,.addrW({level{1'b0}})
                                                     ,.din({DATA_WIDTH{1'b0}})
                                                     ,.dout(Data_out));
													 

//initial $readmemh("ram.init", ram, 0, DEPTH-1);

		
endmodule