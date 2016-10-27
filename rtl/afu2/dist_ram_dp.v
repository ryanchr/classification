// self-defined bram-dp

module dist_ram_dp #(parameter DATA_WIDTH=32, ADDR_WIDTH_RAM=7) (
    input clk,
    input wen,
    input [ADDR_WIDTH_RAM-1:0] addrR,
    input [ADDR_WIDTH_RAM-1:0] addrW,
    input [DATA_WIDTH-1:0] din,
    output [DATA_WIDTH-1:0] dout
    );

    localparam ARRAY_SIZE = 1 << ADDR_WIDTH_RAM;
    reg [DATA_WIDTH-1:0] ram [0:ARRAY_SIZE-1];

    //read and write
    always@(posedge clk)
    begin
        //synchronous write
        if (wen)
        begin
            ram[addrW] <= din;
        end
    end

    assign dout = ram[addrR];

endmodule
