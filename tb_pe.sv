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
    wire        req_type;
    wire [4:0]  addr;
    wire [31:0] data;
    wire        finished;

    // ================================
    // Instancia del PE
    // ================================
    PE #(
        .TRACE_MIF("trace.mif")
    ) uut (
        .clk(clk),
        .rst(rst),
        .stall_cache(stall_cache),
        .data_cache(data_cache),
        .req_valid(req_valid),
        .req_type(req_type),
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
                $display("[%t] PE solicita -> type=%0d addr=%0d data=%h",
                         $time, req_type, addr, data);

                // simular 1 ciclo de espera
                stall_cache = 1;
                @(posedge clk);

                // Cache responde
                data_cache  = $random;   // aunque el PE no lo use aún
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