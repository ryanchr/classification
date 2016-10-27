`timescale 1ns / 1ps


module tree_last_level(
    Key_in, 
    Index_in,
    clk,
    rst,
    Index_out,
    valid_in,
    valid_out
);
//`include "common_func.v"
parameter  level = 12;				                    // which level 
parameter  total_level = 12;				            // which level 
parameter  ram_init_data = "/import/usc/home/renchen/ren_ancs/rtl/afu2/tree_data_0";
localparam   no_nodes = 2**(level);		                // how many nodes 

input   [15:0]                  Key_in;
input   [total_level-2:0]       Index_in;
input                           clk;
input                           rst;
input                           valid_in;

output  reg[total_level-1:0]    Index_out;
output  reg                     valid_out;

reg[15:0]                       Key_in_tmp;
reg[level-1:0]                  Index_in_tmp1;
reg[level-1:0]                  Index_in_tmp2;
reg                             valid_in_tmp;

wire [15:0]        Data_out;

generate
	if(level>0) begin
		tree_bram #(.level(level),.init_file(ram_init_data)) bram (
		.Addr_in(Index_in),
		.clk(clk),
		//.rst(rst),
		.Data_out(Data_out)
		);
	end else begin
		tree_dram #(.level(level),.init_file(ram_init_data)) dram (
        .Addr_in(Index_in),
        .clk(clk),
        .rst(rst),
        .Data_out(Data_out)
        );
	end
endgenerate

//assign Index_out=(Key_in<Data_out) ? Index_in*2+1: Index_in*2+2;


always@(posedge clk)
begin
    if(rst)
	begin
	    Key_in_tmp <= 0;
        valid_in_tmp <= 0; 
        Index_in_tmp1 <= 0;
		Index_in_tmp2 <= 0;
		Index_out <= 0;
		valid_out <= 0;
	end
	else
	begin
	    Key_in_tmp <= Key_in;
	    valid_in_tmp <= valid_in;
	    Index_in_tmp1 <= Index_in*2+1;
		Index_in_tmp2 <= (Index_in+1)*2;
        Index_out <= (Key_in_tmp < Data_out) ? Index_in_tmp1: Index_in_tmp2;
        valid_out <= valid_in_tmp;
	end
end


endmodule


