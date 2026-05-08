module Counter #(parameter COUNTER = 64)(
    input logic clk,
    input logic rst,
    input logic control,
    output logic [COUNTER-1:0] count
);

logic [COUNTER-1:0] counter;
logic last_level;

assign count = counter;

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin 
        counter    <= '0;
        last_level <= 1'b0;
    end
    else begin 
        // detectar flanco de subida
        if (control && !last_level) begin
            counter <= counter + 1;
        end

        // SIEMPRE actualizar el estado previo
        last_level <= control;
    end
end

endmodule