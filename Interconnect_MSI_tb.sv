`timescale 1ns/1ps

module Interconnect_MSI_tb();

    logic        clk;
    logic        reset;

    logic [3:0]  help;
    logic [37:0] request_packet [3:0];

    logic        bus_rd;
    logic        bus_inv;
    logic        ic_ready;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;

    logic [63:0] mem_data_out;
    logic        mem_ready;

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

    // Generador de reloj
    initial clk = 0;
    always #5 clk = ~clk;

    // Modelo de RAM simplificado
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_data_out <= 64'b0;
            mem_ready    <= 1'b0;
        end else if (mem_we == 1'b0 && mem_address != 5'b0) begin
            mem_data_out <= 64'hDEADBEEFCAFEBABE;
            mem_ready    <= 1'b1;
        end else if (mem_we == 1'b1) begin
            mem_data_out <= 64'b0;
            mem_ready    <= 1'b1;
        end else begin
            mem_data_out <= 64'b0;
            mem_ready    <= 1'b0;
        end
    end

    // Tarea: esperar N ciclos
    task wait_cycles(input int n);
        repeat(n) @(posedge clk);
    endtask

    // Tarea: enviar request de un PE
    task send_request(
        input logic [1:0]  pe_id,
        input logic        op_type,
        input logic [4:0]  addr,
        input logic [31:0] data
    );
        request_packet[pe_id] = {op_type, addr, data};
        help[pe_id] = 1'b1;
        @(posedge clk);
        help[pe_id] = 1'b0;
    endtask

    // Tarea: verificar señal
    task check(
        input string nombre,
        input logic  obtenido,
        input logic  esperado
    );
        if (obtenido === esperado)
            $display("  [PASS] %s = %b", nombre, obtenido);
        else
            $display("  [FAIL] %s = %b, esperado %b", nombre, obtenido, esperado);
    endtask

    initial begin
        // Inicialización
        reset  = 1'b1;
        help   = 4'b0000;
        for (int i = 0; i < 4; i++)
            request_packet[i] = 38'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        // ============================================================
        // CASO 1: Read Miss — PE0 lee dirección 0x04
        // ============================================================
        $display("\n--- CASO 1: Read Miss PE0 (I -> S) ---");
        send_request(2'd0, 1'b1, 5'b00100, 32'h0);

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
        // ============================================================
        $display("\n--- CASO 2: Write Miss PE1 (I -> M) ---");
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
        // CASO 3: Arbitraje simultaneo PE0 y PE2
        // ============================================================
        $display("\n--- CASO 3: Arbitraje simultaneo PE0 y PE2 ---");
        request_packet[0] = {1'b1, 5'b00100, 32'h0};
        request_packet[2] = {1'b0, 5'b01100, 32'h12345678};
        help = 4'b0101;
        @(posedge clk);
        help = 4'b0000;

        wait_cycles(3);
        $display("  Verificando snoop exclusivo:");
        if (bus_rd ^ bus_inv)
            $display("  [PASS] Exactamente una señal de snoop activa");
        else
            $display("  [FAIL] bus_rd=%b bus_inv=%b", bus_rd, bus_inv);

        wait_cycles(8);

        // ============================================================
        // CASO 4: Request mientras IC esta ocupado
        // ============================================================
        $display("\n--- CASO 4: Request mientras IC esta ocupado ---");
        send_request(2'd3, 1'b1, 5'b10000, 32'h0);

        request_packet[1] = {1'b1, 5'b00100, 32'h0};
        help[1] = 1'b1;
        @(posedge clk);
        help[1] = 1'b0;

        wait_cycles(8);
        check("ic_ready limpio tras operacion", ic_ready, 1'b0);
        wait_cycles(4);

        // ============================================================
        // CASO 5: Verificar limpieza de señales de snoop
        // ============================================================
        $display("\n--- CASO 5: Limpieza de señales de snoop ---");
        send_request(2'd0, 1'b0, 5'b00100, 32'hFFFFFFFF);

        wait_cycles(2);
        $display("  En SNOOP_ISSUE:");
        check("bus_inv activo", bus_inv, 1'b1);

        wait_cycles(1);
        $display("  Ciclo siguiente:");
        check("bus_inv limpio", bus_inv, 1'b0);

        wait_cycles(8);

        $display("\n--- Testbench Interconnect_MSI finalizado ---");
        $stop;
    end

    initial begin
        $monitor("[t=%0tns] help=%b bus_rd=%b bus_inv=%b ic_ready=%b mem_we=%b mem_ready=%b",
                 $time, help, bus_rd, bus_inv, ic_ready, mem_we, mem_ready);
    end

endmodule