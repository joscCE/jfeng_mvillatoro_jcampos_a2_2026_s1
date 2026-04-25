`timescale 1ns/1ps

module Interconnect_MSI_tb();

    // ----------------------------------------------------------------
    // Señales del DUT (Device Under Test)
    // ----------------------------------------------------------------

    logic        clk;
    logic        reset;

    // Cache → IC
    logic [3:0]  help;
    logic [37:0] request_packet [3:0];

    // IC → cachés (broadcast)
    logic        bus_rd;
    logic        bus_inv;
    logic        ic_ready;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    // IC → RAM
    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;

    // RAM → IC
    logic [63:0] mem_data_out;
    logic        mem_ready;

    // ----------------------------------------------------------------
    // Instancia del DUT
    // ----------------------------------------------------------------

    Interconnect_MSI #(
        .SNOOP_WAIT_CYCLES(4)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .help         (help),
        .request_packet(request_packet),
        .bus_rd       (bus_rd),
        .bus_inv      (bus_inv),
        .ic_ready     (ic_ready),
        .ic_tag       (ic_tag),
        .ic_cache_line(ic_cache_line),
        .mem_we       (mem_we),
        .mem_address  (mem_address),
        .mem_data_in  (mem_data_in),
        .mem_data_out (mem_data_out),
        .mem_ready    (mem_ready)
    );

    // ----------------------------------------------------------------
    // Generador de reloj — 10ns de período (100MHz)
    // No sintetizable, solo válido en simulación
    // ----------------------------------------------------------------

    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Modelo de RAM simplificado
    // Simula la respuesta de la RAM con latencia de 1 ciclo
    // En un testbench real esto sería una instancia del módulo Ram
    // pero aquí lo manejamos manualmente para tener control total
    // ----------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (mem_we == 1'b0 && mem_address != 5'b0) begin
            // Simular dato de RAM según la dirección solicitada
            // En hardware real vendría del arreglo de memoria
            mem_data_out <= {32'hDEAD_BEEF, 32'hCAFE_BABE};
            mem_ready    <= 1'b1;
        end else if (mem_we == 1'b1) begin
            mem_ready    <= 1'b1;
            mem_data_out <= 64'b0;
        end else begin
            mem_ready    <= 1'b0;
            mem_data_out <= 64'b0;
        end
    end

    // ----------------------------------------------------------------
    // Tarea auxiliar: esperar N ciclos de reloj
    // Las tareas en testbench no son sintetizables
    // ----------------------------------------------------------------

    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // ----------------------------------------------------------------
    // Tarea auxiliar: enviar request de un PE
    // Arma el request_packet y levanta help para el PE indicado
    // ----------------------------------------------------------------

    task send_request(
        input logic [1:0]  pe_id,
        input logic        op_type,    // 1=lectura, 0=escritura
        input logic [4:0]  addr,
        input logic [31:0] data
    );
        request_packet[pe_id] = {op_type, addr, data};
        help[pe_id] = 1'b1;
        @(posedge clk);
        // Help se mantiene un ciclo y luego se baja
        // el IC ya lo capturó en IDLE
        help[pe_id] = 1'b0;
    endtask

    // ----------------------------------------------------------------
    // Tarea auxiliar: verificar valor con mensaje
    // ----------------------------------------------------------------

    task check(
        input string  nombre,
        input logic   obtenido,
        input logic   esperado
    );
        if (obtenido === esperado)
            $display("  [PASS] %s = %b", nombre, obtenido);
        else
            $display("  [FAIL] %s = %b, esperado %b", nombre, obtenido, esperado);
    endtask

    // ----------------------------------------------------------------
    // Estímulos principales
    // ----------------------------------------------------------------

    initial begin
        // --- Inicialización ---
        reset          = 1'b1;
        help           = 4'b0000;
        mem_data_out   = 64'b0;
        mem_ready      = 1'b0;

        for (int i = 0; i < 4; i++)
            request_packet[i] = 38'b0;

        // Mantener reset por 3 ciclos
        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        // ============================================================
        // CASO 1: Read Miss — PE0 lee dirección 0x04
        // Flujo esperado: IDLE → DECODE → SNOOP_ISSUE → WAIT_SNOOP
        //                 → MEM_ACCESS → RESPOND → IDLE
        // Señales esperadas:
        //   SNOOP_ISSUE: bus_rd=1 (lectura activa bus_rd en MSI)
        //   RESPOND:     ic_ready=1, ic_tag=address[4:3], ic_cache_line=dato de RAM
        // ============================================================

        $display("\n--- CASO 1: Read Miss PE0 (I -> S) ---");
        // type=1 (lectura), address=5'b00100 (tag=00, index=10, offset=0)
        send_request(2'd0, 1'b1, 5'b00100, 32'h0);

        // Esperar que el IC complete el flujo completo
        // DECODE(1) + SNOOP_ISSUE(1) + WAIT_SNOOP(4) + MEM_ACCESS(1) + RESPOND(1) = 8 ciclos
        wait_cycles(2);
        $display("  Verificando SNOOP_ISSUE:");
        check("bus_rd",  bus_rd,  1'b1);
        check("bus_inv", bus_inv, 1'b0);

        wait_cycles(6);
        $display("  Verificando RESPOND:");
        check("ic_ready", ic_ready, 1'b1);
        check("ic_tag",   ic_tag,   2'b00);

        wait_cycles(2);

        // ============================================================
        // CASO 2: Write Miss — PE1 escribe en dirección 0x08
        // Flujo esperado igual al read miss pero con bus_inv en lugar de bus_rd
        // Señales esperadas:
        //   SNOOP_ISSUE: bus_inv=1 (escritura activa bus_inv en MSI)
        //   RESPOND:     ic_ready=1
        // ============================================================

        $display("\n--- CASO 2: Write Miss PE1 (I -> M) ---");
        // type=0 (escritura), address=5'b01000 (tag=01, index=00, offset=0)
        send_request(2'd1, 1'b0, 5'b01000, 32'hAABBCCDD);

        wait_cycles(2);
        $display("  Verificando SNOOP_ISSUE:");
        check("bus_inv", bus_inv, 1'b1);
        check("bus_rd",  bus_rd,  1'b0);

        wait_cycles(6);
        $display("  Verificando RESPOND:");
        check("ic_ready", ic_ready, 1'b1);

        wait_cycles(2);

        // ============================================================
        // CASO 3: Dos PEs piden simultáneamente — PE0 y PE2
        // Flujo esperado: IDLE → ARBITRATE → DECODE → ...
        // Con rr_ptr=0 después de los casos anteriores, PE0 debería ganar
        // Verificar que solo uno de los dos genera snoop
        // ============================================================

        $display("\n--- CASO 3: Arbitraje simultaneo PE0 y PE2 ---");
        // Levantar help de ambos al mismo tiempo sin usar la tarea
        // porque la tarea solo levanta uno a la vez
        request_packet[0] = {1'b1, 5'b00100, 32'h0};       // PE0 lectura
        request_packet[2] = {1'b0, 5'b01100, 32'h12345678}; // PE2 escritura
        help = 4'b0101;   // PE0 y PE2 simultáneos
        @(posedge clk);
        help = 4'b0000;

        // Esperar que el IC pase por ARBITRATE y llegue a SNOOP_ISSUE
        wait_cycles(3);
        $display("  Verificando que exactamente una señal de snoop está activa:");
        if (bus_rd ^ bus_inv)
            $display("  [PASS] Exactamente una señal de snoop activa");
        else
            $display("  [FAIL] Condición de snoop incorrecta bus_rd=%b bus_inv=%b",
                     bus_rd, bus_inv);

        // Esperar que complete
        wait_cycles(8);

        // ============================================================
        // CASO 4: Read Miss seguido inmediatamente de otro request
        // Verifica que el IC no acepta nuevas peticiones mientras está ocupado
        // El segundo request debe esperar a que el IC regrese a IDLE
        // ============================================================

        $display("\n--- CASO 4: Request mientras IC esta ocupado ---");
        // PE3 envía request
        send_request(2'd3, 1'b1, 5'b10000, 32'h0);

        // Inmediatamente PE1 intenta enviar otro request
        // El IC está en DECODE, no en IDLE, así que no debe procesarlo
        request_packet[1] = {1'b1, 5'b00100, 32'h0};
        help[1] = 1'b1;
        @(posedge clk);
        help[1] = 1'b0;

        // Esperar que el primer request complete
        wait_cycles(8);
        $display("  Verificando que IC regreso a IDLE correctamente:");
        // Si ic_ready se activó exactamente una vez el IC manejó un solo request
        check("ic_ready después de request 1", ic_ready, 1'b0);

        wait_cycles(4);

        // ============================================================
        // CASO 5: Verificar que bus_rd y bus_inv se limpian
        // después de un ciclo y no quedan pegados
        // ============================================================

        $display("\n--- CASO 5: Verificar limpieza de señales de snoop ---");
        send_request(2'd0, 1'b0, 5'b00100, 32'hFFFFFFFF);

        // Esperar SNOOP_ISSUE
        wait_cycles(2);
        $display("  En SNOOP_ISSUE:");
        check("bus_inv activo", bus_inv, 1'b1);

        // Un ciclo después debe haberse limpiado
        wait_cycles(1);
        $display("  Ciclo siguiente a SNOOP_ISSUE:");
        check("bus_inv limpio", bus_inv, 1'b0);

        wait_cycles(8);

        // ============================================================
        // Fin del testbench
        // ============================================================

        $display("\n--- Testbench Interconnect_MSI finalizado ---");
        $finish;
    end

    // ----------------------------------------------------------------
    // Monitor continuo: imprime cambios importantes en cada ciclo
    // $monitor se activa automáticamente cuando cualquier señal cambia
    // ----------------------------------------------------------------

    initial begin
        $monitor("[t=%0tns] help=%b bus_rd=%b bus_inv=%b ic_ready=%b mem_we=%b mem_ready=%b",
                 $time, help, bus_rd, bus_inv, ic_ready, mem_we, mem_ready);
    end

endmodule