
//This file defines the afu_user behavior in HARP system

module afu_user # (
    parameter CORE_NUM_BITS = 3,      // number of bit to represent mergesort core, value can only be 1, 2, 3
    parameter BLOCK_SIZE_BITS = 8,     // block size bits, 0 means only one cacheline per block
    parameter INPUT_FIFO_DEPTH_BITS = 5,    //8 entries for input FIFO
    //32 entries for output FIFO. The output fifo should never be full, otherwise, would cause data lost. BIG trouble!
    parameter OUTPUT_FIFO_DEPTH_BITS = 5,
	parameter CORE_SET_BITS = 3      // number of inputs for merge sorter
) (
    input clk,    // Clock
    input reset_n,  // Asynchronous reset active low
    input [31:0] ctx_length,   // number of cachelines
    // fifo specific
    input [511:0] rxq_din,  // request input from CPU MM
    input rxq_we, // if the data is valid, then write to the fifo
    // input fifo interfaces deal with outer afu and qpi
    input rxq_re,   // if there is data in the output fifo, afu should assert this signal
    output [511:0] rxq_dout,   // output fifo dout, data which has been sorted
    output rxq_output_empty,    //used to make decision whether to make write request
    output rxq_output_almost_empty,
    output rxq_input_full,      // used to make decision whether to make read request
    output [INPUT_FIFO_DEPTH_BITS - 1:0] rxq_input_count,  // it seems that in sample fifo afu, it is not used.
    output rxq_input_almostfull
);
    localparam BLOCK_NUM = 2**BLOCK_SIZE_BITS;
    localparam CORE_NUM = 2**CORE_NUM_BITS;
	localparam NUM_IN  = 2**CORE_SET_BITS;
	localparam REST_BITS = 512 - CORE_NUM*16 - CORE_NUM - NUM_IN*0;

	localparam TREE_LEVEL = 10;
    wire fifo_input_re;
    wire [511:0] rxq_unsorted_data;
    wire rxq_input_empty;

	reg reset_n_r;
	
	always@(posedge clk)
	begin
	    reset_n_r <= reset_n;
	end

    asyn_read_fifo #(.FIFO_WIDTH(512),
                     .FIFO_DEPTH_BITS(INPUT_FIFO_DEPTH_BITS),       // transfer size 1 -> 32 entries
                     .FIFO_ALMOSTFULL_THRESHOLD(2**(INPUT_FIFO_DEPTH_BITS)-4),
                     .FIFO_ALMOSTEMPTY_THRESHOLD(2)
                    ) input_fifo(
                .clk                (clk),
                .reset_n            (reset_n_r),
                .din                (rxq_din),
                .we                 (rxq_we),
                .re                 (fifo_input_re),
                .dout               (rxq_unsorted_data),
                .empty              (rxq_input_empty),
                .full               (rxq_input_full),
                .count              (rxq_input_count),
                .almostempty        (),
                .almostfull         (rxq_input_almostfull)
            );

    // reg [31:0] inputA [CORE_NUM-1:0];
    // reg [31:0] inputB [CORE_NUM-1:0];
	reg [15:0]            inKey [CORE_NUM-1:0];
	reg [0:0]             inIdx [CORE_NUM-1:0];
	wire [TREE_LEVEL-1:0] outIdx [CORE_NUM-1:0];
	reg [CORE_NUM-1:0]    valid_in ;
	
	reg [15:0]           inSet [NUM_IN-1:0];
	reg [REST_BITS-1:0]  reservedBits;
	
    reg [31:0] cacheline_count;

	//localparam LOOKUP = 2'b00;
    //localparam LOOKUPMERGE = 2'b01;

    reg[1:0] state;
    reg stall;

	//Read e
    //assign fifo_input_re = (~rxq_input_empty & ((state == LOOKUP) || (state == LOOKUPMERGE))) 
	assign fifo_input_re = (~rxq_input_empty & (~reset_n_r)) 
	                       ? 1'b1 : 1'b0;

	//integer idx_core;
	//integer idx_core2;
	/******Updated by Ren*********/
    always @ (posedge clk) begin
        if (~reset_n_r) begin
            //state <= LOOKUP;
            stall <= 1;
            cacheline_count <= 0;
        end else begin
            //case(state)
           //     LOOKUP: begin
                    if (~rxq_input_empty) begin
                        stall <= 0;
                        //state <= LOOKUP;
                        
						//for(idx_core = 0; idx_core < CORE_NUM; idx_core = idx_core + 1)
						//begin: CORE_INKEY
						inKey[0] <= rxq_unsorted_data[15:0];
						inKey[1] <= rxq_unsorted_data[31:16];
						inKey[2] <= rxq_unsorted_data[47:32];
						inKey[3] <= rxq_unsorted_data[63:48];
						inKey[4] <= rxq_unsorted_data[79:64];
						inKey[5] <= rxq_unsorted_data[95:80];
						inKey[6] <= rxq_unsorted_data[111:96];
						inKey[7] <= rxq_unsorted_data[127:112];
						//end
								
						//for(idx_core2 = 0; idx_core2 < CORE_NUM; idx_core2 = idx_core2 + 1)
						//begin: CORE_INIDX
						//inKey[idx_core2] <= rxq_unsorted_data[CORE_NUM*16+idx_core2];
						inIdx[0] <=  rxq_unsorted_data[128];
						inIdx[1] <=  rxq_unsorted_data[129];
						inIdx[2] <=  rxq_unsorted_data[130];
						inIdx[3] <=  rxq_unsorted_data[131];
						inIdx[4] <=  rxq_unsorted_data[132];
						inIdx[5] <=  rxq_unsorted_data[133];
						inIdx[6] <=  rxq_unsorted_data[134];
						inIdx[7] <=  rxq_unsorted_data[135];
						//end	
                        valid_in <= {CORE_NUM{1'b1}};	
						
						reservedBits <= rxq_unsorted_data[511:CORE_NUM*17];   //needs update
						
                        cacheline_count <= cacheline_count + 1'b1;	
						
                    end else if (cacheline_count == ctx_length) begin
                        stall <= 0;
						//valid_in = {CORE_NUM{1'b0}};
						//state <= WAIT;
                    end else begin
                        stall <= 1;
						//valid_in = {CORE_NUM{1'b0}};
						//state <= WAIT;
                    end
                //end
                // LOOKUPMERGE: begin                    
                     // state <= WAIT;
                // end
           // endcase
        end
    end
   
    // localparam IN_CTRL_ADDR_COUNT_BIT = $clog2(16*BLOCK_NUM);
    // reg in_ctrl_addr;
    // reg [IN_CTRL_ADDR_COUNT_BIT-1:0] in_ctrl_addr_count;
    
	
    // always@(posedge clk) begin
        // if (~reset_n) begin
            // in_ctrl_addr <= 0;
            // in_ctrl_addr_count <= 0;
        // end
        // else if (start_out[0] & ~stall) begin
            // in_ctrl_addr_count <= in_ctrl_addr_count + 1'b1;
        // end
        // if (in_ctrl_addr_count == 16*BLOCK_NUM-1) begin
            // in_ctrl_addr <= ~in_ctrl_addr;
        // end
    // end

    // wire [31:0] outA [CORE_NUM-1:0];
    // wire [31:0] outB [CORE_NUM-1:0];
    //wire [31:0] serial_merge_out [CORE_NUM-1:0];
    wire [CORE_NUM-1:0] valid_out;
	
    genvar i;
    generate
        // for (i=0; i<CORE_NUM; i=i+1) begin:MSA
            // serial_merge_top #(.BLOCK_NUM(BLOCK_NUM)) msa (
                             // .inputA(inputA[i]),
                             // .inputB(inputB[i]),
                             // .start_in(1'b1),
                             // .start_out(start_out[i]),
                             // .clk(clk & ~stall),
                             // .rst(~reset_n),
                             // .outA(outA[i]),
                             // .outB(outB[i]),
                             // .in_ctrl_addr(in_ctrl_addr),
                             // .out_ctrl_addr()
                             // );
            // assign serial_merge_out[i] = (in_ctrl_addr == 1'b0) ? outA[i] : outB[i];
        // end
		for (i=0; i<CORE_NUM; i=i+1) begin:TREE
		    tree #(.total_level(TREE_LEVEL)) tree_inst(
		                                     .clk(clk & ~stall),
											 .rst(~reset_n_r),
											 .Key_in(inKey[i]),
											 .Index_in(inIdx[i]),
											 .Index_out(outIdx[i]),
											 .valid_in(valid_in[i]),
											 .valid_out(valid_out[i])
											 );
		end
    endgenerate

    localparam OUTFIRST = 1'b0;
    localparam OUTSECOND = 1'b1;
    reg out_state;
    // reg [31:0] out_first [CORE_NUM-1:0];
    // reg [31:0] out_second [CORE_NUM-1:0];
	
	//reg [CORE_NUM-1:0] valid_out_r;
	reg [15:0] outIdx_r [CORE_NUM-1:0];
	reg [15:0] outIdx_next_r [CORE_NUM-1:0];
	localparam HIGHBITSNUM = 16-TREE_LEVEL;
	
    // output
    wire [511:0] rxq_output_din;
    reg rxq_output_we;
    wire rxq_output_full;
    reg [31:0] cacheline_count_out;
	reg all_cl_out;
	
	//output register
	// reg [TREE_LEVEL-1:0] outIdx_r_tmp [CORE_NUM-1:0];
	// reg [CORE_NUM-1:0]   valid_out_r;
	
	// always@(posedge clk) begin
	    // valid_out_r <= valid_out;
	// end
	
	//
	// genvar j;
	// generate
	    // for(j = 0; j < CORE_NUM; j = j + 1)
		// begin: OUTIDXREG
	        // always@(posedge clk) begin
		        // outIdx_r_tmp [j] <= {{HIGHBITSNUM{1'b0}},outIdx[j]};
		    // end
		// end
	// endgenerate
	
	
	always@(posedge clk) begin
	    if (~reset_n_r) begin
            all_cl_out <= 1'b0;
			//valid_out_r <= {CORE_NUM{1'b0}};
        end else begin
		    all_cl_out <= (cacheline_count_out >= ctx_length-1)? 1'b1: 1'b0;
			//valid_out_r <= valid_out;
		end
	end

	//integer idx_o;
    always @ (posedge clk) begin
        if (~reset_n_r) begin
            out_state <= OUTFIRST;
            rxq_output_we <= 1'b0;
            cacheline_count_out <= 0;
        end else begin
            case (out_state)
                OUTFIRST: begin
                    if (valid_out[0] & ~stall & ~rxq_output_full & ~all_cl_out) begin
                        out_state <= OUTSECOND;
						
						//for(idx_o = 0; idx_o < CORE_NUM; idx_o = idx_o + 1)
						//begin: CORE_OUTIDX
						//outIdx_r[idx_o] <= {{HIGHBITSNUM{1'b0}},outIdx[idx_o]};
						outIdx_r[0] <=  {{HIGHBITSNUM{1'b0}},outIdx[0]};
                        outIdx_r[1] <=  {{HIGHBITSNUM{1'b0}},outIdx[1]};
                        outIdx_r[2] <=  {{HIGHBITSNUM{1'b0}},outIdx[2]};
                        outIdx_r[3] <=  {{HIGHBITSNUM{1'b0}},outIdx[3]};
                        outIdx_r[4] <=  {{HIGHBITSNUM{1'b0}},outIdx[4]};
                        outIdx_r[5] <=  {{HIGHBITSNUM{1'b0}},outIdx[5]};
                        outIdx_r[6] <=  {{HIGHBITSNUM{1'b0}},outIdx[6]};
                        outIdx_r[7] <=  {{HIGHBITSNUM{1'b0}},outIdx[7]};
						//end
						
                    end
                    rxq_output_we <= 1'b0;
                end
                OUTSECOND: begin
                    if (~stall & ~rxq_output_full) begin
                        out_state <= OUTFIRST;
						
						
						//for(idx_o = 0; idx_o < CORE_NUM; idx_o = idx_o + 1)
						//begin: CORE_OUTIDX_NEXT
						//    outIdx_next_r[idx_o] <= {{HIGHBITSNUM{1'b0}},outIdx[idx_o]};
						//end
						outIdx_next_r[0] <=  {{HIGHBITSNUM{1'b0}},outIdx[0]};
                        outIdx_next_r[1] <=  {{HIGHBITSNUM{1'b0}},outIdx[1]};
                        outIdx_next_r[2] <=  {{HIGHBITSNUM{1'b0}},outIdx[2]};
                        outIdx_next_r[3] <=  {{HIGHBITSNUM{1'b0}},outIdx[3]};
                        outIdx_next_r[4] <=  {{HIGHBITSNUM{1'b0}},outIdx[4]};
                        outIdx_next_r[5] <=  {{HIGHBITSNUM{1'b0}},outIdx[5]};
                        outIdx_next_r[6] <=  {{HIGHBITSNUM{1'b0}},outIdx[6]};
                        outIdx_next_r[7] <=  {{HIGHBITSNUM{1'b0}},outIdx[7]};
						
						
                        rxq_output_we <= 1'b1;
                        cacheline_count_out <= cacheline_count_out + 1'b1;
                    end
                end
            endcase
        end
    end 
	
	//little endian
    assign rxq_output_din =  {
							  16'h1313, 16'h1313, 16'h1313, 16'h1313, 
							  16'h1313, 16'h1313, 16'h1313, 16'h1313,
							  16'h1313, 16'h1313, 16'h1313, 16'h1313,
							  16'h1313, 16'h1313, 16'h1313, 16'h1313,
                              outIdx_next_r[7], outIdx_next_r[6], outIdx_next_r[5], outIdx_next_r[4], 
                              outIdx_next_r[3], outIdx_next_r[2], outIdx_next_r[1], outIdx_next_r[0], 
							  outIdx_r[7], outIdx_r[6], outIdx_r[5],  outIdx_r[4], 
                              outIdx_r[3], outIdx_r[2], outIdx_r[1],  outIdx_r[0]		  
							  } ;
    // output buffer
    

    syn_read_fifo #(.FIFO_WIDTH(512),
                       .FIFO_DEPTH_BITS(OUTPUT_FIFO_DEPTH_BITS),       // transfer size 1 -> 32 entries
                       .FIFO_ALMOSTFULL_THRESHOLD(2**(OUTPUT_FIFO_DEPTH_BITS)-4),
                       .FIFO_ALMOSTEMPTY_THRESHOLD(2)
                      ) output_fifo(
                .clk                (clk),
                .reset_n            (reset_n_r),
                .din                (rxq_output_din),
                .we                 (rxq_output_we),
                .re                 (rxq_re),
                .dout               (rxq_dout),
                .empty              (rxq_output_empty),
                .almostempty        (rxq_output_almost_empty),
                .full               (rxq_output_full),
                .count              (),
                .almostfull         ()
            );

endmodule
