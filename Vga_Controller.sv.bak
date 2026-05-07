module Vga_Controller #(parameter N=8,
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
    input logic clk, rst, stop,
    output logic Hs, Vs,
	 output logic VGA_Blank, VGA_Sync_N,
	 output logic [9:0] Q_X, Q_Y,
	 output logic [7:0]  R, G, B,
	 input logic [9:0] Money,
	 input logic [1:0] state1, state2, state3

	 
);	 



	logic [9:0] Q_x, Q_y, D_x, D_y;         
    logic rstx,rsty;
	logic Area_screen;
	
	
	
	logic Area_D;
	logic Area_D2;
	logic Area_D3;
	logic Area_D4;
	logic Area_S;
	
	logic Area_marco;
	logic Area_div;

	Counter count_y(clk, (rstx & rsty)| rst, rstx, 1'b1 ,D_y);			
	Counter count_x(clk, rstx | rst , 1'b1, 1'b1 ,D_x);
   

	Register reg_x(clk, rst, D_x, 1'b1 ,Q_x);
	Register reg_y(clk, rst, D_y, 1'b1 ,Q_y);
	
	Comparator cmp_x(Q_x, H_Total, rstx);
	Comparator cmp_y(Q_y, V_Total, rsty);

    
    

    // Señales de sincronización
    assign Hs = ~(Q_x >= H_Va + H_FP && Q_x < H_Va + H_FP + H_SycP);  
	 assign Vs = ~(Q_y >= V_Va + V_FP && Q_y < V_Va + V_FP + V_SycP); 
	 assign VGA_Sync_N = 1'b1;
	 assign VGA_Blank = (Q_x <= H_Va) && (Q_y <= V_Va);
	 assign Q_X = Q_x;
	 assign Q_Y = Q_y;
	 


logic Area_Dinero, Area_Fondo;

Panel #(
    .x_start(10),
    .y_start(240),
    .width(280),
    .height(110)
) panel_izquierdo (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Area_front(Area_Dinero),

);

logic [3:0] numb1;
logic [3:0] numb2;
logic [3:0] numb3;

deco_BDS deco(
.Num(Money),
.numb1(numb1),
.numb2(numb2),
.numb3(numb3)

);



logic visible_SegT;

logic visible_seg;
SevenSeg_Display #(
    .x(135), .y(276)
) display_seg (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .num(numb3),
    .visible(visible_seg)
);



logic visible_seg1;
SevenSeg_Display #(
    .x(175), .y(276)
) display_seg1 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .num(numb2),
    .visible(visible_seg1)
);

logic visible_seg2;
SevenSeg_Display #(
    .x(215), .y(276)
) display_seg2 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .num(numb1),
    .visible(visible_seg2)
);



assign visible_SegT = visible_seg1 | visible_seg|visible_seg2 ;



//columnas

logic column1, column2,column3, fill1, fill2, fill3;

Column #(
    .x_start(320),
    .y_start(160),
    .width(110),
    .height(290)
) c1 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Area_front(column1),
	 .fill(fill1)

);

Column #(
    .x_start(420),
    .y_start(160),
    .width(110),
    .height(290)
) c2 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Area_front(column2),
	.fill(fill2)
);


Column #(
    .x_start(520),
    .y_start(160),
    .width(110),
    .height(290)
) c3 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Area_front(column3),
	.fill(fill3)
);

logic atras_slot;
logic atras_slot_som;






//C de colones

logic colones;

logic [7:0] RC ,BC, GC;



Draw_C  #(.SCALE(6)) colo (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .pos_x(80),
    .pos_y(280),
    .visible(colones)
);





// area para botones


logic Area_Btn1;
logic Area_Btn2;
logic Area_Btn3;

logic Area_Btn1_s;
logic Area_Btn2_s;
logic Area_Btn3_s;
logic Arrow_up, Arrow_Down,Equis;


Draw_Arrow  #(.SCALE(5)) arro (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .pos_x(40),
    .pos_y(370),
    .visible(Arrow_up)
);


Draw_Arrow_Dowm  #(.SCALE(5)) arro2 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .pos_x(150),
    .pos_y(370),
    .visible(Arrow_Down)
);

Draw_X  #(.SCALE(4)) ex (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .pos_x(250),
    .pos_y(370),
    .visible(Equis)
);





Button #(
    .x_start(10),
    .y_start(360),
    .width(100),
    .height(100)
) Btn1 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Btn_front(Area_Btn1),
    .Btn_shadow(Area_Btn1_s)
);





Button #(
    .x_start(120),
    .y_start(360),
    .width(100),
    .height(100)
) Btn2 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Btn_front(Area_Btn2),
    .Btn_shadow(Area_Btn2_s)
);

Button #(
    .x_start(230),
    .y_start(360),
    .width(80),
    .height(100)
) Btn3 (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Btn_front(Area_Btn3),
    .Btn_shadow(Area_Btn3_s)
);



 


//letrero

logic letrero_Zone;
logic letras;

Panel #(
    .x_start(320),
    .y_start(70),
    .width(310),
    .height(80)
) panel_msg (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .Area_front(letrero_Zone),

);
logic win_state;
logic mitad;

assign mitad = Q_Y <= 120;

Draw_CASH #(.SCALE(4)) cash_display (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .pos_x(430),
    .pos_y(105),
    .visible(letras)
);

Draw_WIN #(.SCALE(6)) Winnig (
    .Q_X(Q_X),
    .Q_Y(Q_Y),
    .pos_x(10),
    .pos_y(105),
    .visible(win_state)
);



//figuras

// Slots en 3x3 dentro del Area_screen

logic slot[2:0][2:0];  // 3 filas x 3 columnas

logic slot_active;
logic slot_active_row0;
logic slot_active_row1;
logic slot_active_row2;


// Activación por fila
assign slot_active_row0 = slot[0][0] | slot[0][1] | slot[0][2];
assign slot_active_row1 = slot[1][0] | slot[1][1] | slot[1][2];
assign slot_active_row2 = slot[2][0] | slot[2][1] | slot[2][2];

// Activación global (si aún la necesitas)
assign slot_active = slot_active_row0 | slot_active_row1 | slot_active_row2;










// Fila 0 (Y = 210 a 270)



logic clk_div;

clk_div clkdiv(
    .clk(clk),
    .rst_active(rst),
    .clk25(clk_div)
);








logic [7:0] R_slot [0:2][0:2];
logic [7:0] G_slot [0:2][0:2];
logic [7:0] B_slot [0:2][0:2];

Symbol #(.x0(360), .x1(390), .y0(210), .y1(270)) slot_0_0 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state1+2'd2), .visible(slot[0][0]), .R(R_slot[0][0]), .G(G_slot[0][0]), .B(B_slot[0][0])
);

Symbol #(.x0(460), .x1(490), .y0(210), .y1(270)) slot_0_1 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state2+2'd2), .visible(slot[0][1]), .R(R_slot[0][1]), .G(G_slot[0][1]), .B(B_slot[0][1])
);

Symbol #(.x0(560), .x1(590), .y0(210), .y1(270)) slot_0_2 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state3+2'd2), .visible(slot[0][2]), .R(R_slot[0][2]), .G(G_slot[0][2]), .B(B_slot[0][2])
);

// Fila 1 (Y = 290 a 350)
Symbol #(.x0(360), .x1(390), .y0(290), .y1(350)) slot_1_0 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state1), .visible(slot[1][0]), .R(R_slot[1][0]), .G(G_slot[1][0]), .B(B_slot[1][0])
);

Symbol #(.x0(460), .x1(490), .y0(290), .y1(350)) slot_1_1 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state2), .visible(slot[1][1]), .R(R_slot[1][1]), .G(G_slot[1][1]), .B(B_slot[1][1])
);

Symbol #(.x0(560), .x1(590), .y0(290), .y1(350)) slot_1_2 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state3), .visible(slot[1][2]), .R(R_slot[1][2]), .G(G_slot[1][2]), .B(B_slot[1][2])
);

// Fila 2 (Y = 375 a 430)
Symbol #(.x0(360), .x1(390), .y0(375), .y1(430)) slot_2_0 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state1+2'd1), .visible(slot[2][0]), .R(R_slot[2][0]), .G(G_slot[2][0]), .B(B_slot[2][0])
);

Symbol #(.x0(460), .x1(490), .y0(375), .y1(430)) slot_2_1 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state2+2'd1), .visible(slot[2][1]), .R(R_slot[2][1]), .G(G_slot[2][1]), .B(B_slot[2][1])
);

Symbol #(.x0(560), .x1(590), .y0(375), .y1(430)) slot_2_2 ( .Q_X(Q_X), .Q_Y(Q_Y), .rot_state(state3+2'd1), .visible(slot[2][2]), .R(R_slot[2][2]), .G(G_slot[2][2]), .B(B_slot[2][2])
);


logic [23:0] color_Select;

// Mux que elige entre los 9 símbolos visibles
Mux93 color_selector(
    .A({R_slot[0][0], G_slot[0][0], B_slot[0][0]}), 
    .B({R_slot[0][1], G_slot[0][1], B_slot[0][1]}), 
    .C({R_slot[0][2], G_slot[0][2], B_slot[0][2]}), 
    .D({R_slot[1][0], G_slot[1][0], B_slot[1][0]}), 
    .E({R_slot[1][1], G_slot[1][1], B_slot[1][1]}), 
    .F({R_slot[1][2], G_slot[1][2], B_slot[1][2]}), 
    .G({R_slot[2][0], G_slot[2][0], B_slot[2][0]}), 
    .H({R_slot[2][1], G_slot[2][1], B_slot[2][1]}), 
    .I({R_slot[2][2], G_slot[2][2], B_slot[2][2]}), 
    .S({slot[2][2],slot[2][1],slot[2][0],slot[1][2],slot[1][1],slot[1][0],slot[0][2],slot[0][1],slot[0][0]}), 
    .out(color_Select)
);
	 
	 
	 
logic area_colum;

Rom_tile rom_tile(
	.Q_X(Q_X), 
	.Q_Y(Q_Y),
	.visible(area_colum),
	.R(), 
	.G(), 
	.B()
);
	 
	 
always_comb begin
    Area_screen = (Q_X > 330 && Q_X < 620) && (Q_Y > 180 && Q_Y < 450);
	
	 Area_marco = (Q_X > 420 && Q_X < 630) && (Q_Y > 160 && Q_Y < 460);


	
    if ((fill1 | fill2 | fill3) & ~area_colum & ~slot_active_row0 & ~slot_active_row1 & ~slot_active_row2) begin
        R = 8'hbF;
        G = 8'hbF;
        B = 8'hFF;
    end else if( win_state ) begin
        R = 8'hFF;
        G = 8'h00;
        B = 8'h00;
	end else if( slot_active) begin
        R = color_Select[23:16]; // bits 23–16
        G = color_Select[15:8];  // bits 15–8
        B = color_Select[7:0];   // bits 7–0
	end else if( (Area_Btn1_s | Area_Btn3_s | Area_Btn2_s) & ~Arrow_up & ~Arrow_Down & ~Equis) begin
        R = 8'h68;
        G = 8'h00;
        B = 8'h68;
	end  else if(Area_Btn1 | Area_Btn2 | Area_Btn3) begin
        R = 8'hFF;
        G = 8'h00;
        B = 8'hFF;
	end else if(letras & mitad ) begin
        R = 8'h00;
        G = 8'hbF;
        B = 8'hbF;
	end else if(letrero_Zone) begin
        R = 8'h00;
        G = 8'h00;
        B = 8'hFF;
	end else if(colones | visible_SegT) begin
        R = 8'hFF;
        G = 8'hFF;
        B = 8'hFF;
	end else if(Area_Dinero | (letras & ~mitad)) begin
        R = 8'h00;
        G = 8'hFF;
        B = 8'h00;
	end else if(area_colum) begin
        R = 8'hFF;
        G = 8'hFF;
        B = 8'h00;
	end else if( column1| column2 | column3  ) begin
        R = 8'hFF;
        G = 8'hFF;
        B = 8'h00;
	end else begin 
		R = 8'h00;
        G = 8'h00;
        B = 8'h00;
	end

end

	
endmodule