module CounterV #(parameter N = 10)(
    input logic clk,
    input logic rst,
    input logic en,
    input logic mode,                
    output logic [N-1:0] Q
);
    always_ff @(negedge clk or posedge rst) begin
        if (rst)
            Q <= '0;                
        else if (en) begin
            if (mode)
                Q <= Q + 1'b1;
            else
                Q <= Q - 1'b1;
        end
    end

endmodule