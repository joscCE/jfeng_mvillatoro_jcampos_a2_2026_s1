module clk_div (
    input logic clk,
    input logic rst_active,
    output logic clk25
);

    always_ff @(posedge clk or posedge rst_active) begin
        if (rst_active)
            clk25 <= 0;
        else
            clk25 <= ~clk25;
    end

endmodule