`timescale 1ns / 1ps

module Top_tb();

    // Parámetros de simulación
    logic clk;
    logic reset;

    // Instancia del módulo Top
    Top dut (
        .clk(clk),
        .reset(reset)
    );

    // Generación de Reloj (100MHz aprox)
    always #5 clk = ~clk;

    // Proceso de prueba
    initial begin
        // Inicialización de señales
        clk = 0;
        reset = 1;

        // Reset del sistema
        $display("--- Iniciando Simulación del Sistema Multi-Core MSI ---");
        #20;
        reset = 0;
        $display("--- Reset liberado, ejecutando trazas ---");

        // Esperar a que los PE terminen o un tiempo prudencial
        // Dado que usas archivos .mif, la simulación debe durar lo suficiente
        // para que cada procesador ejecute sus instrucciones.
        #100000; 

        // Mostrar reporte de estadísticas por cada Cache
        $display("\n========================================================");
        $display("         REPORTE DE RENDIMIENTO (HARDWARE COUNTERS)      ");
        $display("========================================================");
        
        for (int i = 0; i < 4; i++) begin
            $display("CORE %0d:", i);
            $display("  > Invalidaciones recibidas (count_inv):   %0d", dut.count_inv[i]);
            $display("  > Ciclos totales en STALL (count_timer):  %0d", dut.count_timer[i]);
            $display("--------------------------------------------------------");
        end
        
        $display("Simulación finalizada a las %0t", $time);
        $finish;
    end

    // Opcional: Monitor de eventos críticos en consola
    initial begin
        forever begin
            @(posedge clk);
            for(int j=0; j<4; j++) begin
                if (dut.bus_inv && dut.snoop_addr != 0) begin
                    // Ejemplo de log si quieres ver las invalidaciones en tiempo real
                    // $display("[BUS] Invalidación detectada en dirección: %h", dut.snoop_addr);
                end
            end
        end
    end

endmodule 