`timescale 1ns/1ps

module tb_pe;

    // ================================
    // Señales del PE
    // ================================
    reg clk;
    reg rst;

    // Nuevas señales hacia el PE
    reg stall_cache;
    reg [31:0] data_cache;

    wire        req_valid;
    wire        rd;
    wire        we;
    wire [4:0]  addr;
    wire [31:0] data;
    wire        finished;

    // ================================
    // Instancia del PE
    // ================================
    PE #(
        .TRACE_MIF("trace1.mif")
    ) uut (
        .clk(clk),
        .rst(rst),
        .stall_cache(stall_cache),
        .data_cache(data_cache),
        .req_valid(req_valid),
        .rd(rd),
        .we(we),
        .addr(addr),
        .data(data),
        .finished(finished)
    );

    // ================================
    // Generación de reloj
    // ================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;   // 100 MHz
    end

    // ================================
    // Estímulos
    // ================================
    initial begin
        // Inicialización
        rst         = 1;
        stall_cache = 0;
        data_cache  = 32'h12345678;

        $display("---- Iniciando Testbench ----");

        // Mantener reset
        #20;
        rst = 0;

        // Esperar solicitudes del PE
        forever begin
            @(posedge clk);

            if (req_valid) begin
                $display("[%t] PE solicita -> %s addr=%0d data=%h",
                         $time,
                         rd ? "READ " : "WRITE",
                         addr,
                         data);

                // simular 1 ciclo de espera
                stall_cache = 1;
                @(posedge clk);

                // Cache responde
                data_cache  = $random;
                stall_cache = 0;
            end
        end
    end

    // ================================
    // Finalización automática
    // ================================
    initial begin
        wait(finished == 1);
        $display("[%t] PE termino ejecucion (FIN detectado)", $time);
        #20;
        $finish;
    end

endmodule