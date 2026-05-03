module Top (
    input  logic clk,
    input  logic reset,
    input  logic protocol_sel
);

    // Top minimo temp
    logic unused_inputs;
    assign unused_inputs = clk ^ reset ^ protocol_sel;

endmodule

