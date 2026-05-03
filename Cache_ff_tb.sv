`timescale 1ns/1ps

module Cache_ff_tb();

    // Señales
    logic clk, reset, we, rd, stall;
    logic [4:0] address;
    logic [31:0] data_in, data_out;
    logic ready, bus_rd, bus_update, CE;
    logic [31:0] bus_data;
    logic [1:0] bus_tag, ic_tag;
    logic [63:0] ic_data;
    logic [1:0] current_state, current_tag;

    // Instancia
    Cache_ff uut (.*);

    // Estados Firefly
    localparam VALID   = 2'b00; // Exclusivo Limpio
    localparam SHARED  = 2'b01; // Compartido
    localparam DIRTY   = 2'b10; // Exclusivo Sucio (no usado explícitamente en este código pero definido)
    localparam INVALID = 2'b11;

    always #5 clk = ~clk;

    // Tarea para simular respuesta del IC ante un Miss
    task response_ic(input [1:0] t, input [63:0] d, input copy_exists);
        begin
            wait(stall);
            @(posedge clk);
            #1;
            ic_tag = t;
            ic_data = d;
            CE = copy_exists;
            ready = 1;
            @(posedge clk);
            #1;
            ready = 0;
            CE = 0;
        end
    endtask

    initial begin
        // Init
        clk = 0; reset = 1; we = 0; rd = 0; address = 0;
        data_in = 0; ready = 0; bus_rd = 0; bus_update = 0;
        bus_data = 0; bus_tag = 0; CE = 0;

        #15 reset = 0;
        $display("\n--- INICIO TEST PROTOCOLO FIREFLY ---");

        // ---------------------------------------------------------
        // ESCENARIO 1: Read Miss sin copia en otras caches (CE=0)
        // Debería pasar de INVALID a VALID (Exclusivo)
        // ---------------------------------------------------------
        $display("\n[Escenario 1] Read Miss (CE=0)...");
        address = 5'b00000; rd = 1;
        fork
            response_ic(2'b00, 64'hAAAA_AAAA_BBBB_BBBB, 0);
        join
        @(posedge clk); rd = 0;
        $display("Estado: %b (Esperado: 00 - VALID), Dato: %h", current_state, data_out);

        // ---------------------------------------------------------
        // ESCENARIO 2: Write Hit en estado VALID
        // Sigue en VALID porque no hay nadie más escuchando (CE=0)
        // ---------------------------------------------------------
        $display("\n[Escenario 2] Write Hit en Exclusivo (CE=0)...");
        address = 5'b00000; data_in = 32'h1234_5678; we = 1; CE = 0;
        #10 we = 0;
        $display("Estado: %b (Esperado: 00 - VALID)", current_state);

        // ---------------------------------------------------------
        // ESCENARIO 3: Snoop Update (Alguien más actualiza el dato)
        // Si recibimos bus_update, actualizamos dato y pasamos a SHARED
        // ---------------------------------------------------------
        $display("\n[Escenario 3] Recibiendo Bus Update externo...");
        bus_tag = 2'b00;
        bus_data = 32'h9999_9999;
        bus_update = 1; address = 5'b00000; // offset 0
        #10 bus_update = 0;
        $display("Estado: %b (Esperado: 01 - SHARED), Dato nuevo: %h", current_state, uut.cache[0][33:2]);

        // ---------------------------------------------------------
        // ESCENARIO 4: Write Hit con copia existente (CE=1)
        // Como hay otros (CE=1), nos quedamos en SHARED
        // ---------------------------------------------------------
        $display("\n[Escenario 4] Write Hit con CE=1...");
        address = 5'b00000; data_in = 32'h7777_7777; we = 1; CE = 1;
        #10 we = 0;
        $display("Estado: %b (Esperado: 01 - SHARED)", current_state);

        // ---------------------------------------------------------
        // ESCENARIO 5: Conflicto y reemplazo
        // Traer un nuevo tag (01) en lugar del (00)
        // ---------------------------------------------------------
        $display("\n[Escenario 5] Reemplazo de linea por conflicto...");
        address = 5'b01000; rd = 1; // Index 0, Tag 1
        fork
            response_ic(2'b01, 64'h0, 0);
        join
        @(posedge clk); rd = 0;
        $display("Nuevo Tag: %b, Estado: %b", current_tag, current_state);

        #20 $display("\n--- TEST FIREFLY FINALIZADO ---");
        $finish;
    end

endmodule