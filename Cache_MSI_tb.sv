`timescale 1ns/1ps

module Cache_MSI_tb();

    // Reloj y reset
    logic clk;
    logic reset;

    // PE -> Cache
    logic we;
    logic rd;
    logic [4:0] address;
    logic [31:0] data_in;
    logic [31:0] data_out;
    logic stall;

    // Cache -> IC
    logic help;
    logic [37:0] request_packet;
    logic ready_c;
    logic wb_valid;
    logic [63:0] cache_line_c;

    // IC -> Cache
    logic ready;
    logic bus_inv;
    logic bus_rd;
    logic [4:0] snoop_addr;
    logic [1:0] resp_id;
    logic [1:0] ic_tag;
    logic [63:0] ic_data;

    // Debug
    logic [1:0] current_state;
    logic [1:0] current_tag;

    Cache_MSI dut (
        .clk(clk),
        .reset(reset),
        .cache_id(2'd0),
        .we(we),
        .rd(rd),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .stall(stall),
        .help(help),
        .request_packet(request_packet),
        .ready_c(ready_c),
        .wb_valid(wb_valid),
        .cache_line_c(cache_line_c),
        .ready(ready),
        .bus_inv(bus_inv),
        .bus_rd(bus_rd),
        .snoop_addr(snoop_addr),
        .resp_id(resp_id),
        .ic_tag(ic_tag),
        .ic_data(ic_data),
        .current_state(current_state),
        .current_tag(current_tag)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    int errors;
    int checks;

    localparam [1:0] INVALID  = 2'b00;
    localparam [1:0] SHARED   = 2'b01;
    localparam [1:0] MODIFIED = 2'b10;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1;
    endtask

    task automatic check_bit(
        input string name,
        input logic got,
        input logic exp
    );
        checks++;
        if (got === exp) $display("  [PASS] %s = %b", name, got);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", name, got, exp);
        end
    endtask

    task automatic check2(
        input string name,
        input logic [1:0] got,
        input logic [1:0] exp
    );
        checks++;
        if (got === exp) $display("  [PASS] %s = %b", name, got);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", name, got, exp);
        end
    endtask

    task automatic check64(
        input string name,
        input logic [63:0] got,
        input logic [63:0] exp
    );
        checks++;
        if (got === exp) $display("  [PASS] %s = 0x%016h", name, got);
        else begin
            errors++;
            $display("  [FAIL] %s = 0x%016h, esperado 0x%016h", name, got, exp);
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;

        reset = 1'b1;
        we = 1'b0;
        rd = 1'b0;
        address = 5'b0;
        data_in = 32'b0;
        ready = 1'b0;
        bus_inv = 1'b0;
        bus_rd = 1'b0;
        snoop_addr = 5'b0;
        resp_id = 2'b00;
        ic_tag = 2'b0;
        ic_data = 64'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        $display("\n--- CASO 1: Read miss I->S con request a IC ---");
        address = 5'b00100; // tag=00 idx=2 off=0
        rd = 1'b1;
        wait_cycles(1);
        check_bit("help en miss", help, 1'b1);
        check_bit("type=read", request_packet[37], 1'b1);
        check_bit("stall activo", stall, 1'b1);

        wait_cycles(3);
        ic_tag = 2'b00;
        ic_data = {32'hDEAD_BEEF, 32'hCAFE_BABE};
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        rd = 1'b0;
        wait_cycles(1);

        check2("estado tras read miss", current_state, SHARED);
        check_bit("help limpio tras ready", help, 1'b0);

        $display("\n--- CASO 2: Write hit en SHARED pide upgrade (no local M directo) ---");
        address = 5'b00100;
        data_in = 32'h1234_5678;
        we = 1'b1;
        wait_cycles(1);
        check_bit("help en upgrade", help, 1'b1);
        check_bit("type=write", request_packet[37], 1'b0);

        // IC responde con linea base (simula que invalido remotos y le dio ownership)
        wait_cycles(3);
        ic_tag = 2'b00;
        ic_data = {32'hDEAD_BEEF, 32'hCAFE_BABE};
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        we = 1'b0;
        wait_cycles(1);
        check2("estado tras upgrade", current_state, MODIFIED);

        $display("\n--- CASO 3: BusRd sobre linea M genera wb_valid + linea y M->S ---");
        snoop_addr = 5'b00100;
        bus_rd = 1'b1;
        wait_cycles(1);
        bus_rd = 1'b0;
        check_bit("ready_c por snoop", ready_c, 1'b1);
        check_bit("wb_valid activo", wb_valid, 1'b1);
        check64("cache_line_c writeback", cache_line_c, {32'hDEAD_BEEF, 32'h1234_5678});
        wait_cycles(1);
        check2("estado tras bus_rd", current_state, SHARED);

        $display("\n--- CASO 4: BusInv sobre linea valida => INVALID ---");
        snoop_addr = 5'b00100;
        bus_inv = 1'b1;
        wait_cycles(1);
        bus_inv = 1'b0;
        wait_cycles(1);
        check2("estado tras bus_inv", current_state, INVALID);

        $display("\n--- CASO 5: Write hit en MODIFIED se queda local (sin help) ---");
        // Primero hacemos write miss para volver a M
        address = 5'b01000; // tag=01 idx=0 off=0
        data_in = 32'hAAAA_BBBB;
        we = 1'b1;
        wait_cycles(1);
        wait_cycles(3);
        ic_tag = 2'b01;
        ic_data = 64'h1111_2222_3333_4444;
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        wait_cycles(1);
        check2("estado en M", current_state, MODIFIED);

        // Ahora write hit local en M
        data_in = 32'h5555_AAAA;
        we = 1'b1;
        wait_cycles(1);
        we = 1'b0;
        wait_cycles(1);
        check_bit("sin help en write hit M", help, 1'b0);
        check2("sigue en M", current_state, MODIFIED);

        $display("\n--- CASO 6: data_out en miss ya no usa Z interno ---");
        address = 5'b11111; // linea no valida
        rd = 1'b1;
        wait_cycles(1);
        check64("request_packet addr correcto", {59'b0, request_packet[36:32]}, {59'b0, 5'b11111});
        checks++;
        if (^data_out !== 1'bx) $display("  [PASS] data_out definido en miss (no Z)");
        else begin
            errors++;
            $display("  [FAIL] data_out indeterminado en miss");
        end
        rd = 1'b0;

        wait_cycles(2);

        $display("\n=============================================");
        if (errors == 0)
            $display("Cache_MSI_tb: PASS (%0d checks)", checks);
        else
            $display("Cache_MSI_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule
