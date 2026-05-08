`timescale 1ns/1ps

module Interconnect_MSI_double_service_tb;

    logic        clk;
    logic        reset;

    // Cache -> IC
    logic [3:0]  help;
    logic [37:0] request_packet [3:0];
    logic [3:0]  ready_c;
    logic [3:0]  wb_valid;
    logic [63:0] cache_line_c [3:0];

    // IC Broadcast
    logic        ic_ready;
    logic        bus_inv;
    logic        bus_rd;
    logic [1:0]  resp_id;
    logic [4:0]  snoop_addr;
    logic [1:0]  ic_tag;
    logic [63:0] ic_cache_line;

    // IC -> memoria
    logic        mem_req;
    logic        mem_we;
    logic [4:0]  mem_address;
    logic [63:0] mem_data_in;

    // memoria -> IC
    logic [63:0] mem_data_out;
    logic        mem_ready;

    Interconnect_MSI dut (
        .clk(clk),
        .reset(reset),
        .help(help),
        .request_packet(request_packet),
        .ready_c(ready_c),
        .wb_valid(wb_valid),
        .cache_line_c(cache_line_c),
        .ic_ready(ic_ready),
        .bus_inv(bus_inv),
        .bus_rd(bus_rd),
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

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // RAM simple
    logic [63:0] ram [0:31];
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_ready    <= 1'b0;
            mem_data_out <= 64'h0;
            for (int i = 0; i < 32; i++) begin
                ram[i] <= 64'h1000_0000_0000_0000 + i;
            end
        end else begin
            mem_ready <= 1'b0;
            if (mem_req) begin
                if (mem_we)
                    ram[mem_address] <= mem_data_in;
                mem_data_out <= ram[mem_address];
                mem_ready    <= 1'b1;
            end
        end
    end

    // Caches remotos (1,2,3) siempre ack cuando hay broadcast
    always_comb begin
        ready_c = 4'b0000;
        wb_valid = 4'b0000;
        for (int j = 0; j < 4; j++) begin
            cache_line_c[j] = 64'h0;
        end

        if (bus_inv || bus_rd) begin
            ready_c = 4'b1110; // requester es cache0
        end
    end

    int resp_count;
    int inv_rise_count;
    int mem_req_rise_count;
    logic bus_inv_d;
    logic mem_req_d;

    // Modelo requester (cache0): baja help al recibir su respuesta
    always_ff @(posedge clk) begin
        if (reset) begin
            help[0] <= 1'b0;
        end else begin
            if (ic_ready && (resp_id == 2'd0))
                help[0] <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            resp_count <= 0;
            inv_rise_count <= 0;
            mem_req_rise_count <= 0;
            bus_inv_d <= 1'b0;
            mem_req_d <= 1'b0;
        end else begin
            if (ic_ready && (resp_id == 2'd0))
                resp_count <= resp_count + 1;

            if (bus_inv && !bus_inv_d)
                inv_rise_count <= inv_rise_count + 1;

            if (mem_req && !mem_req_d)
                mem_req_rise_count <= mem_req_rise_count + 1;

            bus_inv_d <= bus_inv;
            mem_req_d <= mem_req;
        end
    end

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk);
        #1;
    endtask

    initial begin
        // defaults
        reset = 1'b1;
        help = 4'b0000;
        for (int k = 0; k < 4; k++) begin
            request_packet[k] = 38'h0;
        end

        wait_cycles(3);
        reset = 1'b0;
        wait_cycles(1);

        // Caso objetivo: write miss de cache0
        // Sin fix, suele verse double-servicing (2 respuestas para 1 solicitud)
        request_packet[0] = {1'b0, 5'd6, 32'hDEAD_BEEF};
        help[0] = 1'b1;

        wait_cycles(30);

        $display("\n--- Double-servicing regression check ---");
        $display("resp_count         = %0d", resp_count);
        $display("inv_rise_count     = %0d", inv_rise_count);
        $display("mem_req_rise_count = %0d", mem_req_rise_count);

        if (resp_count != 1) begin
            $display("[FAIL] resp_count esperado=1, obtenido=%0d", resp_count);
            $fatal(1);
        end

        if (inv_rise_count != 1) begin
            $display("[FAIL] inv_rise_count esperado=1, obtenido=%0d", inv_rise_count);
            $fatal(1);
        end

        if (mem_req_rise_count != 1) begin
            $display("[FAIL] mem_req_rise_count esperado=1, obtenido=%0d", mem_req_rise_count);
            $fatal(1);
        end

        $display("[PASS] Interconnect_MSI_double_service_tb");
        $finish;
    end

endmodule
