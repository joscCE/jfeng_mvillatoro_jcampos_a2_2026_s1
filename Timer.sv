module Timer #(parameter COUNTER = 64)(
    input logic clk,
    input logic rst,
    input logic control,
    output logic [COUNTER-1:0] count
);

logic [COUNTER-1:0] counter;

assign count = counter;


always_ff @(posedge clk or posedge rst) begin
    if (rst) begin 
        counter <= '0;
    end
    else if(control) begin 
        counter <= counter + 1;
    end
end

endmodule