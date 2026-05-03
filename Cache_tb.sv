`timescale 1ns/1ps

module Cache_tb();

    // Reloj y Reset
    logic clk;
    logic reset;
    
    // CPU -> Cache
    logic we;
    logic rd;
    logic [4:0] address;
    logic [31:0] data_in;
    logic [31:0] data_out;
    logic stall;

    // IC -> Cache
    logic ready;
    logic bus_inv;
    logic bus_rd;
    logic [1:0] bus_tag;   
    logic [1:0] ic_tag;
    logic [63:0] ic_data;

    // Salidas nuevas
    logic ready_c;
    logic [63:0] cache_line_c;

    // Debug
    logic [1:0] current_state;
    logic [1:0] current_tag;

    // Instancia
    Cache uut (.*);

    // Clock
    always #5 clk = ~clk;

    initial begin
        // Init
        clk = 0;
        reset = 1;
        we = 0;
        rd = 0;
        address = 0;
        data_in = 0;
        ready = 0;
        bus_inv = 0;
        bus_rd = 0;
        bus_tag = 0;
        ic_tag = 0;
        ic_data = 0;

        #15 reset = 0;
        $display("\n--- Inicio Testbench MSI (con Write-Back) ---");

        // =========================================
        // CASO 1: READ MISS (I -> S)
        // =========================================
        address = 5'b00100; // tag=00 index=10
        rd = 1;
        #10;

        #10;
        ic_tag = 2'b00;
        ic_data = {32'hBEEF_BEEF, 32'hCAFE_CAFE};
        ready = 1;

        #10;
        ready = 0;
        rd = 0;

        $display("[Read Miss] Estado: %b (esperado SHARED=01)", current_state);

        // =========================================
        //CASO 2: WRITE HIT (S -> M)
        // =========================================
        address = 5'b00100;
        data_in = 32'h1234_5678;
        we = 1;

        #10;
        we = 0;

        $display("[Write Hit] Estado: %b (esperado MODIFIED=10)", current_state);

        // =========================================
        //CASO 3: BUS_RD con MODIFIED (WRITE-BACK)
        // =========================================
        #10;
        bus_tag = 2'b00; // mismo tag
        bus_rd = 1;

        #10;
        bus_rd = 0;

        $display("[BusRd] ready_c: %b (esperado 1)", ready_c);
        $display("[BusRd] cache_line_c: %h (debe ser el bloque)");
        $display("[BusRd] Estado: %b (esperado SHARED=01)", current_state);

        // =========================================
        //CASO 4: INVALIDACIÓN (S -> I)
        // =========================================
        #10;
        bus_inv = 1;

        #10;
        bus_inv = 0;

        $display("[Invalidate] Estado: %b (esperado INVALID=00)", current_state);

        // =========================================
        // CASO 5: WRITE MISS (I -> M)
        // =========================================
        address = 5'b01000; // tag=01 index=00
        data_in = 32'hAAAA_BBBB;
        we = 1;

        #10;

        ic_tag = 2'b01;
        ic_data = 64'h0;
        ready = 1;

        #10;
        ready = 0;
        we = 0;

        $display("[Write Miss] Estado: %b (esperado MODIFIED=10)", current_state);

        // =========================================
        #20;
        $display("--- Testbench Finalizado ---\n");
        $finish;
    end

endmodule