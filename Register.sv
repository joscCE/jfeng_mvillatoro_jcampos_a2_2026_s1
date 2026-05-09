module Register #(parameter N = 10) (

	input clk, rst,
	input [N-1:0] D,
	input en,
	output logic [N-1:0] Q

);


always_ff @(posedge clk or posedge rst)
	if(rst) Q <= 10'h00;
	else if(en)
		Q <= D;


endmodule 