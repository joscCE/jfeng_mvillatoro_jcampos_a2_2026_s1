`timescale 1ns/1ps

module Cache_ff_tb();

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
    logic bus_rd;
    logic bus_update;
    logic [4:0] snoop_addr;
    logic [1:0] resp_id;
    logic [1:0] ic_tag;
    logic [63:0] ic_data;

    // Debug
    logic [1:0] current_state;
    logic [1:0] current_tag;

    Cache_ff dut (
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
        .bus_rd(bus_rd),
        .bus_update(bus_update),
        .snoop_addr(snoop_addr),
        .resp_id(resp_id),
        .ic_tag(ic_tag),
        .ic_data(ic_data),
        .current_state(current_state),
        .current_tag(current_tag)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    int errors;
    int checks;

    localparam [1:0] VALID   = 2'b00;
    localparam [1:0] SHARED  = 2'b01;
    localparam [1:0] INVALID = 2'b11;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1;
    endtask

    task automatic check_bit(input string n, input logic g, input logic e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", n, g, e);
        end
    endtask

    task automatic check2(input string n, input logic [1:0] g, input logic [1:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin
            errors++;
            $display("  [FAIL] %s = %b, esperado %b", n, g, e);
        end
    endtask

    task automatic check32(input string n, input logic [31:0] g, input logic [31:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = 0x%08h", n, g);
        else begin
            errors++;
            $display("  [FAIL] %s = 0x%08h, esperado 0x%08h", n, g, e);
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
        bus_rd = 1'b0;
        bus_update = 1'b0;
        snoop_addr = 5'b0;
        resp_id = 2'b0;
        ic_tag = 2'b0;
        ic_data = 64'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        $display("\n--- CASO 1: Read miss levanta request y consume respuesta valida ---");
        address = 5'b00100;
        rd = 1'b1;
        wait_cycles(1);
        check_bit("help en miss", help, 1'b1);
        check_bit("type=read", request_packet[37], 1'b1);
        check_bit("stall activo", stall, 1'b1);

        wait_cycles(3);
        ic_tag = 2'b00;
        ic_data = {32'h1111_2222, 32'h3333_4444};
        resp_id = 2'd0;
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        rd = 1'b0;
        wait_cycles(1);
        check2("estado tras read miss", current_state, SHARED);
        check_bit("help limpio", help, 1'b0);

        $display("\n--- CASO 2: resp_id incorrecto NO debe consumir request ---");
        address = 5'b01000;
        rd = 1'b1;
        wait_cycles(2);
        resp_id = 2'd1;
        ic_tag = 2'b01;
        ic_data = 64'hAAAA_BBBB_CCCC_DDDD;
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        wait_cycles(1);
        check_bit("sigue pendiente con resp_id incorrecto", help, 1'b1);

        resp_id = 2'd0;
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        rd = 1'b0;
        wait_cycles(1);
        check_bit("pendiente liberado con resp_id correcto", help, 1'b0);

        $display("\n--- CASO 3: Write hit en SHARED pide update al bus ---");
        address = 5'b00100;
        data_in = 32'hDEAD_BEEF;
        we = 1'b1;
        wait_cycles(1);
        check_bit("help en write hit SHARED", help, 1'b1);
        check_bit("type=write", request_packet[37], 1'b0);
        wait_cycles(3);
        resp_id = 2'd0;
        ic_tag = 2'b00;
        ic_data = {32'h1111_2222, 32'h3333_4444};
        ready = 1'b1;
        wait_cycles(1);
        ready = 1'b0;
        we = 1'b0;
        wait_cycles(1);
        check2("estado tras write update", current_state, SHARED);

        $display("\n--- CASO 4: Snoop update remoto actualiza palabra y ack ---");
        snoop_addr = 5'b00100;
        ic_data = {32'h0000_0000, 32'hCAFE_BABE};
        bus_update = 1'b1;
        wait_cycles(1);
        bus_update = 1'b0;
        check_bit("ready_c por bus_update", ready_c, 1'b1);
        check_bit("wb_valid se mantiene en 0", wb_valid, 1'b0);

        // Leemos para comprobar dato actualizado
        address = 5'b00100;
        rd = 1'b1;
        wait_cycles(1);
        rd = 1'b0;
        check32("dato tras bus_update", data_out, 32'hCAFE_BABE);

        $display("\n--- CASO 5: BusRd remoto mantiene linea en SHARED ---");
        snoop_addr = 5'b00100;
        bus_rd = 1'b1;
        wait_cycles(1);
        bus_rd = 1'b0;
        check_bit("ready_c por bus_rd", ready_c, 1'b1);
        check2("estado tras bus_rd", current_state, SHARED);

        // Sanidad de reset inicial
        address = 5'b11111;
        rd = 1'b1;
        wait_cycles(1);
        checks++;
        if (^data_out !== 1'bx) $display("  [PASS] data_out definido en miss");
        else begin
            errors++;
            $display("  [FAIL] data_out indefinido en miss");
        end
        rd = 1'b0;

        wait_cycles(2);

        $display("\n=============================================");
        if (errors == 0)
            $display("Cache_ff_tb: PASS (%0d checks)", checks);
        else
            $display("Cache_ff_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule
