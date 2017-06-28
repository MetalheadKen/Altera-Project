`include "defines.v"

module openmips_min_sopc(clk, rst, uart_in, uart_out, gpio_i, gpio_o, flash_data_i, flash_addr_o, flash_we_o, flash_rst_o, flash_oe_o, flash_ce_o,
						 sdr_clk_o, sdr_cs_n_o, sdr_cke_o, sdr_ras_n_o, sdr_cas_n_o, sdr_we_n_o, sdr_dqm_o, sdr_ba_o, sdr_addr_o, sdr_dq_io);

	input  wire 						clk;
	input  wire							rst;
	
	/* 新增UART介面 */
	input  wire							uart_in;
	output wire							uart_out;
	
	/* 新增16位元輸入介面 */
	input  wire [15:0]					gpio_i;
	
	/* 新增32位元輸出介面 */
	output wire [31:0]					gpio_o;
	
	/* 新增與外部Flash相連的介面 */
	input  wire [7:0]					flash_data_i;
	output wire [21:0]					flash_addr_o;
	output wire							flash_we_o;
	output wire							flash_rst_o;
	output wire							flash_oe_o;
	output wire							flash_ce_o;

	/* 新增與外部SDRAM相連的介面 */
	output wire							sdr_clk_o;
	output wire							sdr_cs_n_o;
	output wire							sdr_cke_o;
	output wire							sdr_ras_n_o;
	output wire							sdr_cas_n_o;
	output wire							sdr_we_n_o;
	output wire [1:0]					sdr_dqm_o;
	output wire [1:0]					sdr_ba_o;
	output wire [12:0]					sdr_addr_o;
	inout  wire [15:0]					sdr_dq_io;

	wire [7:0]				interrupt;
	wire					timer_int;
	wire					gpio_int;
	wire					uart_int;
	wire [31:0] 			gpio_i_temp;
  
	wire [31:0] 			m0_data_i;
	wire [31:0] 			m0_data_o;
	wire [31:0] 			m0_addr_i;
	wire [3:0]  			m0_sel_i;
	wire					m0_we_i;
	wire					m0_cyc_i; 
	wire					m0_stb_i;
	wire					m0_ack_o;  
	
	wire [31:0]				m1_data_i;
	wire [31:0]				m1_data_o;
	wire [31:0]				m1_addr_i;
	wire [3:0]				m1_sel_i;
	wire					m1_we_i;
	wire					m1_cyc_i; 
	wire					m1_stb_i;
	wire					m1_ack_o;  	

	wire [31:0]				s0_data_i;
	wire [31:0]				s0_data_o;
	wire [31:0]				s0_addr_o;
	wire [3:0]				s0_sel_o;
	wire					s0_we_o; 
	wire					s0_cyc_o; 
	wire					s0_stb_o;
	wire					s0_ack_i;

	wire [31:0]				s1_data_i;
	wire [31:0]				s1_data_o;
	wire [31:0]				s1_addr_o;
	wire [3:0]				s1_sel_o;
	wire					s1_we_o; 
	wire					s1_cyc_o; 
	wire					s1_stb_o;
	wire					s1_ack_i;
  
	wire [31:0]				s2_data_i;
	wire [31:0]				s2_data_o;
	wire [31:0]				s2_addr_o;
	wire [3:0]				s2_sel_o;
	wire					s2_we_o; 
	wire					s2_cyc_o; 
	wire					s2_stb_o;
	wire					s2_ack_i;
	
	wire [31:0]				s3_data_i;
	wire [31:0]				s3_data_o;
	wire [31:0]				s3_addr_o;
	wire [3:0]				s3_sel_o;
	wire					s3_we_o; 
	wire					s3_cyc_o; 
	wire					s3_stb_o;
	wire					s3_ack_i;	  
	
	wire					sdram_init_done;
  
	assign sdr_clk_o = clk;

	/* 實體化實際版OpenMIPS處理器 */
	openmips openmips0(.clk(clk),
					   .rst(rst),
		
					   /* 指令Wishbone匯流排介面連接到Wishbone匯流排互聯矩陣的主設備介面1 */
					   .iwishbone_data_i(m1_data_o),
					   .iwishbone_ack_i(m1_ack_o),
					   .iwishbone_addr_o(m1_addr_i),
					   .iwishbone_data_o(m1_data_i),
					   .iwishbone_we_o(m1_we_i),
					   .iwishbone_sel_o(m1_sel_i),
					   .iwishbone_stb_o(m1_stb_i),
					   .iwishbone_cyc_o(m1_cyc_i), 
					
					   /* 於下面會說明訊號interrupt的含義 */
					   .int_i(interrupt),
					   
					   /* 資料Wishbone匯流排介面連接到Wishbone匯流排互聯矩陣的主設備介面0 */
					   .dwishbone_data_i(m0_data_o),
					   .dwishbone_ack_i(m0_ack_o),
					   .dwishbone_addr_o(m0_addr_i),
					   .dwishbone_data_o(m0_data_i),
					   .dwishbone_we_o(m0_we_i),
					   .dwishbone_sel_o(m0_sel_i),
					   .dwishbone_stb_o(m0_stb_i),
					   .dwishbone_cyc_o(m0_cyc_i),
				
					   .timer_int_o(timer_int)
	);
	
	/* OpenMIPS處理器的中斷輸入，此處有時脈中斷、UART中斷、GPIO中斷 */
	assign interrupt = {3'b000, gpio_int, uart_int, timer_int};

	/* 實體化GPIO */
	gpio_top gpio_top0(.wb_clk_i(clk),
					   .wb_rst_i(rst),
					   
					   /* GPIO連接到Wishbone互聯矩陣的從設備介面2 */
					   .wb_cyc_i(s2_cyc_o),
					   .wb_adr_i(s2_addr_o[7:0]),
					   .wb_dat_i(s2_data_o),
					   .wb_sel_i(s2_sel_o),
					   .wb_we_i(s2_we_o),
					   .wb_stb_i(s2_stb_o),
					   .wb_dat_o(s2_data_i),
					   .wb_ack_o(s2_ack_i),
					   .wb_err_o(),
					   
					   .wb_inta_o(gpio_int),
					   .ext_pad_i(gpio_i_temp),
					   .ext_padoe_o(),
					   
					   /* 連接到32位元輸出介面 */
					   .ext_pad_o(gpio_o)
	);
	
	/* 將SDRAM控制器的輸出sdram_init_done有做為一個GPIO的一個輸入 */
	assign gpio_i_temp = {15'h0000, sdram_init_done, gpio_i};

	/* 實體化Flash控制器 */
	flash_top flash_top0(.wb_clk_i(clk),
						 .wb_rst_i(rst),
						 
						 /* Flash控制器連接到Wishbone匯流排互聯矩陣的從設備介面3 */
						 .wb_adr_i(s3_addr_o),
						 .wb_dat_o(s3_data_i),
						 .wb_dat_i(s3_data_o),
						 .wb_sel_i(s3_sel_o),
						 .wb_we_i(s3_we_o),
						 .wb_stb_i(s3_stb_o), 
						 .wb_cyc_i(s3_cyc_o), 
						 .wb_ack_o(s3_ack_i),
						 
						 /* 與小型SOPC外部介面相連，對外連接Flash晶片 */
						 .flash_adr_o(flash_addr_o),
						 .flash_dat_i(flash_data_i),
						 .flash_rst(flash_rst_o),
						 .flash_oe(flash_oe_o),
						 .flash_ce(flash_ce_o),
						 .flash_we(flash_we_o)
	);

	/* 實體化UART控制器 */
	uart_top uart_top0(.wb_clk_i(clk), 
					   .wb_rst_i(rst),
					   
					   /* UART控制器連接到Wishbone匯流排互聯矩陣的從設備介面1 */
					   .wb_adr_i(s1_addr_o[4:0]),
					   .wb_dat_i(s1_data_o),
					   .wb_dat_o(s1_data_i), 
					   .wb_we_i(s1_we_o), 
					   .wb_stb_i(s1_stb_o), 
					   .wb_cyc_i(s1_cyc_o),
					   .wb_ack_o(s1_ack_i),
					   .wb_sel_i(s1_sel_o),
					   
					   /* 序列埠中斷 */
					   .int_o(uart_int),
					   
					   /* 連接UART介面 */
					   .stx_pad_o(uart_out),
					   .srx_pad_i(uart_in),
					   .cts_pad_i(1'b0), 
					   .dsr_pad_i(1'b0), 
					   .ri_pad_i(1'b0), 
					   .dcd_pad_i(1'b0),
					   .rts_pad_o(),  
					   .dtr_pad_o()
	);

	/* 實體化SDRAM控制器 */
	sdrc_top sdrc_top0(.wb_clk_i(clk),
					   .wb_rst_i(rst),
					   
					   /* SDRAM控制器連接到Wishbone匯流排互聯矩陣的從設備介面0 */
					   .wb_stb_i(s0_stb_o),
					   .wb_ack_o(s0_ack_i),
					   .wb_addr_i({s0_addr_o[25:2],2'b00}),
					   .wb_we_i(s0_we_o),
					   .wb_dat_i(s0_data_o),
					   .wb_sel_i(s0_sel_o),
					   .wb_dat_o(s0_data_i),
					   .wb_cyc_i(s0_cyc_o),
					   .wb_cti_i(3'b000),
						
					   /* 與小型SOPC外部介面相連，對外連接SDRAM */
					   .sdram_clk(clk),
					   .sdram_resetn(~rst),
					   .sdr_cs_n(sdr_cs_n_o),
					   .sdr_cke(sdr_cke_o),
					   .sdr_ras_n(sdr_ras_n_o),
					   .sdr_cas_n(sdr_cas_n_o),
					   .sdr_we_n(sdr_we_n_o),
					   .sdr_dqm(sdr_dqm_o),
					   .sdr_ba(sdr_ba_o),
					   .sdr_addr(sdr_addr_o),
					   .sdr_dq(sdr_dq_io),
							
					   /* SDRAM控制器的一些設定，參考表13-20 */
					   .cfg_sdr_width(2'b01),
					   .cfg_colbits(2'b00),
					   .cfg_req_depth(2'b11),
					   .cfg_sdr_en(1'b1),
					   .cfg_sdr_mode_reg(13'b0000000110001),
					   .cfg_sdr_tras_d(4'b1000),
					   .cfg_sdr_trp_d(4'b0010),
					   .cfg_sdr_trcd_d(4'b0010),
					   .cfg_sdr_cas(3'b100),
					   .cfg_sdr_trcar_d(4'b1010),
					   .cfg_sdr_twr_d(4'b0010),
					   .cfg_sdr_rfsh(12'b011010011000),
					   .cfg_sdr_rfmax(3'b100),
					   
					   /* SDRAM初始化完畢訊號，透過GPIO的輸入介面傳給處理器 */
					   .sdr_init_done(sdram_init_done)
	);

	/* 實體化WB_CONMAX */
	wb_conmax_top wb_conmax_top0(.clk_i(clk),
								 .rst_i(rst),

								 /* 主設備介面0，連接到OpenMIPS處理器的資料Wishbone匯流排介面 */
								 .m0_data_i(m0_data_i),
								 .m0_data_o(m0_data_o),
								 .m0_addr_i(m0_addr_i),
								 .m0_sel_i(m0_sel_i),
								 .m0_we_i(m0_we_i), 
								 .m0_cyc_i(m0_cyc_i), 
								 .m0_stb_i(m0_stb_i),
								 .m0_ack_o(m0_ack_o), 

								 /* 主設備介面1，連接到OpenMIPS處理器的指令Wishbone匯流排介面 */
								 .m1_data_i(m1_data_i),
								 .m1_data_o(m1_data_o),
								 .m1_addr_i(m1_addr_i),
								 .m1_sel_i(m1_sel_i),
								 .m1_we_i(m1_we_i), 
								 .m1_cyc_i(m1_cyc_i), 
								 .m1_stb_i(m1_stb_i),
								 .m1_ack_o(m1_ack_o), 
								
								 /* 主設備介面1 */
								 .m2_data_i(`ZeroWord),
								 .m2_data_o(),
								 .m2_addr_i(`ZeroWord),
								 .m2_sel_i(4'b0000),
								 .m2_we_i(1'b0), 
								 .m2_cyc_i(1'b0), 
								 .m2_stb_i(1'b0),
								 .m2_ack_o(), 
								 .m2_err_o(), 
								 .m2_rty_o(),

								 /* 主設備介面3 */
								 .m3_data_i(`ZeroWord),
								 .m3_data_o(),
								 .m3_addr_i(`ZeroWord),
								 .m3_sel_i(4'b0000),
								 .m3_we_i(1'b0), 
								 .m3_cyc_i(1'b0), 
								 .m3_stb_i(1'b0),
								 .m3_ack_o(), 
								 .m3_err_o(), 
								 .m3_rty_o(),
								
								 /* 主設備介面4 */
								 .m4_data_i(`ZeroWord),
								 .m4_data_o(),
								 .m4_addr_i(`ZeroWord),
								 .m4_sel_i(4'b0000),
								 .m4_we_i(1'b0), 
								 .m4_cyc_i(1'b0), 
								 .m4_stb_i(1'b0),
								 .m4_ack_o(), 
								 .m4_err_o(), 
								 .m4_rty_o(),
								
								 /* 主設備介面5 */
								 .m5_data_i(`ZeroWord),
								 .m5_data_o(),
								 .m5_addr_i(`ZeroWord),
								 .m5_sel_i(4'b0000),
								 .m5_we_i(1'b0), 
								 .m5_cyc_i(1'b0), 
								 .m5_stb_i(1'b0),
								 .m5_ack_o(), 
								 .m5_err_o(), 
								 .m5_rty_o(),

								 /* 主設備介面6 */
								 .m6_data_i(`ZeroWord),
								 .m6_data_o(),
								 .m6_addr_i(`ZeroWord),
								 .m6_sel_i(4'b0000),
								 .m6_we_i(1'b0), 
								 .m6_cyc_i(1'b0), 
								 .m6_stb_i(1'b0),
								 .m6_ack_o(), 
								 .m6_err_o(), 
								 .m6_rty_o(),
								
								 /* 主設備介面7 */
								 .m7_data_i(`ZeroWord),
								 .m7_data_o(),
								 .m7_addr_i(`ZeroWord),
								 .m7_sel_i(4'b0000),
								 .m7_we_i(1'b0), 
								 .m7_cyc_i(1'b0), 
								 .m7_stb_i(1'b0),
								 .m7_ack_o(), 
								 .m7_err_o(), 
								 .m7_rty_o(),

								 /* 從設備介面0，連接到SDRAM控制器 */
								 .s0_data_i(s0_data_i),
								 .s0_data_o(s0_data_o),
								 .s0_addr_o(s0_addr_o),
								 .s0_sel_o(s0_sel_o),
								 .s0_we_o(s0_we_o), 
								 .s0_cyc_o(s0_cyc_o), 
								 .s0_stb_o(s0_stb_o),
								 .s0_ack_i(s0_ack_i), 
								 .s0_err_i(1'b0), 
								 .s0_rty_i(1'b0),
	
								 /* 從設備介面1，連接到UART控制器 */
								 .s1_data_i(s1_data_i),
								 .s1_data_o(s1_data_o),
								 .s1_addr_o(s1_addr_o),
								 .s1_sel_o(s1_sel_o),
								 .s1_we_o(s1_we_o), 
								 .s1_cyc_o(s1_cyc_o), 
								 .s1_stb_o(s1_stb_o),
								 .s1_ack_i(s1_ack_i), 
								 .s1_err_i(1'b0), 
								 .s1_rty_i(1'b0),

								 /* 從設備介面2，連接到GPIO */
								 .s2_data_i(s2_data_i),
								 .s2_data_o(s2_data_o),
								 .s2_addr_o(s2_addr_o),
								 .s2_sel_o(s2_sel_o),
								 .s2_we_o(s2_we_o), 
								 .s2_cyc_o(s2_cyc_o), 
								 .s2_stb_o(s2_stb_o),
								 .s2_ack_i(s2_ack_i), 
								 .s2_err_i(1'b0), 
								 .s2_rty_i(1'b0),

								 /* 從設備介面3，連接到Flash控制器 */
								 .s3_data_i(s3_data_i),
								 .s3_data_o(s3_data_o),
								 .s3_addr_o(s3_addr_o),
								 .s3_sel_o(s3_sel_o),
								 .s3_we_o(s3_we_o), 
								 .s3_cyc_o(s3_cyc_o), 
								 .s3_stb_o(s3_stb_o),
								 .s3_ack_i(s3_ack_i), 
								 .s3_err_i(1'b0),
								 .s3_rty_i(1'b0),

								 /* 從設備介面4 */
								 .s4_data_i(),
								 .s4_data_o(),
								 .s4_addr_o(),
								 .s4_sel_o(),
								 .s4_we_o(), 
								 .s4_cyc_o(), 
								 .s4_stb_o(),
								 .s4_ack_i(1'b0), 
								 .s4_err_i(1'b0),
								 .s4_rty_i(1'b0),

								 /* 從設備介面5 */
								 .s5_data_i(),
								 .s5_data_o(),
								 .s5_addr_o(),
								 .s5_sel_o(),
								 .s5_we_o(), 
								 .s5_cyc_o(), 
								 .s5_stb_o(),
								 .s5_ack_i(1'b0),
								 .s5_err_i(1'b0),
								 .s5_rty_i(1'b0),

								 /* 從設備介面6 */
								 .s6_data_i(),
								 .s6_data_o(),
								 .s6_addr_o(),
								 .s6_sel_o(),
								 .s6_we_o(), 
								 .s6_cyc_o(), 
								 .s6_stb_o(),
								 .s6_ack_i(1'b0), 
								 .s6_err_i(1'b0), 
								 .s6_rty_i(1'b0),

								 /* 從設備介面7 */
								 .s7_data_i(),
								 .s7_data_o(),
								 .s7_addr_o(),
								 .s7_sel_o(),
								 .s7_we_o(), 
								 .s7_cyc_o(), 
								 .s7_stb_o(),
								 .s7_ack_i(1'b0), 
								 .s7_err_i(1'b0), 
								 .s7_rty_i(1'b0),

								 /* 從設備介面8 */
								 .s8_data_i(),
								 .s8_data_o(),
								 .s8_addr_o(),
								 .s8_sel_o(),
								 .s8_we_o(), 
								 .s8_cyc_o(), 
								 .s8_stb_o(),
								 .s8_ack_i(1'b0), 
								 .s8_err_i(1'b0), 
								 .s8_rty_i(1'b0),

								 /* 從設備介面9 */
								 .s9_data_i(),
								 .s9_data_o(),
								 .s9_addr_o(),
								 .s9_sel_o(),
								 .s9_we_o(), 
								 .s9_cyc_o(), 
								 .s9_stb_o(),
								 .s9_ack_i(1'b0), 
								 .s9_err_i(1'b0), 
								 .s9_rty_i(1'b0),

								 /* 從設備介面10 */
								 .s10_data_i(),
								 .s10_data_o(),
								 .s10_addr_o(),
								 .s10_sel_o(),
								 .s10_we_o(), 
								 .s10_cyc_o(), 
								 .s10_stb_o(),
								 .s10_ack_i(1'b0), 
								 .s10_err_i(1'b0), 
								 .s10_rty_i(1'b0),

								 /* 從設備介面11 */
								 .s11_data_i(),
								 .s11_data_o(),
								 .s11_addr_o(),
								 .s11_sel_o(),
								 .s11_we_o(), 
								 .s11_cyc_o(), 
								 .s11_stb_o(),
								 .s11_ack_i(1'b0), 
								 .s11_err_i(1'b0), 
								 .s11_rty_i(1'b0),

								 /* 從設備介面12 */
								 .s12_data_i(),
								 .s12_data_o(),
								 .s12_addr_o(),
								 .s12_sel_o(),
								 .s12_we_o(), 
								 .s12_cyc_o(), 
								 .s12_stb_o(),
								 .s12_ack_i(1'b0), 
								 .s12_err_i(1'b0), 
								 .s12_rty_i(1'b0),

								 /* 從設備介面13 */
								 .s13_data_i(),
								 .s13_data_o(),
								 .s13_addr_o(),
								 .s13_sel_o(),
								 .s13_we_o(), 
								 .s13_cyc_o(), 
								 .s13_stb_o(),
								 .s13_ack_i(1'b0), 
								 .s13_err_i(1'b0), 
								 .s13_rty_i(1'b0),

								 /* 從設備介面14 */
								 .s14_data_i(),
								 .s14_data_o(),
								 .s14_addr_o(),
								 .s14_sel_o(),
								 .s14_we_o(), 
								 .s14_cyc_o(), 
								 .s14_stb_o(),
								 .s14_ack_i(1'b0), 
								 .s14_err_i(1'b0), 
								 .s14_rty_i(1'b0),

								 /* 從設備介面15 */
								 .s15_data_i(),
								 .s15_data_o(),
								 .s15_addr_o(),
								 .s15_sel_o(),
								 .s15_we_o(), 
								 .s15_cyc_o(), 
								 .s15_stb_o(),
								 .s15_ack_i(1'b0), 
								 .s15_err_i(1'b0), 
								 .s15_rty_i(1'b0)
	);

endmodule
