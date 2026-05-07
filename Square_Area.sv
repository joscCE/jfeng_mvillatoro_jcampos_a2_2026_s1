module Square_Area #(
    parameter int x0 = 100, x1 = 200,
    parameter int y0 = 100, y1 = 200,
    parameter int corn = 10
)(
    input  logic [9:0] Q_X, Q_Y,
    output logic Aden
);

logic cor_1, cor_2, cor_3, cor_4;

always_comb begin
    // Esquina superior izquierda
    cor_1 = (Q_X > x0 && Q_X < (x0 + corn)) && (Q_Y > y0 && Q_Y < (y0 + corn));

    // Esquina superior derecha
    cor_2 = (Q_X > (x1 - corn) && Q_X < x1) && (Q_Y > y0 && Q_Y < (y0 + corn));

    // Esquina inferior izquierda
    cor_3 = (Q_X > x0 && Q_X < (x0 + corn)) && (Q_Y > (y1 - corn) && Q_Y < y1);

    // Esquina inferior derecha
    cor_4 = (Q_X > (x1 - corn) && Q_X < x1) && (Q_Y > (y1 - corn) && Q_Y < y1);

    // Área completa sin las esquinas
    Aden = (Q_X > x0 && Q_X < x1) &&
           (Q_Y > y0 && Q_Y < y1) &&
           !cor_1 && !cor_2 && !cor_3 && !cor_4;
end

endmodule