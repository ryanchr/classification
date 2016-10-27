`timescale 1ns / 1ps


module tree_start_level(
    Key_in, 
    Index_in,
    clk,
    rst,
    Index_out,
	Key_out,
	valid_in,
    valid_out
);
//`include "common_func.v"
parameter      level = 12;				                    // which level 
parameter      total_level = 12;				            // which level 
//parameter    ram_init_data = "tree_data_0";
//localparam   no_nodes = power2(level);		        // how many nodes 

parameter Data_out = 16;

input   [15:0]           Key_in;
input   [0:0]            Index_in;
input                    clk;
input                    rst;
input                    valid_in;

output  reg[1:0]        Index_out;
output  reg[15:0]       Key_out;
output  reg             valid_out;

//wire [15:0]        Data_out;

// generate
	// if(level>10) begin
		// tree_bram #(.level(level),.init_file(ram_init_data)) bram (
		// .Addr_in(Index_in),
		// .clk(clk),
		// .rst(rst),
		// .Data_out(Data_out)
		// );
	// end else begin
		// tree_dram #(.level(level),.init_file(ram_init_data)) dram (
        // .Addr_in(Index_in),
        // .clk(clk),
        // .rst(rst),
        // .Data_out(Data_out)
        // );
	// end
// endgenerate
always@(posedge clk)
begin
    if(rst)
	begin
	    Key_out <= 0;
		Index_out <= 0;
		valid_out <= 0;
	end
	else
	begin
	    Key_out <= Key_in;
        Index_out <= (Key_in < Data_out) ? Index_in*2+1: Index_in*2+2;
        valid_out <= valid_in;
	end
end


endmodule


