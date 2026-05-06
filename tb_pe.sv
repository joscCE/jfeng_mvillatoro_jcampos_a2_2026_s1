`timescale 1ns/1ps

module tb_pe;

    // ================================
    // Señales del PE
    // ================================
    reg clk;
    reg rst;
    reg done;

    wire        req_valid;
    wire        req_type;
    wire [4:0]  addr;
    wire [31:0] data;
    wire        finished;

    // ================================
    // Instancia del PE
    // ================================
    PE #(
        .TRACE_MIF("trace0.mif")
    ) uut (
        .clk(clk),
        .rst(rst),
        .done(done),
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
        done = 0;
        rst  = 1;   // activar reset

        $display("---- Iniciando Testbench ----");

        // Mantener reset por un tiempo
        #20;
        rst = 0;

        // Esperar solicitudes del PE
        forever begin
            @(posedge clk);

            if (req_valid) begin
                $display("[%t] PE solicita -> type=%0d addr=%0d data=%h",
                    $time, req_type, addr, data);

                // Simula que la cache tarda 1 ciclo en responder
                @(posedge clk);
                done = 1;

                @(posedge clk);
                done = 0;
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