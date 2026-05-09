module deco_BDS (
    input  logic [9:0] Num,
    output logic [3:0] numb1,
    output logic [3:0] numb2,
    output logic [3:0] numb3
);

always_comb begin
    // Si hay valores indefinidos en Num, salida segura en 0
    if (^Num === 1'bx || ^Num === 1'bz) begin
        numb1 = 4'd0;
        numb2 = 4'd0;
        numb3 = 4'd0;
    end else begin
        numb3 = Num / 7'd100;
        numb1 = Num % 4'd10;
        numb2 = (Num / 7'd10) % 4'd10;
    end
end

endmodule