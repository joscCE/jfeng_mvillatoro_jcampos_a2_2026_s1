module Vga_Controller #(
   parameter N=8,

   H_Va = 10'd640,
   H_FP = 10'd16,
   H_SycP = 10'd96,
   H_BckP = 10'd48,
   H_Total = H_Va + H_FP + H_SycP + H_BckP,

   V_Va = 10'd480,
   V_FP = 10'd10,
   V_SycP = 10'd2,
   V_BckP = 10'd33,
   V_Total = V_Va + V_FP + V_SycP + V_BckP

)(
    input logic clk,
    input logic rst,

    output logic Hs,
    output logic Vs,

    output logic VGA_Blank,
    output logic VGA_Sync_N,

    output logic [9:0] Q_X,
    output logic [9:0] Q_Y,

    output logic [7:0] R,
    output logic [7:0] G,
    output logic [7:0] B,

    input logic [63:0] count_timer [3:0],
    input logic [63:0] count_inv   [3:0]
);

    //====================================================
    // VGA SYNC
    //====================================================

    logic [9:0] Q_x, Q_y, D_x, D_y;
    logic rstx, rsty;

    CounterV count_y(
        clk,
        (rstx & rsty)|rst,
        rstx,
        1'b1,
        D_y
    );

    CounterV count_x(
        clk,
        rstx|rst,
        1'b1,
        1'b1,
        D_x
    );

    Register reg_x(
        clk,
        rst,
        D_x,
        1'b1,
        Q_x
    );

    Register reg_y(
        clk,
        rst,
        D_y,
        1'b1,
        Q_y
    );

    Comparator cmp_x(Q_x, 10'd800, rstx);
    Comparator cmp_y(Q_y, 10'd525, rsty);

    assign Hs = ~(Q_x >= 656 && Q_x < 752);
    assign Vs = ~(Q_y >= 490 && Q_y < 492);

    assign VGA_Sync_N = 1'b1;

    assign VGA_Blank =
        (Q_x < 640) &&
        (Q_y < 480);

    assign Q_X = Q_x;
    assign Q_Y = Q_y;

    //====================================================
    // DISPLAY WIRES
    //====================================================

    logic [15:0] v_inv;
    logic [15:0] v_stall;

    //====================================================
    // DIGIT GENERATION
    //====================================================

    genvar i;

    generate

        for (i = 0; i < 4; i++) begin : gen_decos

            //------------------------------------------------
            // DIGITS
            //------------------------------------------------

            logic [3:0] d0_i, d1_i, d2_i, d3_i;
            logic [3:0] d0_s, d1_s, d2_s, d3_s;

            //------------------------------------------------
            // DECODERS
            //------------------------------------------------

            deco_BDS_4 deco_i (
                .Num(count_inv[i][13:0]),

                .numb0(d0_i),
                .numb1(d1_i),
                .numb2(d2_i),
                .numb3(d3_i)
            );

            deco_BDS_4 deco_s (
                .Num(count_timer[i][13:0]),

                .numb0(d0_s),
                .numb1(d1_s),
                .numb2(d2_s),
                .numb3(d3_s)
            );

            //------------------------------------------------
            // INVALIDATIONS
            //------------------------------------------------

            SevenSeg_Display #(
                .x(145),
                .y(65 + i*90)
            ) ss_inv3 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d3_i),
                .visible(v_inv[i*4+3])
            );

            SevenSeg_Display #(
                .x(170),
                .y(65 + i*90)
            ) ss_inv2 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d2_i),
                .visible(v_inv[i*4+2])
            );

            SevenSeg_Display #(
                .x(195),
                .y(65 + i*90)
            ) ss_inv1 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d1_i),
                .visible(v_inv[i*4+1])
            );

            SevenSeg_Display #(
                .x(220),
                .y(65 + i*90)
            ) ss_inv0 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d0_i),
                .visible(v_inv[i*4+0])
            );

            //------------------------------------------------
            // STALLS
            //------------------------------------------------

            SevenSeg_Display #(
                .x(385),
                .y(65 + i*90)
            ) ss_st3 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d3_s),
                .visible(v_stall[i*4+3])
            );

            SevenSeg_Display #(
                .x(410),
                .y(65 + i*90)
            ) ss_st2 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d2_s),
                .visible(v_stall[i*4+2])
            );

            SevenSeg_Display #(
                .x(435),
                .y(65 + i*90)
            ) ss_st1 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d1_s),
                .visible(v_stall[i*4+1])
            );

            SevenSeg_Display #(
                .x(460),
                .y(65 + i*90)
            ) ss_st0 (
                .Q_X(Q_X),
                .Q_Y(Q_Y),
                .num(d0_s),
                .visible(v_stall[i*4+0])
            );

        end

    endgenerate

    //====================================================
    // PANEL
    //====================================================

    logic Area_Fondo;

    Square_Area #(
        .x0(20),
        .x1(620),
        .y0(20),
        .y1(440),
        .corn(8)
    ) PANEL (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(Area_Fondo)
    );

    //====================================================
    // HEADER
    //====================================================

    logic Header;

    Square_Area #(
        .x0(20),
        .x1(620),
        .y0(20),
        .y1(50),
        .corn(0)
    ) HEAD (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(Header)
    );

    //====================================================
    // GRID LINES
    //====================================================

    logic line_v1;
    logic line_v2;

    logic line_h0;
    logic line_h1;
    logic line_h2;

    Square_Area #(
        .x0(120),
        .x1(123),
        .y0(50),
        .y1(420),
        .corn(0)
    ) DIV_V1 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(line_v1)
    );

    Square_Area #(
        .x0(360),
        .x1(363),
        .y0(50),
        .y1(420),
        .corn(0)
    ) DIV_V2 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(line_v2)
    );

    Square_Area #(
        .x0(20),
        .x1(620),
        .y0(135),
        .y1(138),
        .corn(0)
    ) DIV_H0 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(line_h0)
    );

    Square_Area #(
        .x0(20),
        .x1(620),
        .y0(225),
        .y1(228),
        .corn(0)
    ) DIV_H1 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(line_h1)
    );

    Square_Area #(
        .x0(20),
        .x1(620),
        .y0(315),
        .y1(318),
        .corn(0)
    ) DIV_H2 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(line_h2)
    );

    //====================================================
    // CACHE BOXES
    //====================================================

    logic cache0_box;
    logic cache1_box;
    logic cache2_box;
    logic cache3_box;

    Square_Area #(
        .x0(50),
        .x1(85),
        .y0(70),
        .y1(105),
        .corn(4)
    ) CACHE0 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(cache0_box)
    );

    Square_Area #(
        .x0(50),
        .x1(85),
        .y0(160),
        .y1(195),
        .corn(4)
    ) CACHE1 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(cache1_box)
    );

    Square_Area #(
        .x0(50),
        .x1(85),
        .y0(250),
        .y1(285),
        .corn(4)
    ) CACHE2 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(cache2_box)
    );

    Square_Area #(
        .x0(50),
        .x1(85),
        .y0(340),
        .y1(375),
        .corn(4)
    ) CACHE3 (
        .Q_X(Q_X),
        .Q_Y(Q_Y),
        .Aden(cache3_box)
    );

    //====================================================
    // ANY ACTIVE SEGMENT
    //====================================================

    logic any_seg;

    assign any_seg =
        (|v_inv) |
        (|v_stall);

    //====================================================
    // VGA DRAW
    //====================================================

    always_comb begin

        //------------------------------------------------
        // DEFAULT
        //------------------------------------------------

        R = 8'h00;
        G = 8'h00;
        B = 8'h00;

        //------------------------------------------------
        // ACTIVE AREA
        //------------------------------------------------

        if(VGA_Blank) begin

            //--------------------------------------------
            // PANEL
            //--------------------------------------------

            if(Area_Fondo) begin

                R = 8'h05;
                G = 8'h10;
                B = 8'h30;

            end

            //--------------------------------------------
            // HEADER
            //--------------------------------------------

            if(Header) begin

                R = 8'h20;
                G = 8'h30;
                B = 8'h70;

            end

            //--------------------------------------------
            // GRID
            //--------------------------------------------

            if(line_v1 || line_v2 ||
               line_h0 || line_h1 || line_h2) begin

                R = 8'h50;
                G = 8'h50;
                B = 8'h50;

            end

            //--------------------------------------------
            // CACHE COLORS
            //--------------------------------------------

            if(cache0_box) begin
                R = 8'hFF;
                G = 8'h30;
                B = 8'h30;
            end

            if(cache1_box) begin
                R = 8'h30;
                G = 8'hFF;
                B = 8'h30;
            end

            if(cache2_box) begin
                R = 8'h30;
                G = 8'h30;
                B = 8'hFF;
            end

            if(cache3_box) begin
                R = 8'hFF;
                G = 8'hFF;
                B = 8'h30;
            end

            //--------------------------------------------
            // NUMBERS
            //--------------------------------------------

            if(any_seg) begin

                R = 8'hFF;
                G = 8'hFF;
                B = 8'hFF;

            end

        end

    end

endmodule