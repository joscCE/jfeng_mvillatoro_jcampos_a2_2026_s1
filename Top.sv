// =============================================================
// Top.sv - implementacion MINIMA temporal.
//
// La integracion completa (4 caches + IC MSI/Firefly + RAM)
// queda diferida hasta que el modulo Cache exponga las salidas
// help y request_packet acordadas en el protocolo, y el IC
// difunda la direccion de snoop. Mientras tanto este Top
// solo deja una shell sintetizable para que el proyecto
// Quartus compile sin errores. La validacion funcional se
// hace por testbench a nivel de cada modulo (Ram_tb,
// Interconnect_MSI_tb e Interconnect_RAM_tb).
// =============================================================
module Top (
    input  logic clk,
    input  logic reset,
    input  logic protocol_sel
);

    // Sin logica activa. Las entradas se dejan sin usar
    // intencionalmente; Quartus las marcara como tied-off.
    // No se instancian Cache, Interconnect_MSI ni Ram aqui.

endmodule

