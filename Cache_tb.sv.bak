`timescale 1ns/1ps

module Cache_tb();

    // Señales del Reloj y Reset
    logic clk;
    logic reset;
    
    // Interfaz Procesador -> Cache
    logic we;
    logic rd;
    logic [4:0] address;
    logic [31:0] data_in;
    logic [31:0] data_out;
    logic stall;

    // Interfaz IC -> Cache
    logic ready;
    logic bus_inv;
    logic bus_rd;
    logic [1:0] ic_tag;
    logic [63:0] ic_data;
    
    // Monitoreo
    logic [1:0] current_state;
    logic [1:0] current_tag;

    // Instancia de la Cache
    Cache uut (.*);

    // Generación de Reloj (10ns periodo)
    always #5 clk = ~clk;

    initial begin
        // --- Inicialización ---
        clk = 0;
        reset = 1;
        we = 0;
        rd = 0;
        address = 0;
        data_in = 0;
        ready = 0;
        bus_inv = 0;
        bus_rd = 0;
        ic_tag = 0;
        ic_data = 0;

        #15 reset = 0;
        $display("--- Inicio de Testbench MSI ---");

        // --- CASO 1: Read Miss (I -> S) ---
        // El procesador quiere leer la dirección 0x04 (Tag 0, Index 2, Offset 0)
        address = 5'b00100; 
        rd = 1;
        #10;
        if (stall) $display("[T=25ns] Stall detectado: Read Miss en direccion 0x04");

        // El IC responde después de un ciclo
        #10;
        ic_tag = 2'b00;
        ic_data = {32'hBEEF_BEEF, 32'hCAFE_CAFE}; // Bloque completo
        ready = 1;
        #10;
        ready = 0;
        rd = 0;
        $display("[T=45ns] Dato cargado. Estado actual: %b (Debe ser SHARED=01)", current_state);

        // --- CASO 2: Write Hit (S -> M) ---
        // El procesador escribe en la misma dirección que ya tiene
        address = 5'b00100;
        data_in = 32'h1234_5678;
        we = 1;
        #10;
        we = 0;
        $display("[T=55ns] Write Hit ejecutado. Estado actual: %b (Debe ser MODIFIED=10)", current_state);

        // --- CASO 3: Invalidación Externa (M -> I) ---
        // El IC avisa que otro procesador quiere escribir en nuestro bloque
        #10;
        bus_inv = 1;
        #10;
        bus_inv = 0;
        $display("[T=75ns] Invalidez recibida del Bus. Estado actual: %b (Debe ser INVALID=00)", current_state);

        // --- CASO 4: Write Miss Directo (I -> M) ---
        // Procesador escribe en dirección 0x08 (Tag 1, Index 0, Offset 0)
        address = 5'b01000;
        data_in = 32'hAAAA_BBBB;
        we = 1;
        #10;
        // Simulamos respuesta del IC
        ic_tag = 2'b01;
        ic_data = 64'h0; // Datos base vacíos de memoria
        ready = 1;
        #10;
        ready = 0;
        we = 0;
        $display("[T=105ns] Write Miss completado. Estado actual: %b (Debe ser MODIFIED=10)", current_state);

        #20;
        $display("--- Testbench Finalizado ---");
        $finish;
    end

endmodule