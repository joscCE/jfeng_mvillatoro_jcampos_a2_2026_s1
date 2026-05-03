`timescale 1ns/1ps

module Interconnect_FF_tb();

    logic        clk;
    logic        reset;

    // Cache -> IC
    logic [3:0]  help;
    logic [37:0] request_packet [3:0];
    logic [3:0]  ready_c;

    // IC -> cache
    logic        ic_ready;
    logic        bus_inv;
    logic        bus_rd;
    logic        bus_update;
    logic [1:0]  resp_id;
    logic [4:0]  snoop_addr;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    // IC <-> RAM
    logic        mem_req;
    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;
    logic [63:0] mem_data_out;
    logic        mem_ready;

    Interconnect_FF dut (
        .clk(clk),
        .reset(reset),
        .help(help),
        .request_packet(request_packet),
        .ready_c(ready_c),
        .ic_ready(ic_ready),
        .bus_inv(bus_inv),
        .bus_rd(bus_rd),
        .bus_update(bus_update),
        .resp_id(resp_id),
        .snoop_addr(snoop_addr),
        .ic_tag(ic_tag),
        .ic_cache_line(ic_cache_line),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_address(mem_address),
        .mem_data_in(mem_data_in),
        .mem_data_out(mem_data_out),
        .mem_ready(mem_ready)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // RAM model simple
    logic [63:0] ram [0:3];
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_data_out <= 64'b0;
            mem_ready    <= 1'b0;
            ram[0]       <= 64'h0101_0101_1111_1111;
            ram[1]       <= 64'h0202_0202_2222_2222;
            ram[2]       <= 64'h0303_0303_3333_3333;
            ram[3]       <= 64'h0404_0404_4444_4444;
        end else begin
            mem_ready <= 1'b0;
            if (mem_req) begin
                if (mem_we) ram[mem_address[2:1]] <= mem_data_in;
                mem_data_out <= ram[mem_address[2:1]];
                mem_ready <= 1'b1;
            end
        end
    end

    // Todos los caches responden al snoop en el mismo ciclo
    always_comb begin
        if (bus_rd || bus_update)
            ready_c = 4'b1111;
        else
            ready_c = 4'b0000;
    end

    int errors;
    int checks;

    task automatic wait_cycles(input int n);
        repeat(n) @(posedge clk);
        #1;
    endtask

    task automatic send_req(
        input logic [1:0] pe,
        input logic type_read,
        input logic [4:0] addr,
        input logic [31:0] data
    );
        request_packet[pe] = {type_read, addr, data};
        help[pe] = 1'b1;
        @(posedge clk);
        #1;
        help[pe] = 1'b0;
    endtask

    task automatic check_bit(input string n, input logic g, input logic e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin errors++; $display("  [FAIL] %s = %b, esperado %b", n, g, e); end
    endtask

    task automatic check2(input string n, input logic [1:0] g, input logic [1:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = %b", n, g);
        else begin errors++; $display("  [FAIL] %s = %b, esperado %b", n, g, e); end
    endtask

    task automatic check64(input string n, input logic [63:0] g, input logic [63:0] e);
        checks++;
        if (g === e) $display("  [PASS] %s = 0x%016h", n, g);
        else begin errors++; $display("  [FAIL] %s = 0x%016h, esperado 0x%016h", n, g, e); end
    endtask

    task automatic wait_ready(input int maxc);
        int c;
        c = 0;
        while (ic_ready !== 1'b1 && c < maxc) begin
            @(posedge clk);
            #1;
            c++;
        end
        if (ic_ready !== 1'b1) begin
            errors++;
            $display("  [FAIL] timeout esperando ic_ready");
        end
    endtask

    initial begin
        errors = 0;
        checks = 0;
        reset = 1'b1;
        help = 4'b0;
        for (int i = 0; i < 4; i++) request_packet[i] = 38'b0;

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        $display("\n--- CASO 1: Read miss PE0 ---");
        send_req(2'd0, 1'b1, 5'b00010, 32'h0);
        wait_cycles(2);
        check_bit("bus_rd", bus_rd, 1'b1);
        check_bit("bus_update", bus_update, 1'b0);
        check_bit("bus_inv", bus_inv, 1'b0);
        check2("resp_id", resp_id, 2'd0);
        check2("ic_tag", ic_tag, 2'b00);
        wait_ready(20);
        check64("ic_cache_line desde RAM", ic_cache_line, 64'h0202_0202_2222_2222);
        @(posedge clk); #1;
        check_bit("ic_ready uniciclo", ic_ready, 1'b0);

        $display("\n--- CASO 2: Write miss PE1 con write-update ---");
        send_req(2'd1, 1'b0, 5'b01001, 32'hAABB_CCDD);
        wait_cycles(2);
        check_bit("bus_rd activo", bus_rd, 1'b1);
        check_bit("bus_update activo", bus_update, 1'b1);
        check_bit("bus_inv sigue en 0", bus_inv, 1'b0);
        check2("resp_id write", resp_id, 2'd1);
        check64("payload write-update", ic_cache_line, {32'hAABB_CCDD, 32'h0});

        begin
            int saw_req;
            int saw_we;
            saw_req = 0;
            saw_we = 0;
            for (int k = 0; k < 25; k++) begin
                @(posedge clk); #1;
                if (mem_req) begin
                    saw_req++;
                    if (mem_we) saw_we = 1;
                end
                if (ic_ready) break;
            end
            checks++;
            if (saw_req == 1) $display("  [PASS] mem_req uniciclo");
            else begin errors++; $display("  [FAIL] mem_req aparecio %0d ciclos", saw_req); end
            checks++;
            if (saw_we == 1) $display("  [PASS] mem_we asertado en write");
            else begin errors++; $display("  [FAIL] mem_we no asertado en write"); end
        end

        wait_ready(20);
        @(posedge clk); #1;
        check_bit("ic_ready limpio", ic_ready, 1'b0);

        $display("\n--- CASO 3: Arbitraje con 2 requests simultaneos ---");
        request_packet[0] = {1'b1, 5'b00110, 32'h0};
        request_packet[3] = {1'b1, 5'b10000, 32'h0};
        help = 4'b1001;
        @(posedge clk); #1;
        wait_ready(20);
        checks++;
        $display("  [PASS] primera respuesta recibida");

        // Se mantiene el otro help en alto para que el IC tome la segunda peticion
        help[resp_id] = 1'b0;
        @(posedge clk); #1;
        wait_ready(20);
        checks++;
        $display("  [PASS] segunda respuesta recibida");
        help = 4'b0000;

        wait_cycles(2);

        $display("\n=============================================");
        if (errors == 0)
            $display("Interconnect_FF_tb: PASS (%0d checks)", checks);
        else
            $display("Interconnect_FF_tb: FAIL (%0d/%0d checks)", errors, checks);
        $display("=============================================\n");
        $stop;
    end

endmodule
