// self-defined bram-dp

module bram_dp #(parameter DATA_WIDTH=32, ADDR_WIDTH_RAM=7, init_file = "input.hex") (
    input clk,
    input wen,
    input en,
    input [ADDR_WIDTH_RAM-1:0] addrR,
    input [ADDR_WIDTH_RAM-1:0] addrW,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
    );

    localparam ARRAY_SIZE = 1 << ADDR_WIDTH_RAM;
    reg [DATA_WIDTH-1:0] ram [0:ARRAY_SIZE-1];
	localparam MAX_VAL = 1<<12-1;

    //read and write
    always@(posedge clk)
    begin
        //synchronous write
        if (wen)
        begin
            ram[addrW] <= din;
        end
        //synchronous read
        if (en)
        begin
            dout <= ram[addrR];
        end
    end

	
    reg [15:0] data[ARRAY_SIZE-1:0];
    //reg [15:0] data_o[DEPTH-1:0];
    integer i;
    initial
    begin
        $readmemh(init_file, data);
        for(i=0; i<ARRAY_SIZE; i=i+1)
    	begin
    	    //data_o[i] = i;
            ram[i] = data[i];
    		//$display("d:%h",i,data[i]);
			//ram[i] = $random() % MAX_VAL;
    	end
    	//$writememh("output.hex",data_o);
    end			
endmodule
