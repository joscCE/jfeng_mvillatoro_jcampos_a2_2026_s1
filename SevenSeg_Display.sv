module SevenSeg_Display #(
    parameter logic [9:0] x = 0,
    parameter logic [9:0] y = 0
)(
    input  logic [9:0] Q_X, Q_Y,
    input logic [3:0] num,
    output logic visible
);
    logic [6:0] segments;
    logic [6:0] seg_en;
    logic [6:0] seg_area;

    // Codificación típica de display de 7 segmentos (A-G)
    always_comb begin
        case (num)
        4'd0: segments = 7'b1111110;
        4'd1: segments = 7'b0110000;
        4'd2: segments = 7'b1101101;
        4'd3: segments = 7'b1111001;
        4'd4: segments = 7'b0110011;
        4'd5: segments = 7'b1011011;
        4'd6: segments = 7'b1011111;
        4'd7: segments = 7'b1110000;
        4'd8: segments = 7'b1111111;
        4'd9: segments = 7'b1111011;
        default: segments = 7'b0000000; // Apagado
        endcase
    end

    // Instancias de segmentos (A a G)
    genvar i;
    generate
        for (i = 0; i < 7; i++) begin : seg_gen
            assign seg_en[i] = segments[i];
        end
    endgenerate

  // Segmento A (horizontal arriba)
    // Segmento A
    Square_Area #(
        .x0(x+2),
        .x1(x+14),
        .y0(y+0),
        .y1(y+3),
        .corn(1)
    ) segA (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[6])
    );

    // Segmento B
    Square_Area #(
        .x0(x+14),
        .x1(x+17),
        .y0(y+3),
        .y1(y+14),
        .corn(1)
    ) segB (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[5])
    );

    // Segmento C
    Square_Area #(
        .x0(x+14),
        .x1(x+17),
        .y0(y+16),
        .y1(y+27),
        .corn(1)
    ) segC (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[4])
    );

    // Segmento D
    Square_Area #(
        .x0(x+2),
        .x1(x+14),
        .y0(y+27),
        .y1(y+30),
        .corn(1)
    ) segD (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[3])
    );

    // Segmento E
    Square_Area #(
        .x0(x-1),
        .x1(x+2),
        .y0(y+16),
        .y1(y+27),
        .corn(1)
    ) segE (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[2])
    );

    // Segmento F
    Square_Area #(
        .x0(x-1),
        .x1(x+2),
        .y0(y+3),
        .y1(y+14),
        .corn(1)
    ) segF (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[1])
    );

    // Segmento G
    Square_Area #(
        .x0(x+2),
        .x1(x+14),
        .y0(y+14),
        .y1(y+17),
        .corn(1)
    ) segG (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(seg_area[0])
    );

    // Visibilidad final si está encendido y colisiona
    assign visible = |(seg_en & seg_area);

endmodule