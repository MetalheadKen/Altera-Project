/* 4 SECONDs RED, 1 SECONDs YELLOW, 4 SECONDs GREEN */
module FSM_RGY_LIGHT(
	input  wire 	   CLOCK_27,
	input  wire [17:0] SW,
	
	output wire [6:0]  HEX0,
	output wire [17:0] LEDR
);

	wire CLOCK_1HZ;
	wire [2:0] SECOND;

	DIVIDER   d0(CLOCK_27,  SW[17], CLOCK_1HZ);
	RGY_LIGHT r0(CLOCK_1HZ, SW[17], SECOND, LEDR[17], LEDR[13], LEDR[15]);
	SEGMENT   s0(SECOND,	HEX0);

endmodule

module DIVIDER(
	input  wire CLK,
	input  wire RESET,
	
	output reg  CLK_1HZ
);
	
	integer DIVIDER;
	
	always @(posedge RESET or negedge CLK)
		begin
			if(RESET)
				DIVIDER <= 0;
			else
				begin
					if(DIVIDER == 26999999)
						DIVIDER <= 0;
					else
						DIVIDER <= DIVIDER + 1;
					
					if(DIVIDER < 13500000)
						CLK_1HZ <= 0;
					else
						CLK_1HZ <= 1;
				end
		end

endmodule

/* Watch Out Of Multiple Constant Drivers For Net */
module RGY_LIGHT(
	input  wire 	  CLK,
	input  wire 	  RESET,
	
	output wire [2:0] SEC_SEGMENT,
	
	output wire 	  RED_LED,
	output wire 	  GREEN_LED,
	output wire 	  YELLOW_LED
);
	
	parameter [1:0] RED    = 2'b00,
					GREEN  = 2'b01,
					YELLOW = 2'b10;
					
	reg [1:0] PRE_STATE;
	reg [1:0] NEXT_STATE;
	reg [2:0] SECOND;

	/* Define The Sequential Block */
	always @(posedge RESET or negedge CLK)
		begin
			if(RESET)
				begin
					PRE_STATE <= RED;
					SECOND    <= 3'b000;
				end
			else
				begin
					PRE_STATE <= NEXT_STATE;
					SECOND 	  <= SECOND + 1'b1;
					
					if(PRE_STATE == RED)
						begin
							if(SECOND == 3'b100)
								SECOND <= 3'b000;
						end
					else if(PRE_STATE == YELLOW)
						begin
							if(SECOND == 3'b001)
								SECOND <= 3'b000;
						end
					else if(PRE_STATE == GREEN)
						begin
							if(SECOND == 3'b100)
								SECOND <= 3'b000;
						end
				end
		end
		
	/* Define The Next State Combinational Circuit */
	always @(SECOND or PRE_STATE)
		begin
			case(PRE_STATE)
				RED:
					begin
						if(SECOND == 3'b100)
							begin
								//SECOND	   = 3'b000;
								NEXT_STATE = YELLOW;
							end
						else
							begin
								//SECOND     = SECOND + 1'b1;
								NEXT_STATE = RED;
							end
					end
					
				YELLOW:
					begin
						if(SECOND == 3'b001)
							begin
								//SECOND 	   = 3'b000;
								NEXT_STATE = GREEN;
							end
						else
							begin
								//SECOND	   = SECOND + 1'b1;
								NEXT_STATE = YELLOW;
							end
					end
					
				GREEN:
					begin
						if(SECOND == 3'b100)
							begin
								//SECOND	   = 3'b000;
								NEXT_STATE = RED;
							end
						else
							begin
								//SECOND	   = SECOND + 1'b1;
								NEXT_STATE = RED;
							end
					end
					
				default:
					begin
						NEXT_STATE = 2'bxx;
					end
			endcase
		end
			
	assign RED_LED     = (PRE_STATE == RED)    ? 1'b1 : 1'b0;
	assign GREEN_LED   = (PRE_STATE == GREEN)  ? 1'b1 : 1'b0;
	assign YELLOW_LED  = (PRE_STATE == YELLOW) ? 1'b1 : 1'b0;
	
	assign SEC_SEGMENT = SECOND;

endmodule

module SEGMENT(
	input  wire [2:0] SECOND,
	
	output reg  [6:0] DATA
);

	always @( * )
		begin
			case(SECOND)
				4'h0 	:	DATA = 7'b1000000;
				4'h1 	:	DATA = 7'b1111001;
				4'h2 	: 	DATA = 7'b0100100;
				4'h3 	: 	DATA = 7'b0110000;
				4'h4 	: 	DATA = 7'b0011001;
				default : 	DATA = 7'b1111111;
			endcase
		end

endmodule
