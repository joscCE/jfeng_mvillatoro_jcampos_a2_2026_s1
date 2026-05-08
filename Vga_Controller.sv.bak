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
    input logic clk, rst,
    output logic Hs, Vs,
    output logic VGA_Blank, VGA_Sync_N,
    output logic [9:0] Q_X, Q_Y,
    output logic [7:0] R, G, B,
    

    input logic [63:0] count_timer [3:0],
    input logic [63:0] count_inv [3:0]
);

    // --- Señales de Sincronización (Tu lógica original) ---
    logic [9:0] Q_x, Q_y, D_x, D_y;
    logic rstx, rsty;
    CounterV count_y(clk, (rstx & rsty)| rst, rstx, 1'b1 ,D_y);			
    CounterV count_x(clk, rstx | rst , 1'b1, 1'b1 ,D_x);
    Register reg_x(clk, rst, D_x, 1'b1 ,Q_x);
    Register reg_y(clk, rst, D_y, 1'b1 ,Q_y);
    Comparator cmp_x(Q_x, 10'd800, rstx); // Ajustado a total genérico
    Comparator cmp_y(Q_y, 10'd525, rsty);
    
    assign Hs = ~(Q_x >= 656 && Q_x < 752);  
    assign Vs = ~(Q_y >= 490 && Q_y < 492); 
    assign VGA_Sync_N = 1'b1;
    assign VGA_Blank = (Q_x < 640) && (Q_y < 480);
    assign Q_X = Q_x;
    assign Q_Y = Q_y;

    // --- LÓGICA DE VISUALIZACIÓN DE ESTADÍSTICAS ---
    
    logic [3:0] d_inv [3:0][2:0];   // Dígitos para Invalidaciones (4 cores, 3 dígitos c/u)
    logic [3:0] d_stall [3:0][2:0]; // Dígitos para Stall (4 cores, 3 dígitos c/u)
	 logic [11:0] v_inv;  
    logic [11:0] v_stall;

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_decos
            // Cables internos para los dígitos decodificados de este Core
            logic [3:0] d1_i, d2_i, d3_i;
            logic [3:0] d1_s, d2_s, d3_s;

            // Decodificador para Invalidaciones (BDS)
            deco_BDS deco_i (
                .Num(count_inv[i][9:0]), 
                .numb1(d1_i), .numb2(d2_i), .numb3(d3_i)
            );
            
            // Decodificador para Stall (BDS)
            deco_BDS deco_s (
                .Num(count_timer[i][9:0]), 
                .numb1(d1_s), .numb2(d2_s), .numb3(d3_s)
            );
            
            // Displays de 7 Segmentos para Invalidaciones (Columna Izquierda)
            // Usamos índices calculados: i*3, i*3+1, i*3+2 para llenar el vector de 12 bits
            SevenSeg_Display #(.x(100), .y(100 + i*80)) ss_inv2 (.Q_X(Q_X), .Q_Y(Q_Y), .num(d3_i), .visible(v_inv[i*3+2]));
            SevenSeg_Display #(.x(140), .y(100 + i*80)) ss_inv1 (.Q_X(Q_X), .Q_Y(Q_Y), .num(d2_i), .visible(v_inv[i*3+1]));
            SevenSeg_Display #(.x(180), .y(100 + i*80)) ss_inv0 (.Q_X(Q_X), .Q_Y(Q_Y), .num(d1_i), .visible(v_inv[i*3+0]));

            // Displays de 7 Segmentos para Stall (Columna Derecha)
            SevenSeg_Display #(.x(400), .y(100 + i*80)) ss_st2 (.Q_X(Q_X), .Q_Y(Q_Y), .num(d3_s), .visible(v_stall[i*3+2]));
            SevenSeg_Display #(.x(440), .y(100 + i*80)) ss_st1 (.Q_X(Q_X), .Q_Y(Q_Y), .num(d2_s), .visible(v_stall[i*3+1]));
            SevenSeg_Display #(.x(480), .y(100 + i*80)) ss_st0 (.Q_X(Q_X), .Q_Y(Q_Y), .num(d1_s), .visible(v_stall[i*3+0]));
        end
    endgenerate

    // Áreas de fondo
    logic Area_Fondo;
    assign Area_Fondo = (Q_X > 50 && Q_X < 590) && (Q_Y > 50 && Q_Y < 430);
    
    // Ahora la reducción OR funcionará correctamente sobre los 12 bits
    logic any_seg;
    assign any_seg = (|v_inv) | (|v_stall);

    // Pintar la pantalla
    always_comb begin
        if (!VGA_Blank) begin
            {R, G, B} = 8'h00; // Fuera de zona activa
        end else if (any_seg) begin
            {R, G, B} = 8'hFF; // Blanco para los números
        end else if (Area_Fondo) begin
            R = 8'h00; G = 8'h20; B = 8'h60; // Azul para el panel
        end else begin
            {R, G, B} = 8'h00; // Fondo negro
        end
    end

endmodule