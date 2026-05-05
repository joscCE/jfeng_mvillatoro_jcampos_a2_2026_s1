`timescale 1ns/1ps

module Top (
    input  logic        clk,
    input  logic        reset,

    // --- Interfaz Procesadores MSI (4 PEs) ---
    input  logic [3:0]  msi_pe_we,
    input  logic [3:0]  msi_pe_rd,
    input  logic [4:0]  msi_pe_addr [3:0],
    input  logic [31:0] msi_pe_data_in [3:0],
    output logic [31:0] msi_pe_data_out [3:0],
    output logic [3:0]  msi_pe_stall,
    output logic [1:0]  msi_cache_state [3:0],

    // --- Interfaz Procesadores Firefly (4 PEs) ---
    input  logic [3:0]  ff_pe_we,
    input  logic [3:0]  ff_pe_rd,
    input  logic [4:0]  ff_pe_addr [3:0],
    input  logic [31:0] ff_pe_data_in [3:0],
    output logic [31:0] ff_pe_data_out [3:0],
    output logic [3:0]  ff_pe_stall,
    output logic [1:0]  ff_cache_state [3:0]
);

    // =========================================================
    // Señales Internas MSI (Extraídas del TB masivo)[cite: 1]
    // =========================================================
    logic [3:0]  msi_help;
    logic [37:0] msi_request_packet [3:0];
    logic [3:0]  msi_ready_c;
    logic [3:0]  msi_wb_valid;
    logic [63:0] msi_cache_line_c [3:0];

    logic        msi_ic_ready;
    logic        msi_bus_inv;
    logic        msi_bus_rd;
    logic [1:0]  msi_resp_id;
    logic [4:0]  msi_snoop_addr;
    logic [1:0]  msi_ic_tag;
    logic [63:0] msi_ic_cache_line;

    logic        msi_mem_req;
    logic        msi_mem_we;
    logic [4:0]  msi_mem_address;
    logic [63:0] msi_mem_data_in;
    logic [63:0] msi_mem_data_out;
    logic        msi_mem_ready;

    // =========================================================
    // Señales Internas Firefly (Extraídas del TB masivo)[cite: 1]
    // =========================================================
    logic [3:0]  ff_help;
    logic [37:0] ff_request_packet [3:0];
    logic [3:0]  ff_ready_c;
    logic [63:0] ff_cache_line_c [3:0];

    logic        ff_ic_ready;
    logic        ff_bus_inv; // No usado activamente en FF pero presente en interconexión
    logic        ff_bus_rd;
    logic        ff_bus_update;
    logic [1:0]  ff_resp_id;
    logic [4:0]  ff_snoop_addr;
    logic [1:0]  ff_ic_tag;
    logic [63:0] ff_ic_cache_line;

    logic        ff_mem_req;
    logic        ff_mem_we;
    logic [4:0]  ff_mem_address;
    logic [63:0] ff_mem_data_in;
    logic [63:0] ff_mem_data_out;
    logic        ff_mem_ready;

    // =========================================================
    // Instanciación del Sistema MSI
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : g_msi_system
            Cache_MSI u_cache_msi (
                .clk(clk), .reset(reset), .cache_id(i[1:0]),
                .we(msi_pe_we[i]), .rd(msi_pe_rd[i]),
                .address(msi_pe_addr[i]), .data_in(msi_pe_data_in[i]),
                .data_out(msi_pe_data_out[i]), .stall(msi_pe_stall[i]),
                .help(msi_help[i]), .request_packet(msi_request_packet[i]),
                .ready_c(msi_ready_c[i]), .wb_valid(msi_wb_valid[i]),
                .cache_line_c(msi_cache_line_c[i]), .ready(msi_ic_ready),
                .bus_inv(msi_bus_inv), .bus_rd(msi_bus_rd), .snoop_addr(msi_snoop_addr),
                .resp_id(msi_resp_id), .ic_tag(msi_ic_tag), .ic_data(msi_ic_cache_line),
                .current_state(msi_cache_state[i]), .current_tag()
            );
        end
    endgenerate

    Interconnect_MSI u_ic_msi (
        .clk(clk), .reset(reset), .help(msi_help), .request_packet(msi_request_packet),
        .ready_c(msi_ready_c), .wb_valid(msi_wb_valid), .cache_line_c(msi_cache_line_c),
        .ic_ready(msi_ic_ready), .bus_inv(msi_bus_inv), .bus_rd(msi_bus_rd),
        .resp_id(msi_resp_id), .snoop_addr(msi_snoop_addr), .ic_tag(msi_ic_tag),
        .ic_cache_line(msi_ic_cache_line), .mem_req(msi_mem_req), .mem_we(msi_mem_we),
        .mem_address(msi_mem_address), .mem_data_in(msi_mem_data_in),
        .mem_data_out(msi_mem_data_out), .mem_ready(msi_mem_ready)
    );

    Ram u_ram_msi (
        .clk(clk), .reset(reset), .req(msi_mem_req), .we(msi_mem_we),
        .address(msi_mem_address), .data_in(msi_mem_data_in),
        .data_out(msi_mem_data_out), .mem_ready(msi_mem_ready)
    );

    // =========================================================
    // Instanciación del Sistema Firefly
    // =========================================================
    generate
        for (i = 0; i < 4; i++) begin : g_ff_system
            Cache_ff u_cache_ff (
                .clk(clk), .reset(reset), .cache_id(i[1:0]),
                .we(ff_pe_we[i]), .rd(ff_pe_rd[i]),
                .address(ff_pe_addr[i]), .data_in(ff_pe_data_in[i]),
                .data_out(ff_pe_data_out[i]), .stall(ff_pe_stall[i]),
                .help(ff_help[i]), .request_packet(ff_request_packet[i]),
                .ready_c(ff_ready_c[i]), .wb_valid(), // Firefly no usa wb_valid explícito aquí
                .cache_line_c(ff_cache_line_c[i]), .ready(ff_ic_ready),
                .bus_rd(ff_bus_rd), .bus_update(ff_bus_update), .snoop_addr(ff_snoop_addr),
                .resp_id(ff_resp_id), .ic_tag(ff_ic_tag), .ic_data(ff_ic_cache_line),
                .current_state(ff_cache_state[i]), .current_tag()
            );
        end
    endgenerate

    Interconnect_FF u_ic_ff (
        .clk(clk), .reset(reset), .help(ff_help), .request_packet(ff_request_packet),
        .ready_c(ff_ready_c), .ic_ready(ff_ic_ready), .bus_inv(ff_bus_inv),
        .bus_rd(ff_bus_rd), .bus_update(ff_bus_update), .resp_id(ff_resp_id),
        .snoop_addr(ff_snoop_addr), .ic_tag(ff_ic_tag), .ic_cache_line(ff_ic_cache_line),
        .mem_req(ff_mem_req), .mem_we(ff_mem_we), .mem_address(ff_mem_address),
        .mem_data_in(ff_mem_data_in), .mem_data_out(ff_mem_data_out), .mem_ready(ff_mem_ready)
    );

    Ram u_ram_ff (
        .clk(clk), .reset(reset), .req(ff_mem_req), .we(ff_mem_we),
        .address(ff_mem_address), .data_in(ff_mem_data_in),
        .data_out(ff_mem_data_out), .mem_ready(ff_mem_ready)
    );

endmodule