module deco_BDS_4 (

    input  logic [13:0] Num,

    output logic [3:0] numb0,
    output logic [3:0] numb1,
    output logic [3:0] numb2,
    output logic [3:0] numb3
);
    logic [13:0] value;
    always_comb begin
        //------------------------------------------------
        // PROTECCION CONTRA X/Z
        //------------------------------------------------

        if (^Num === 1'bx || ^Num === 1'bz) begin

            numb0 = 4'd0;
            numb1 = 4'd0;
            numb2 = 4'd0;
            numb3 = 4'd0;

        end

        //------------------------------------------------
        // CONVERSION DECIMAL 4 DIGITOS
        //------------------------------------------------

        else begin

            value = Num;

            // unidades
            numb0 = value % 10;
            value = value / 10;

            // decenas
            numb1 = value % 10;
            value = value / 10;

            // centenas
            numb2 = value % 10;
            value = value / 10;

            // miles
            numb3 = value % 10;

        end

    end

endmodule