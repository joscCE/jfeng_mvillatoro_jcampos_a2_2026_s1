`timescale 1ns/1ps

module Coherence_Integration_Full_tb();

    // Señales Globales
    logic clk;
    logic rst;

    // --- Señales de los PEs ---
    // Usamos arreglos para conectar los 4 núcleos fácilmente
    logic [3:0]  pe_done;
    logic [3:0]  pe_req_valid;
    logic [3:0]  pe_req_type;
    logic [4:0]  pe_addr [3:0];
    logic [31:0] pe_data_in [3:0];
    logic [31:0] pe_data_out [3:0]; // Datos que regresan de la cache
    logic [3:0]  pe_finished;

    // --- Señales de la Interconexión (Protocolo Firefly como ejemplo) ---
    logic [3:0]  ic_help;
    logic [37:0] ic_req_packet [3:0];
    logic [3:0]  ic_ready_c;
    logic        ic_ready;
    logic        bus_rd, bus_update, bus_inv;
    logic [1:0]  resp_id;
    logic [4:0]  snoop_addr;
    logic [63:0] ic_data_bus;

    // --- Señales de RAM ---
    logic        mem_req, mem_we, mem_ready;
    logic [4:0]  mem_addr;
    logic [63:0] mem_data_to_ram, mem_data_from_ram;

    localparam string TRACE_FILES [4] = '{"trace0.mif", "trace1.mif", "trace2.mif", "trace3.mif"};

    // Generador de Reloj (100MHz)[cite: 3]
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================
    // INSTANCIACIÓN DEL SISTEMA (DUT)
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_cores
            // Instancia del procesador que lee trazas[cite: 1, 3]
            PE u_pe (
                .clk(clk),
                .rst(rst),
                .done(pe_done[i]),       // Señal de "listo" desde la cache
                .req_valid(pe_req_valid[i]),
                .req_type(pe_req_type[i]),
                .addr(pe_addr[i]),
                .data(pe_data_in[i]),
                .finished(pe_finished[i])
            );

            // Instancia de la Cache[cite: 2]
            // Nota: Se asume lógica de Firefly. Si es MSI, ajusta los puertos.
            Cache_ff u_cache (
                .clk(clk),
                .reset(rst),
                .cache_id(i[1:0]),
                .we(pe_req_type[i]),
                .rd(pe_req_valid[i] && !pe_req_type[i]),
                .address(pe_addr[i]),
                .data_in(pe_data_in[i]),
                .data_out(pe_data_out[i]),
                .stall(pe_done[i]),      // Control de flujo para el PE[cite: 3]
                
                .help(ic_help[i]),
                .request_packet(ic_req_packet[i]),
                .ready_c(ic_ready_c[i]),
                
                .ready(ic_ready),
                .bus_rd(bus_rd),
                .bus_update(bus_update),
                .snoop_addr(snoop_addr),
                .resp_id(resp_id),
                .ic_data(ic_data_bus),
                
                .current_state(),
                .current_tag()
            );
        end
    endgenerate

    // Interconexión Centralizada[cite: 2]
    Interconnect_FF u_ic (
        .clk(clk),
        .reset(rst),
        .help(ic_help),
        .request_packet(ic_req_packet),
        .ready_c(ic_ready_c),
        .ic_ready(ic_ready),
        .bus_rd(bus_rd),
        .bus_update(bus_update),
        .bus_inv(bus_inv),
        .resp_id(resp_id),
        .snoop_addr(snoop_addr),
        .ic_cache_line(ic_data_bus),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_address(mem_addr),
        .mem_data_in(mem_data_to_ram),
        .mem_data_out(mem_data_from_ram),
        .mem_ready(mem_ready)
    );

    // Memoria RAM compartida[cite: 2]
    Ram u_ram (
        .clk(clk),
        .reset(rst),
        .req(mem_req),
        .we(mem_we),
        .address(mem_addr),
        .data_in(mem_data_to_ram),
        .data_out(mem_data_from_ram),
        .mem_ready(mem_ready)
    );

    // =========================================================
    // LÓGICA DE CONTROL Y MONITOREO
    // =========================================================
    initial begin
        // Inicialización[cite: 3]
        rst = 1;
        $display("[%t] ---- Iniciando Integracion PE->Cache->IC->RAM ----", $time);

        // Reset del sistema
        #50;
        rst = 0;

        // Monitoreo de actividad en consola[cite: 3]
        forever begin
            @(posedge clk);
            for (int j = 0; j < 4; j++) begin
                if (pe_req_valid[j] && !pe_done[j]) begin
                    $display("[%t] Core %0d solicita: %s en Dir: %0d con Dato: %h", 
                        $time, j, (pe_req_type[j] ? "WRITE" : "READ"), pe_addr[j], pe_data_in[j]);
                end
            end
        end
    end

    // Finalización automática basada en el estado de los 4 PEs[cite: 3]
    initial begin
        wait(pe_finished == 4'b1111);
        $display("[%t] ---- TODOS LOS CORES FINALIZARON (FIN detectado) ----", $time);
        #100;
        $finish;
    end

endmodule