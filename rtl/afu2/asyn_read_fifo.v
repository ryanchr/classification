// Copyright (c) 2013-2015, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.


module asyn_read_fifo #(
    parameter FIFO_WIDTH = 32,
    parameter FIFO_DEPTH_BITS = 8,
    parameter FIFO_ALMOSTFULL_THRESHOLD = 2**FIFO_DEPTH_BITS - 4,
    parameter FIFO_ALMOSTEMPTY_THRESHOLD = 2
) (
    input  wire                         clk,
    input  wire                         reset_n,
    
    input  wire                         we,              // input   write enable
    input  wire [FIFO_WIDTH - 1:0]      din,            // input   write data with configurable width
    input  wire                         re,              // input   read enable
    
    output wire [FIFO_WIDTH - 1:0]      dout,            // output  read data with configurable width    
    output reg  [FIFO_DEPTH_BITS - 1:0] count,              // output  FIFOcount
    output reg                          empty,              // output  FIFO empty
    output reg                          almostempty,              // output  FIFO almost empty
    output reg                          full,               // output  FIFO full                
    output reg                          almostfull         // output  configurable programmable full/ almost full    
);
 
    reg  [FIFO_DEPTH_BITS - 1:0]        rp;
    reg  [FIFO_DEPTH_BITS - 1:0]        rp_next;
    reg  [FIFO_DEPTH_BITS - 1:0]        wp;
    wire  [FIFO_DEPTH_BITS - 1:0]       raddr;
    reg pass_through;
    reg [FIFO_WIDTH - 1:0] din_reg;
    wire [FIFO_WIDTH - 1:0] fifo_dout;

    spl_sdp_mem #(.DATA_WIDTH(FIFO_WIDTH),
                  .ADDR_WIDTH(FIFO_DEPTH_BITS)
                 ) fifo (
                  .clk(clk),
                  .we(we),
                  .re(1'b1),
                  .raddr(raddr),
                  .waddr(wp),
                  .din(din),
                  .dout(fifo_dout)
                 );

    // output logic
    assign raddr = (re) ? rp_next : rp;

    always@(posedge clk) begin
        din_reg <= din;
        if (~reset_n) begin
            pass_through <= 0;
        end else if ((we & empty) | (we & re & count == 1)) begin
            pass_through <= 1;
        end else begin
            pass_through <= 0;
        end
    end

    assign dout = (pass_through == 1'b1) ? din_reg : fifo_dout;
        
    always @(posedge clk) begin
        if (~reset_n) begin
            empty <= 1'b1;
            almostempty <= 1'b1;
            full <= 1'b0;
            almostfull <= 1'b0;
            count <= 0;            
            rp <= 0;
            rp_next <= 1;
            wp <= 0;
            
        end
        
        else begin
            case ({we, re})
                // write and read at same time
                2'b11 : begin
                    wp <= wp + 1'b1;
//                    mem[wp] <= din;
                    
                    rp <= rp + 1'b1;

                    rp_next <= rp_next + 1'b1;
//                    dout <= mem[rp];
                end
                
                // write only
                2'b10 : begin
                    if (full) begin                                                
                                           
                    end
                    
                    else begin
                        wp <= wp + 1'b1;
//                        mem[wp] <= din;
                        count <= count + 1'b1;

                        empty <= 1'b0;

                        if (count == (FIFO_ALMOSTEMPTY_THRESHOLD-1))
                            almostempty <= 1'b0;
                            
                        if (count == (2**FIFO_DEPTH_BITS-1))
                            full <= 1'b1;

                        if (count == (FIFO_ALMOSTFULL_THRESHOLD-1))
                            almostfull <= 1'b1;
                    end
                end
                
                // read only
                2'b01 : begin
                    if (empty) begin                                               
                        
                    end
                    
                    else begin
                        rp <= rp + 1'b1;

                        rp_next <= rp_next + 1'b1;
//                        dout <= mem[rp];
                        count <= count - 1'b1;                    
                        full <= 0;
                    
                        if (count == FIFO_ALMOSTFULL_THRESHOLD)
                            almostfull <= 1'b0;
                                            
                        if (count == 1)
                            empty <= 1'b1;
                            
                        if (count == FIFO_ALMOSTEMPTY_THRESHOLD)
                            almostempty <= 1'b1;
                                             
                    end 
                end
                
                default : begin

                end
            endcase
        end
    end

    
    
endmodule

