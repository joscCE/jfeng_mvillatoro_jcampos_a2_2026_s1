module Interconnect_MSI #(
    parameter int SNOOP_WAIT_CYCLES = 4
)(
    input logic        clk,
    input logic        reset,

    // Cache -> IC
    input logic [3:0]  help,
    input logic [37:0] request_packet [3:0],
    input logic [3:0]  ready_c,
    input logic [3:0]  wb_valid,
    input logic [63:0] cache_line_c [3:0],

    // IC Broadcast
    output logic        ic_ready,
    output logic        bus_inv,
    output logic        bus_rd,
    output logic [1:0]  resp_id,
    output logic [4:0]  snoop_addr,
    output logic [1:0]  ic_tag,
    output logic [63:0] ic_cache_line,

    // IC -> memoria
    output logic        mem_req,
    output logic        mem_we,
    output logic [4:0]  mem_address,
    output logic [63:0] mem_data_in,

    // memoria -> IC
    input logic [63:0] mem_data_out,
    input logic        mem_ready
);

    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        SNOOP_ISSUE = 3'b001,
        WAIT_SNOOP  = 3'b010,
        MEM_ACCESS  = 3'b011,
        RESPOND     = 3'b100
    } state_t;

    state_t current_state, next_state;

    // =====================================================
    // internos
    // =====================================================

    logic        req_type;
    logic [4:0]  req_address;

    logic [63:0] owner_line;
    logic        owner_found;

    logic        mem_cmd_issued;
    logic        use_owner_line_in_respond;

    logic [1:0] rr_ptr;
    logic [1:0] winner;
    logic [1:0] selected_winner;

    // Double-servicing fix: skip one IDLE cycle after serving a cache
    // so its 'help' has time to de-assert before we sample again.
    logic        skip_cycle;
    logic [1:0]  last_served;

    logic [3:0] snoop_pending;
    logic       all_ready_c;
    logic [3:0] help_masked;
    logic [1:0] rr_ptr_safe;

    assign all_ready_c = (snoop_pending == 4'b0000);

    // If rr_ptr is ever unknown in simulation, fall back to 0 so RR can recover.
    assign rr_ptr_safe = (^rr_ptr === 1'bx) ? 2'd0 : rr_ptr;

    // Build masked help robustly (avoid ternary X-propagation when skip_cycle is X).
    always_comb begin
        help_masked = help;
        if (skip_cycle === 1'b1)
            help_masked[last_served] = 1'b0;
    end

    // =====================================================
    // combinacional RR
    // =====================================================

    always_comb begin

        selected_winner = rr_ptr_safe;

        if (help_masked[rr_ptr_safe])
            selected_winner = rr_ptr_safe;

        else if (help_masked[(rr_ptr_safe + 2'd1) & 2'b11])
            selected_winner = (rr_ptr_safe + 2'd1) & 2'b11;

        else if (help_masked[(rr_ptr_safe + 2'd2) & 2'b11])
            selected_winner = (rr_ptr_safe + 2'd2) & 2'b11;

        else if (help_masked[(rr_ptr_safe + 2'd3) & 2'b11])
            selected_winner = (rr_ptr_safe + 2'd3) & 2'b11;

    end

    // =====================================================
    // FSM state
    // =====================================================

    always_ff @(posedge clk) begin
        if (reset)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end
    // =====================================================
    // FSM next state
    // =====================================================
    always_comb begin
        next_state = current_state;

        case (current_state)

            IDLE: begin
                if (skip_cycle)
                    next_state = IDLE;
                else if (help_masked != 4'b0000)
                    next_state = SNOOP_ISSUE;
            end

            SNOOP_ISSUE: begin
                next_state = WAIT_SNOOP;
            end

            WAIT_SNOOP: begin
                if (all_ready_c)
                    next_state = MEM_ACCESS;
            end

            MEM_ACCESS: begin
                if (mem_ready)
                    next_state = RESPOND;
            end

            RESPOND: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    // =====================================================
    // MAIN
    // =====================================================

    always_ff @(posedge clk) begin

        if (reset) begin

            bus_rd <= 1'b0;
            bus_inv <= 1'b0;
            ic_ready <= 1'b0;

            resp_id <= 2'b0;
            snoop_addr <= 5'b0;
            ic_tag <= 2'b0;
            ic_cache_line <= 64'b0;

            mem_req <= 1'b0;
            mem_we <= 1'b0;
            mem_address <= 5'b0;
            mem_data_in <= 64'b0;

            req_type <= 1'b0;
            req_address <= 5'b0;

            owner_line <= 64'b0;
            owner_found <= 1'b0;

            mem_cmd_issued <= 1'b0;
            use_owner_line_in_respond <= 1'b0;

            rr_ptr <= 2'b0;
            winner <= 2'b0;
            skip_cycle  <= 1'b0;
            last_served <= 2'b0;

            snoop_pending <= 4'b0000;
        end
        else begin
            // defaults
            ic_ready <= 1'b0;
            mem_req <= 1'b0;
            mem_we <= 1'b0;

            case (current_state)

                // =========================================
                // IDLE
                // =========================================

                IDLE: begin

                    bus_inv <= 1'b0;
                    bus_rd <= 1'b0;

                    owner_found <= 1'b0;
                    owner_line <= 64'b0;

                    mem_cmd_issued <= 1'b0;
                    use_owner_line_in_respond <= 1'b0;

                    snoop_pending <= 4'b0000;

                    if (skip_cycle) begin
                        // Burn one cycle so the just-served cache's 'help'
                        // de-asserts before we sample help again.
                        skip_cycle <= 1'b0;
                    end else if (help_masked != 4'b0000) begin

                        winner <= selected_winner;

                        req_type <= request_packet[selected_winner][37];

                        req_address <=
                            request_packet[selected_winner][36:32];

                        resp_id <= selected_winner;

                        snoop_addr <=
                            request_packet[selected_winner][36:32];

                        rr_ptr <= selected_winner + 2'd1;

                    end

                end

                // =========================================
                // SNOOP_ISSUE
                // =========================================

                SNOOP_ISSUE: begin

                    snoop_pending <= ~(4'b0001 << winner);

                    if (req_type == 1'b0)
                        bus_inv <= 1'b1;
                    else
                        bus_rd <= 1'b1;

                    snoop_addr <= req_address;

                end

                // =========================================
                // WAIT_SNOOP
                // =========================================

                WAIT_SNOOP: begin

                    // mantener bus activo
                    if (req_type == 1'b0)
                        bus_inv <= 1'b1;
                    else
                        bus_rd <= 1'b1;

                    // limpiar caches que respondieron
                    snoop_pending <= snoop_pending & ~ready_c;

                    // capturar owner
                    if (wb_valid != 4'b0000) begin

                        if (wb_valid[0]) begin
                            owner_found <= 1'b1;
                            owner_line <= cache_line_c[0];
                        end
                        else if (wb_valid[1]) begin
                            owner_found <= 1'b1;
                            owner_line <= cache_line_c[1];
                        end
                        else if (wb_valid[2]) begin
                            owner_found <= 1'b1;
                            owner_line <= cache_line_c[2];
                        end
                        else begin
                            owner_found <= 1'b1;
                            owner_line <= cache_line_c[3];
                        end

                    end

                    if (all_ready_c) begin
                        bus_inv <= 1'b0;
                        bus_rd <= 1'b0;
                    end

                end

                // =========================================
                // MEM_ACCESS
                // =========================================

                MEM_ACCESS: begin

                    bus_inv <= 1'b0;
                    bus_rd <= 1'b0;

                    if (!mem_cmd_issued) begin

                        mem_req <= 1'b1;

                        mem_address <= req_address;

                        if (owner_found) begin

                            mem_we <= 1'b1;
                            mem_data_in <= owner_line;

                            use_owner_line_in_respond <= 1'b1;

                        end
                        else begin

                            mem_we <= 1'b0;

                            use_owner_line_in_respond <= 1'b0;

                        end

                        mem_cmd_issued <= 1'b1;

                    end

                end

                // =========================================
                // RESPOND
                // =========================================

                RESPOND: begin

                    ic_ready <= 1'b1;

                    ic_tag <= req_address[4:3];

                    if (use_owner_line_in_respond)
                        ic_cache_line <= owner_line;
                    else
                        ic_cache_line <= mem_data_out;

                    mem_cmd_issued <= 1'b0;

                    // Arm skip so IDLE burns one cycle before re-sampling help.
                    // This gives the served cache time to clear its 'pending'
                    // and de-assert 'help', preventing double-servicing.
                    skip_cycle  <= 1'b1;
                    last_served <= winner;

                end

            endcase
        end
    end

endmodule