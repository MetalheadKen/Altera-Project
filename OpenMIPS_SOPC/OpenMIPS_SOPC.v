module OpenMIPS_SOPC(
		/* 時脈27MHZ */
		input  wire 			CLOCK_27,
		
		/* UART介面 */
		input  wire 			UART_RXD,
		output wire				UART_TXD,
		
		/* 輸入介面 */
		input  wire [17:0] 	SW,		
		
		/* 輸出介面 */
		output wire [6:0] 	HEX0,
		output wire [6:0] 	HEX1,
		output wire [6:0] 	HEX2,
		output wire [6:0] 	HEX3,
		
		/* Flah介面 */
		output wire [7:0] 	FL_DQ,
		output wire [21:0] 	FL_ADDR,
		output wire				FL_CE_N,
		output wire				FL_OE_N,
		output wire				FL_WE_N,
		output wire				FL_RST_N,
		
		/* SDRAM介面 */
		output wire			 	DRAM_CLK,
		output wire		 		DRAM_CS_N,
		output wire 		 	DRAM_CKE,
		output wire 		 	DRAM_RAS_N,
		output wire				DRAM_CAS_N,
		output wire 		 	DRAM_WE_N,
		output wire				DRAM_UDQM,
		output wire				DRAM_LDQM,
		output wire				DRAM_BA_1,
		output wire				DRAM_BA_0,
		output wire [11:0] 	DRAM_ADDR,
		inout	 wire [15:0]	DRAM_DQ		
);

		wire [31:0] gpio_o_temp;
		wire [15:0] sdr_dq_io_temp;
		
		assign gpio_o_temp		= 	{1'b1, HEX3[6:0], 1'b1, HEX2[6:0], 1'b1, HEX1[6:0], 1'b1, HEX0[6:0]};
		assign sdr_dq_io_temp	= 	{1'b0, DRAM_ADDR[11:0]};
		
		openmips_min_sopc openmips0(
				.clk(CLOCK_27),
				.rst(SW[17]),
				
				.uart_in(UART_RXD),
				.uart_out(UART_TXD),
				
				.gpio_i(SW[15:0]),
				.gpio_o(gpio_o_temp),
				
				.flash_data_i(FL_DQ),
				.flash_addr_o(FL_ADDR),
				.flash_we_o(FL_WE_N),
				.flash_rst_o(FL_RST_N),
				.flash_oe_o(FL_OE_N),
				.flash_ce_o(FL_CE_N),
				
				.sdr_clk_o(DRAM_CLK),
				.sdr_cs_n_o(DRAM_CS_N),
				.sdr_cke_o(DRAM_CKE),
				.sdr_ras_n_o(DRAM_RAS_N),
				.sdr_cas_n_o(DRAM_CAS_N),
				.sdr_we_n_o(DRAM_WE_N),
				.sdr_dqm_o({DRAM_UDQM, DRAM_LDQM}),
				.sdr_ba_o({DRAM_BA_1, DRAM_BA_0}),
				.sdr_addr_o(sdr_dq_io_temp),
				.sdr_dq_io(DRAM_DQ)
		);
				
endmodule
