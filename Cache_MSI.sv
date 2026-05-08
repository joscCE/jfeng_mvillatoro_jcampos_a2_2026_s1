module Cache_MSI(
    input logic clk,                // Reloj
    input logic reset,              // Reset 
    input logic [1:0] cache_id,     // ID del cache (0 a 3)
    input logic we,                 // Escritura desde PE
    input logic rd,                 // Lectura desde PE
    input logic [4:0] address,      // Dirección de acceso desde PE
    input logic [31:0] data_in,     // Datos de escritura desde PE
    output logic [31:0] data_out,   // Datos de lectura hacia PE
    output logic stall,             // Señal de stall hacia PElete

    // Cache -> IC
    output logic help,
    output logic [37:0] request_packet,     // {type[1], address[5], data[32]}
    output logic ready_c,                   // Acknowledge de snoop
    output logic wb_valid,                  // Valida write-back de línea
    output logic [63:0] cache_line_c,       // Datos de línea para write-back

    // IC -> Cache
    input logic ready,              // Respuesta a request (hit/miss)
    input logic bus_inv,            // Señal de invalidación en bus
    input logic bus_rd,             // Señal de lectura en bus
    input logic [4:0] snoop_addr,   // Dirección de snoop
    input logic [1:0] resp_id,      // ID de respuesta
    input logic [1:0] ic_tag,       // Tag de IC
    input logic [63:0] ic_data,     // Datos de IC
    
    // Debug / salida
    output logic [1:0] current_state,   // Estado de la línea cache 
    output logic [1:0] current_tag,      // Tag de la línea cache
    output logic [63:0] Counter_inv,
    output logic [63:0] Time_stall    

);

    // Estados MSI
    localparam INVALID  = 2'b00;    // La línea no es válida
    localparam SHARED   = 2'b01;    // La línea es válida y compartida 
    localparam MODIFIED = 2'b10;    // La línea es válida y modificada

    logic offset;
    logic [1:0] index;          // Índice de la línea en el cache
    logic [1:0] tag;            // Tag de la dirección de acceso
    logic snoop_offset;         // Offset del snoop
    logic [1:0] snoop_index;    // Índice del snoop
    logic [1:0] snoop_tag;      // Tag del snoop

    assign offset = address[0];
    assign index  = address[2:1];
    assign tag    = address[4:3];
    assign snoop_offset = snoop_addr[0];
    assign snoop_index  = snoop_addr[2:1];
    assign snoop_tag    = snoop_addr[4:3];

    // [tag][data][state]
    logic [67:0] cache [0:3];
    logic [67:0] cache_line;

	 
	 logic [63:0] Count_Time_stall;
    logic [63:0] Count_Invalidate;
	 
	 
    assign cache_line = cache[index];

    assign current_tag   = cache_line[67:66];
    assign current_state = cache_line[1:0];
	 
	
	 
    assign Time_stall = Count_Time_stall; 
    assign Counter_inv = Count_Invalidate; 




	Timer #(.COUNTER(64)) counter_timer (
    .clk(clk),
    .rst(reset),
	.control(stall),
    .count(Count_Time_stall)
	);




    //contamos cantidad de updates


	Counter #(.COUNTER(64)) counter_invalidate (
    .clk(clk),
    .rst(reset),
	.control(bus_inv),
    .count(Count_Invalidate)
	);


    // HIT
    logic hit;
    assign hit = (current_tag == tag) && (current_state != INVALID);
	 

    // Write hit en SHARED ocupa transaccion de coherencia (upgrade)
    logic needs_upgrade;
    assign needs_upgrade = we && hit && (current_state == SHARED);

    // Request pendiente hacia IC para miss
    logic pending;                  // Indica que hay un request pendiente a IC
    logic pending_ready_armed;      // Indica que el pending ya paso por al menos un ciclo para evitar ready viejo
    logic [2:0] pending_age;        // Edad del request pendiente, para evitar ready viejo
    logic pending_type;             // Tipo de request pendiente: 1 para lectura, 0 para escritura
    logic [4:0] pending_address;    // Dirección del request pendiente
    logic [31:0] pending_data;      // Datos de escritura del request pendiente
    logic self_snoop;               // Snoop actual es la propia transacción pendiente en el bus

    // Si hay request pendiente a la misma direccion el snoop es la propia transaccion en el bus.
    assign self_snoop = pending && (pending_address == snoop_addr);

    // Hilo de request hacia IC: mientras pending=1, help sigue alto
    assign help = pending;
    assign request_packet = {pending_type, pending_address, pending_data};




    // STALL: se queda activo mientras haya request pendiente
    assign stall = pending || (((rd || we) && (!hit || needs_upgrade)) && !ready);

    // READ
    always_comb begin
        if (hit)
            data_out = (offset) ? cache_line[65:34] : cache_line[33:2];
        else
            data_out = 32'b0;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                cache[i] <= 68'b0;
            end
            pending         <= 1'b0;
            pending_ready_armed <= 1'b0;
            pending_age     <= 3'b0;
            pending_type    <= 1'b0;
            pending_address <= 5'b0;
            pending_data    <= 32'b0;
            ready_c         <= 1'b0;
            wb_valid        <= 1'b0;
            cache_line_c    <= 64'b0;
        end else begin

            


            // defaults de pulsos/salidas a IC
            ready_c  <= 1'b0;
            wb_valid <= 1'b0;

//                         $display(
//     "[CACHE %0d] type=%0d addres=%0d data=%0d we=%0d rd=%0d stall=%0d time=%0t",
//	  cache_id,
//     pending_type,
//     pending_address,
//     pending_data,
//     we,
//     rd,
//     stall,
//     $time
// );



            // =========================
            // 1. SNOOP (BUS)
            // =========================
            if (bus_rd || bus_inv) begin
                // Ack de snoop: este cache ya proceso el ciclo de bus
                ready_c <= 1'b1;

         

                // Solo toca la linea que calza con el snoop_addr
                if (cache[snoop_index][67:66] == snoop_tag &&
                    cache[snoop_index][1:0] != INVALID && !self_snoop) begin

                
					
                    // BusRd: si estaba en M, hace write-back de la linea
                    if (bus_rd) begin
                        if (cache[snoop_index][1:0] == MODIFIED) begin
                            wb_valid     <= 1'b1;
                            cache_line_c <= cache[snoop_index][65:2];
                        end
                        cache[snoop_index][1:0] <= SHARED;
                    end

                    // BusInv: S/M -> I
                    if (bus_inv) begin
                        cache[snoop_index][1:0] <= INVALID;
                    end
                end
            end

            // =========================
            // HIT LOCAL
            // =========================
            if (!pending && hit && !needs_upgrade) begin
                if (we) begin
                    // Write hit local: S/M -> M
                    cache[index][1:0] <= MODIFIED;

                    if (offset)
                        cache[index][65:34] <= data_in;
                    else
                        cache[index][33:2] <= data_in;
                end
            end

            // =========================
            // MISS: se levanta request a IC y se guarda contexto
            // =========================
            if (!pending && ((rd || we) && (!hit || needs_upgrade))) begin
                pending         <= 1'b1;
                pending_ready_armed <= 1'b0;
                pending_age     <= 3'b0;
                // type=1 lectura, type=0 escritura
                pending_type    <= rd ? 1'b1 : 1'b0;
                pending_address <= address;
                pending_data    <= data_in;

            //      $display(
			// 	"[cache] request type=%0d addres=%0d data=%0d time=%0t",
            //     pending_type,
            //     pending_address,
            //     pending_data,
            // $time
            //    );
					 

            end

            // Armado de ready para evitar capturar un ready viejo
            if (pending && !pending_ready_armed) begin
                pending_ready_armed <= 1'b1;
            end

            // Edad del request pendiente. En MSI este request siempre
            // tarda varios ciclos (decode+snoop+mem+respond), asi que
            // si llega un ready demasiado rapido probablemente es viejo.
            if (pending && pending_age != 3'b111) begin
                pending_age <= pending_age + 3'd1;
            end

            // =========================
            // RESPUESTA DEL IC PARA REQUEST PENDIENTE
            // =========================
            if (pending && pending_ready_armed && (pending_age >= 3'd2) &&
                ready && (resp_id == cache_id)) begin
                logic [1:0] p_index;
                logic p_offset;
                p_index  = pending_address[2:1];
                p_offset = pending_address[0];

                cache[p_index][67:66] <= ic_tag;
                cache[p_index][65:2]  <= ic_data;

                if (pending_type == 1'b0) begin
                    // Miss de escritura: termina en M y parchea palabra
                    cache[p_index][1:0] <= MODIFIED;

                    if (p_offset)
                        cache[p_index][65:34] <= pending_data;
                    else
                        cache[p_index][33:2] <= pending_data;

                end else begin
                    // Miss de lectura: I -> S
                    cache[p_index][1:0] <= SHARED;
                end

                pending <= 1'b0;
                pending_ready_armed <= 1'b0;
                pending_age <= 3'b0;
            end
        end
    end

endmodule