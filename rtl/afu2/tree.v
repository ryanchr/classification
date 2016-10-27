`timescale 1ns / 1ps

module tree(
    clk,
    rst,
    Key_in,
    Index_in,
    Index_out,
    valid_in,
    valid_out
);

parameter                   total_level = 12;
parameter                   ram_init_data = "/import/usc/home/renchen/ren_ancs/rtl/afu2/tree_data_0";

input                         clk;
input                         rst;
input    [15:0]               Key_in;
input    [0:0]                Index_in;
output   [total_level-1:0]    Index_out; 
input                         valid_in;
output                        valid_out;
 
wire    [15:0] key_wire                     [total_level-2:0];
wire    [total_level-1:0]     index_wire    [total_level-2:0];

wire                         valid_out_tmp [total_level-2:0];

generate
    tree_start_level #(.level(0)
	                  ,.total_level(total_level)) 
    start_level (
        .Key_in(Key_in), 
        .Index_in(Index_in),
        .clk(clk),
        .rst(rst),
        .Index_out(index_wire[0]),
        .Key_out(key_wire[0]),
        .valid_in(valid_in),
        .valid_out(valid_out_tmp[0]) 
    );
endgenerate


genvar numstg,tag;
generate
    for(numstg=1; numstg < total_level-1; numstg = numstg+1)
    begin: elements
        tree_level #(.level(numstg)
		            ,.total_level(total_level)
					,.ram_init_data(ram_init_data+((numstg>9)? (numstg + 39): numstg-1))
					)
        tree_stage (
                .Key_in(key_wire[numstg-1]), 
                .Index_in(index_wire[numstg-1]),
                .clk(clk),
                .rst(rst),
                .Index_out(index_wire[numstg]),
                .Key_out(key_wire[numstg]),
                .valid_in(valid_out_tmp[numstg-1]),
                .valid_out(valid_out_tmp[numstg]) 
        );
    end
	
endgenerate

generate
	tree_last_level #(.level(total_level-1)
	                 ,.total_level(total_level)
					 ,.ram_init_data(ram_init_data+((total_level>10)? (total_level + 38): total_level-2))) 
    last_level (
        .Key_in(key_wire[total_level-2]), 
        .Index_in(index_wire[total_level-2]),
        .clk(clk),
        .rst(rst),
        .Index_out(Index_out),
        .valid_in(valid_out_tmp[total_level-2]),
        .valid_out(valid_out) 
    );
endgenerate

endmodule
