module Comparator #(parameter N = 10) (

	input [N-1:0] A, B,
	output logic equ
);

assign equ = (A==B);


endmodule 