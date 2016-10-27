`timescale 1ns / 1ps

module tree_dram(
	Addr_in,	// R
	clk,
	rst,
	Data_out		
	);
//`include "common_func.v"
parameter level = 4;
parameter init_file = "input.hex";
localparam DEPTH =2**level;

input [level-1:0] Addr_in;
input clk;
input rst;
output reg [15:0] Data_out;

(* ram_style="distributed" *)  reg [15:0] ram [DEPTH-1:0];
//initial $readmemh("ram.init", ram, 0, DEPTH-1);


always @(posedge clk) begin
    if(rst==1) begin
	   Data_out <= 0;
	end else begin   
	   Data_out <= ram[Addr_in];
	end   
end    


reg [15:0] data[DEPTH-1:0];
//reg [15:0] data_o[DEPTH-1:0];
integer i;
initial
begin
    $readmemh(init_file, data);
    for(i=0; i<DEPTH; i=i+1)
	begin
	    //data_o[i] = i;
        ram[i] = data[i];
	end
	//$writememh("output.hex",data_o);
end					

					
endmodule