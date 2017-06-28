`include "defines.v"

/* 將管線模組實體化、連接 */
module openmips(clk, rst, int_i, iwishbone_data_i, iwishbone_ack_i, iwishbone_addr_o, iwishbone_data_o, iwishbone_we_o, iwishbone_sel_o, iwishbone_stb_o, iwishbone_cyc_o,
			    dwishbone_data_i, dwishbone_ack_i, dwishbone_addr_o, dwishbone_data_o, dwishbone_we_o, dwishbone_sel_o, dwishbone_stb_o, dwishbone_cyc_o, timer_int_o);

	input wire							clk;					/* 時脈訊號 */
	input wire 							rst;					/* 重設訊號 */
	input wire	[5:0]					int_i;					/* 6個外部硬體中斷輸入 */
	
	/* 指令Wishbone匯流排 */
	input  wire [`RegBus]				iwishbone_data_i;		/* 指令Wishbone匯流排輸入的資料 */
	input  wire							iwishbone_ack_i;		/* 指令Wishbone匯流排輸入的回應 */
	output wire [`RegBus]				iwishbone_addr_o;		/* 指令Wishbone匯流排輸出的位址 */
	output wire [`RegBus]				iwishbone_data_o;		/* 指令Wishbone匯流排輸出的資料 */
	output wire							iwishbone_we_o;			/* 指令Wishbone匯流排寫入啟用訊號 */
	output wire	[3:0]					iwishbone_sel_o;		/* 指令Wishbone匯流排位元組選擇訊號 */
	output wire							iwishbone_stb_o;		/* 指令Wishbone匯流排選通訊號 */
	output wire							iwishbone_cyc_o;		/* 指令Wishbone匯流排週期訊號 */
	
	/* 資料Wishbone匯流排 */
	input  wire [`RegBus]				dwishbone_data_i;		/* 資料Wishbone匯流排輸入的資料 */
	input  wire							dwishbone_ack_i;		/* 資料Wishbone匯流排輸入的回應 */
	output wire [`RegBus]				dwishbone_addr_o;		/* 資料Wishbone匯流排輸出的位址 */
	output wire [`RegBus]				dwishbone_data_o;		/* 資料Wishbone匯流排輸出的資料 */
	output wire							dwishbone_we_o;			/* 資料Wishbone匯流排寫入啟用訊號 */
	output wire	[3:0]					dwishbone_sel_o;		/* 資料Wishbone匯流排位元組選擇訊號 */
	output wire							dwishbone_stb_o;		/* 資料Wishbone匯流排選通訊號 */
	output wire							dwishbone_cyc_o;		/* 資料Wishbone匯流排週期訊號 */
	
	output wire							timer_int_o;			/* 是否有定時中斷發生 */
	
	/* 連接IF/ID模組與解碼階段ID模組的變數 */
	wire [`InstAddrBus] 	pc;
	wire [`InstBus]			inst_i;
	wire [`InstAddrBus] 	id_pc_i;
	wire [`InstBus]	  		id_inst_i;
	
	/* 連接解碼階段ID模組輸出與ID/EX模組的輸入的變數 */
	wire [`AluOpBus]	  	id_aluop_o;
	wire [`AluSelBus]	  	id_alusel_o;
	wire [`RegBus]		  	id_reg1_o;
	wire [`RegBus]		  	id_reg2_o;
	wire					id_wreg_o;
	wire [`RegAddrBus] 		id_wd_o;
	wire					id_is_in_delayslot_o;
	wire [`RegBus]			id_link_address_o;
	wire					next_inst_in_delayslot_o;
	wire [`RegBus]			id_inst_o;
	wire [31:0]				id_excepttype_o;
	wire [`RegBus]			id_current_inst_address_o;
	
	/* 連接ID/EX模組輸出與執行階段EX模組的輸入的變數 */
	wire [`AluOpBus]	  	ex_aluop_i;
	wire [`AluSelBus]	  	ex_alusel_i;
	wire [`RegBus]		  	ex_reg1_i;
	wire [`RegBus]		  	ex_reg2_i;
	wire					ex_wreg_i;
	wire [`RegAddrBus]  	ex_wd_i;
	wire					ex_is_in_delayslot_i;
	wire [`RegBus]			ex_link_address_i;
	wire [`RegBus]			ex_inst_i;
	wire [31:0]				ex_excepttype_i;
	wire [`RegBus]			ex_current_inst_address_i;
	
	/* 連接執行階段EX模組的輸出與EX/MEM模組的輸入的變數 */
	wire					ex_wreg_o;
	wire [`RegAddrBus]  	ex_wd_o;
	wire [`RegBus]		  	ex_wdata_o;
	wire [`RegBus]			ex_hi_o;
	wire [`RegBus]			ex_lo_o;
	wire					ex_whilo_o;
	wire [`AluOpBus]		ex_aluop_o;
	wire [`RegBus]			ex_mem_addr_o;
	wire [`RegBus]			ex_reg1_o;
	wire [`RegBus]			ex_reg2_o;
	wire					ex_cp0_reg_we_o;
	wire [4:0]				ex_cp0_reg_write_addr_o;
	wire [`RegBus]			ex_cp0_reg_data_o;
	wire [31:0]				ex_excepttype_o;
	wire [`RegBus]			ex_current_inst_address_o;
	wire					ex_is_in_delayslot_o;
	
	/* 連接EX/MEM模組的輸出與存取記憶體階段MEM模組的輸入的變數 */
	wire					mem_wreg_i;
	wire [`RegAddrBus] 		mem_wd_i;
	wire [`RegBus]		  	mem_wdata_i;
	wire [`RegBus]			mem_hi_i;
	wire [`RegBus]			mem_lo_i;
	wire					mem_whilo_i;
	wire [`AluOpBus]		mem_aluop_i;
	wire [`RegBus]			mem_mem_addr_i;
	wire [`RegBus]			mem_reg1_i;
	wire [`RegBus]			mem_reg2_i;
	wire					mem_cp0_reg_we_i;
	wire [4:0]				mem_cp0_reg_write_addr_i;
	wire [`RegBus]			mem_cp0_reg_data_i;
	wire [31:0]				mem_excepttype_i;
	wire					mem_is_in_delayslot_i;
	wire [`RegBus]			mem_current_inst_address_i;
	
	/* 連接存取記憶體階段MEM模組的輸出與MEM/WB模組的輸入的變數 */
	wire					mem_wreg_o;
	wire [`RegAddrBus]  	mem_wd_o;
	wire [`RegBus]		  	mem_wdata_o;
	wire [`RegBus]			mem_hi_o;
	wire [`RegBus]			mem_lo_o;
	wire					mem_whilo_o;
	wire					mem_LLbit_value_o;
	wire					mem_LLbit_we_o;
	wire					mem_cp0_reg_we_o;
	wire [4:0]				mem_cp0_reg_write_addr_o;
	wire [`RegBus]			mem_cp0_reg_data_o;
	wire [31:0]				mem_excepttype_o;
	wire					mem_is_in_delayslot_o;
	wire [`RegBus]			mem_current_inst_address_o;
	
	/* 連接MEM/WB模組的輸出與回寫階段的輸入 */
	wire					wb_wreg_i;
	wire [`RegAddrBus]  	wb_wd_i;
	wire [`RegBus]		  	wb_wdata_i;
	wire [`RegBus]			wb_hi_i;
	wire [`RegBus]			wb_lo_i;
	wire					wb_whilo_i;
	wire					wb_LLbit_value_i;
	wire					wb_LLbit_we_i;
	wire					wb_cp0_reg_we_i;
	wire [4:0]				wb_cp0_reg_write_addr_i;
	wire [`RegBus]			wb_cp0_reg_data_i;
	wire [31:0]				wb_excepttype_i;
	wire					wb_is_in_delayslot_i;
	wire [`RegBus]			wb_current_inst_address_i;
		
	/* 連接解碼階段ID模組與通用暫存器Regfile模組的變數 */
	wire					reg1_read;
	wire					reg2_read;
	wire [`RegBus]		  	reg1_data;
	wire [`RegBus]		  	reg2_data;
	wire [`RegAddrBus]  	reg1_addr;
	wire [`RegAddrBus]  	reg2_addr;
	
	/* 連接執行階段與HILO模組的輸出，讀取HI、LO暫存器 */
	wire [`RegBus]			hi;
	wire [`RegBus]			lo;
	
	/* 連接執行階段與EX/MEM模組，用於多週期的MADD、MADDU、MSUB、MSUBU指令 */
	wire [`DoubleRegBus]	hilo_temp_o;
	wire [1:0] 				cnt_o;	
	wire [`DoubleRegBus] 	hilo_temp_i;
	wire [1:0]				cnt_i;
	
	/* 連接DIV模組，用於DIV、DIVU指令 */
	wire [`DoubleRegBus]	div_result;
	wire					div_ready;
	wire [`RegBus]			div_opdata1;
	wire [`RegBus]			div_opdata2;
	wire					div_start;
	wire					div_annul;
	wire					signed_div;
	
	/* 連接解碼階段ID/EX模組輸出與ID模組的輸入的變數 */
	wire					is_in_delayslot_i;
	wire					is_in_delayslot_o;
	
	/* 連接解碼階段ID模組輸出與PC模組的輸入的變數 */
	wire					id_branch_flag_o;
	wire [`RegBus]			branch_target_address;
	
	/* 連接控制模組與各階段的模組 */
	wire [5:0]				stall;
	wire					flush;
	wire [`RegBus]			new_pc;
	wire					stallreq_from_if;
	wire					stallreq_from_id;
	wire					stallreq_from_ex;
	wire					stallreq_from_mem;
	
	/* 連接LLbit模組與各階段的模組 */
	wire					LLbit_o;
	
	/* 連接CP0模組與EX模組 */
	wire [4:0]				cp0_raddr_i;
	wire [`RegBus]			cp0_data_o;
	
	/* 連接CP0模組與MEM模組 */
	wire [`RegBus]			cp0_count;
	wire [`RegBus]			cp0_compare;
	wire [`RegBus]			cp0_status;
	wire [`RegBus]			cp0_cause;
	wire [`RegBus]			cp0_epc;
	wire [`RegBus]			cp0_config;
	wire [`RegBus]			cp0_prid;
	
	/* 連接CP0模組與CTRL模組 */
	wire [`RegBus]			latest_epc;
	
	/* 連接OpenMIPS處理器與Wishbon匯流排介面模組 */
	wire					rom_ce;
	wire [31:0]				ram_addr_o;
	wire					ram_we_o;
	wire [3:0]				ram_sel_o;
	wire [`RegBus]			ram_data_o;
	wire					ram_ce_o;
	wire [`RegBus]			ram_data_i;
	
	/* pc_reg實體化 */
	pc_reg pc_reg0(.clk(clk),
				   .rst(rst),
				   
				   .stall(stall), 
				   .flush(flush),
				   .new_pc(new_pc),
				   .branch_flag_i(id_branch_flag_o),
				   .branch_target_address_i(branch_target_address),
				   
				   .pc(pc),
				   .ce(rom_ce)
	);
	
	assign rom_addr_o = pc; /* 指令記憶體的輸入位址就是pc的值 */
	
	/* IF/ID模組實體化 */
	if_id if_id0(.clk(clk), 
				 .rst(rst),
				 
				 .stall(stall),
				 .flush(flush),
				 
				 .if_pc(pc),
				 .if_inst(inst_i),
				 .id_pc(id_pc_i),
				 .id_inst(id_inst_i)
	);
	
	/* 解碼階段ID模組實體化 */
	id id0(.rst(rst),
		   .pc_i(id_pc_i),
		   .inst_i(id_inst_i),
		   
		   /* 來自Regfile模組的輸入 */
		   .reg1_data_i(reg1_data),
		   .reg2_data_i(reg2_data),
		   
		   /* 來自執行階段的資訊，用於解決load相依 */
		   .ex_aluop_i(ex_aluop_o),
		   
		   /* 處於執行階段的指令要寫入目的暫存器資訊 */
		   .ex_wreg_i(ex_wreg_o),
		   .ex_wdata_i(ex_wdata_o),
		   .ex_wd_i(ex_wd_o),
		   
		   /* 處於存取記憶體階段的指令要寫入目的暫存器資訊 */
		   .mem_wreg_i(mem_wreg_o),
		   .mem_wdata_i(mem_wdata_o),
		   .mem_wd_i(mem_wd_o),
		   
		   /* 來自ID/EX模組的輸入 */
		   .is_in_delayslot_i(is_in_delayslot_i),
		   
		   /* 送到Regfile模組的資訊 */
		   .reg1_read_o(reg1_read),
		   .reg2_read_o(reg2_read),
		   .reg1_addr_o(reg1_addr),
		   .reg2_addr_o(reg2_addr),
		   
		   /* 送到ID/EX模組的資訊 */
		   .aluop_o(id_aluop_o),
		   .alusel_o(id_alusel_o),
		   .reg1_o(id_reg1_o),
		   .reg2_o(id_reg2_o), 
		   .wd_o(id_wd_o),
		   .wreg_o(id_wreg_o),
		   .excepttype_o(id_excepttype_o),
		   .inst_o(id_inst_o),
		   
		   .next_inst_in_delayslot_o(next_inst_in_delayslot_o),
		   .is_in_delayslot_o(id_is_in_delayslot_o),
		   .link_addr_o(id_link_address_o),
		   .current_inst_address_o(id_current_inst_address_o),
		   
		   /* 送到PC模組的資訊 */
		   .branch_target_address_o(branch_target_address),
		   .branch_flag_o(id_branch_flag_o),
		   
		   .stallreq(stallreq_from_id)
	);
	
	/* 通用暫存器Regfile模組實體化 */
	regfile regfile1(.clk(clk), 	  .rst(rst),
					 .we(wb_wreg_i),  .waddr(wb_wd_i),    .wdata(wb_wdata_i),
					 .re1(reg1_read), .raddr1(reg1_addr), .rdata1(reg1_data),
					 .re2(reg2_read), .raddr2(reg2_addr), .rdata2(reg2_data)
	);
						  
	/* ID/EX模組實體化 */
	id_ex id_ex0(.clk(clk),
				 .rst(rst),
				 
				 .stall(stall),
				 .flush(flush),
				 
				 /* 從解碼階段ID模組傳遞過來的資訊 */
				 .id_aluop(id_aluop_o),
				 .id_alusel(id_alusel_o),
				 .id_reg1(id_reg1_o), 
				 .id_reg2(id_reg2_o),
				 .id_wd(id_wd_o),
				 .id_wreg(id_wreg_o),
				 
				 .id_link_address(id_link_address_o),
				 .id_is_in_delayslot(id_is_in_delayslot_o),
				 .next_inst_in_delayslot_i(next_inst_in_delayslot_o),
				 .id_inst(id_inst_o),
				 .id_excepttype(id_excepttype_o),
				 .id_current_inst_address(id_current_inst_address_o),
				 
				 /* 傳遞到執行階段EX模組的資訊 */
				 .ex_aluop(ex_aluop_i),
				 .ex_alusel(ex_alusel_i),
				 .ex_reg1(ex_reg1_i),
				 .ex_reg2(ex_reg2_i),
				 .ex_wd(ex_wd_i),
				 .ex_wreg(ex_wreg_i),
				 
				 .ex_link_address(ex_link_address_i),
				 .ex_is_in_delayslot(ex_is_in_delayslot_i),
				 .ex_excepttype(ex_excepttype_i),
				 .ex_current_inst_address(ex_current_inst_address_i),
				 
				 /* 傳遞到解碼階段ID模組的資訊 */
				 .is_in_delayslot_o(is_in_delayslot_i),
				 .ex_inst(ex_inst_i)
	);
	
	/* EX模組的實體化 */
	ex ex0(.rst(rst),
	
		   /* 從ID/EX模組傳遞過來的資訊 */
		   .aluop_i(ex_aluop_i),
		   .alusel_i(ex_alusel_i),
		   .reg1_i(ex_reg1_i),
		   .reg2_i(ex_reg2_i),
		   .wd_i(ex_wd_i),
		   .wreg_i(ex_wreg_i),		
		   
		   .hi_i(hi),
		   .lo_i(lo),
		   
		   .link_address_i(ex_link_address_i),
		   .is_in_delayslot_i(ex_is_in_delayslot_i),
		   .inst_i(ex_inst_i),
		   .excepttype_i(ex_excepttype_i),
		   .current_inst_address_i(ex_current_inst_address_i),
		   
		   /* 從MEM/WB模組傳遞過來的資訊 */
		   .wb_hi_i(wb_hi_i),
		   .wb_lo_i(wb_lo_i),
		   .wb_whilo_i(wb_whilo_i),
		   
		   .wb_cp0_reg_we(wb_cp0_reg_we_i),
		   .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
		   .wb_cp0_reg_data(wb_cp0_reg_data_i),
		   
		   /* 從MEM模組傳遞過來的資訊 */
		   .mem_hi_i(mem_hi_o),
		   .mem_lo_i(mem_lo_o),
		   .mem_whilo_i(mem_whilo_o),
		   
		   .mem_cp0_reg_we(mem_cp0_reg_we_o),
		   .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
		   .mem_cp0_reg_data(mem_cp0_reg_data_o),
		   
		   /* 從EX/MEM模組傳遞過來的資訊 */
		   .hilo_temp_i(hilo_temp_i),
		   .cnt_i(cnt_i),
		   
		   /* 從DIV模組傳遞過來的資訊 */
		   .div_result_i(div_result),
		   .div_ready_i(div_ready),
		   
		   /* 從CP0模組傳遞過來的資訊 */
		   .cp0_reg_data_i(cp0_data_o),
		   
		   /* 輸出到EX/MEM模組的資訊 */
		   .wd_o(ex_wd_o),
		   .wreg_o(ex_wreg_o),
		   .wdata_o(ex_wdata_o),
		   
		   .hi_o(ex_hi_o),
		   .lo_o(ex_lo_o),
		   .whilo_o(ex_whilo_o),
		   
		   .hilo_temp_o(hilo_temp_o),
		   .cnt_o(cnt_o),
		   
		   .cp0_reg_we_o(ex_cp0_reg_we_o),
		   .cp0_reg_write_addr_o(ex_cp0_reg_write_addr_o),
		   .cp0_reg_data_o(ex_cp0_reg_data_o),
		   
		   .excepttype_o(ex_excepttype_o),
		   .is_in_delayslot_o(ex_is_in_delayslot_o),
		   .current_inst_address_o(ex_current_inst_address_o),
		   
		   /* 輸出到DIV模組的資訊 */
		   .div_opdata1_o(div_opdata1),
		   .div_opdata2_o(div_opdata2),
		   .div_start_o(div_start),
		   .signed_div_o(signed_div),
		   .aluop_o(ex_aluop_o),
		   .mem_addr_o(ex_mem_addr_o),
		   .reg2_o(ex_reg2_o),
		   .stallreq(stallreq_from_ex),
		   
		   /* 輸出到CP0模組的資訊 */
		   .cp0_reg_read_addr_o(cp0_raddr_i)
	);
	
	/* EX/MEM模組實體化 */
	ex_mem ex_mem0(.clk(clk),
				   .rst(rst),
				   
				   .stall(stall),
				   .flush(flush),
				   
				   /* 來自執行序階段EX模組的資訊 */
				   .ex_wd(ex_wd_o),
				   .ex_wreg(ex_wreg_o),
				   .ex_wdata(ex_wdata_o),
				   .ex_hi(ex_hi_o),
				   .ex_lo(ex_lo_o),
				   .ex_whilo(ex_whilo_o),
				   
				   .ex_aluop(ex_aluop_o),
				   .ex_mem_addr(ex_mem_addr_o),
				   .ex_reg2(ex_reg2_o),
				   
				   .ex_cp0_reg_we(ex_cp0_reg_we_o),
				   .ex_cp0_reg_write_addr(ex_cp0_reg_write_addr_o),
				   .ex_cp0_reg_data(ex_cp0_reg_data_o),
				   
				   .ex_excepttype(ex_excepttype_o),
				   .ex_is_in_delayslot(ex_is_in_delayslot_o),
				   .ex_current_inst_address(ex_current_inst_address_o),
				   
				   .hilo_i(hilo_temp_o),
				   .cnt_i(cnt_o),
				   
				   /* 送到存取記憶體階段MEM模組的資訊 */
				   .mem_wd(mem_wd_i), 
				   .mem_wreg(mem_wreg_i),
				   .mem_wdata(mem_wdata_i),
				   .mem_hi(mem_hi_i),
				   .mem_lo(mem_lo_i),
				   .mem_whilo(mem_whilo_i),
				   
				   .mem_aluop(mem_aluop_i),
				   .mem_mem_addr(mem_mem_addr_i),
				   .mem_reg2(mem_reg2_i),
				   
				   .mem_cp0_reg_we(mem_cp0_reg_we_i),
				   .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_i),
				   .mem_cp0_reg_data(mem_cp0_reg_data_i),
				   
				   .mem_excepttype(mem_excepttype_i),
				   .mem_is_in_delayslot(mem_is_in_delayslot_i),
				   .mem_current_inst_address(mem_current_inst_address_i),
				   
				   /* 送到執行階段EX模組的資訊 */
				   .hilo_o(hilo_temp_i),
				   .cnt_o(cnt_i)
	);
	
	/* 修改MEM模組實體化 */
	/* 目的是將資料記憶體介面與MEM模組的對應介面連接在一起 */
	mem mem0(.rst(rst),
	
			 /* 來自EX/MEM模組的資訊 */
			 .wd_i(mem_wd_i),
			 .wreg_i(mem_wreg_i),
			 .wdata_i(mem_wdata_i),
			 .hi_i(mem_hi_i),
			 .lo_i(mem_lo_i),
			 .whilo_i(mem_whilo_i),
			 
			 .aluop_i(mem_aluop_i),
			 .mem_addr_i(mem_mem_addr_i),
			 .reg2_i(mem_reg2_i),
			 
			 .cp0_reg_we_i(mem_cp0_reg_we_i),
			 .cp0_reg_write_addr_i(mem_cp0_reg_write_addr_i),
			 .cp0_reg_data_i(mem_cp0_reg_data_i),
			 
			 .excepttype_i(mem_excepttype_i),
			 .is_in_delayslot_i(mem_is_in_delayslot_i),
			 .current_inst_address_i(mem_current_inst_address_i),
			 
			 /* 來自CP0模組的資訊 */
			 .cp0_status_i(cp0_status),
			 .cp0_cause_i(cp0_cause),
			 .cp0_epc_i(cp0_epc),
			 
			 /* 來自回寫階段的資訊 */
			 /* 回寫階段的指令是否要寫入CP0，用來檢測資料相依 */
			 .wb_cp0_reg_we(wb_cp0_reg_we_i),
			 .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
			 .wb_cp0_reg_data(wb_cp0_reg_data_i),
			 
			 /* 來自資料記憶體的資訊 */
			 .mem_data_i(ram_data_i),
			 
			 /* 來自LLbit模組的資訊 */
			 .LLbit_i(LLbit_o),
			 
			 /* 來自MEM/WB模組的資訊，使用資料前推來解決LLbit的最新值問題 */
			 .wb_LLbit_we_i(wb_LLbit_we_i),
			 .wb_LLbit_value_i(wb_LLbit_value_i),
			 
			 /* 送到MEM/WB模組的資訊 */
			 .wd_o(mem_wd_o),
			 .wreg_o(mem_wreg_o),
			 .wdata_o(mem_wdata_o),
			 
			 .LLbit_we_o(mem_LLbit_we_o),
			 .LLbit_value_o(mem_LLbit_value_o),
			 
			 .cp0_reg_we_o(mem_cp0_reg_we_o),
			 .cp0_reg_write_addr_o(mem_cp0_reg_write_addr_o),
			 .cp0_reg_data_o(mem_cp0_reg_data_o),
			 
			 /* 送到EX和MEM/WB模組的資訊 */
			 .hi_o(mem_hi_o),
			 .lo_o(mem_lo_o),
			 .whilo_o(mem_whilo_o),
			 
			 /* 送到CP0模組的資訊 */
			 .excepttype_o(mem_excepttype_o),
			 .is_in_delayslot_o(mem_is_in_delayslot_o),
			 .current_inst_address_o(mem_current_inst_address_o),
			 
			 /* 送到CTRL模組的資訊 */
			 .cp0_epc_o(latest_epc),
			 
			 /* 送到資料記憶體的資訊 */
			 .mem_addr_o(ram_addr_o),
			 .mem_we_o(ram_we_o),
			 .mem_sel_o(ram_sel_o),
			 .mem_data_o(ram_data_o),
			 .mem_ce_o(ram_ce_o)
	);
	
	/* MEM/WB模組實體化 */
	mem_wb mem_wb0(.clk(clk),
				   .rst(rst),
				   
				   .stall(stall),
				   .flush(flush),
				   
				   /* 來自存取記憶體階段MEM模組的資訊 */
				   .mem_wd(mem_wd_o),
				   .mem_wreg(mem_wreg_o),
				   .mem_wdata(mem_wdata_o),
				   .mem_hi(mem_hi_o),
				   .mem_lo(mem_lo_o),
				   .mem_whilo(mem_whilo_o),
				   
				   .mem_LLbit_we(mem_LLbit_we_o),
				   .mem_LLbit_value(mem_LLbit_value_o),
				   
				   .mem_cp0_reg_we(mem_cp0_reg_we_o),
				   .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
				   .mem_cp0_reg_data(mem_cp0_reg_data_o),
				   
				   /* 送到回寫階段的資訊 */
				   .wb_wd(wb_wd_i),
				   .wb_wreg(wb_wreg_i),
				   .wb_wdata(wb_wdata_i),
				   
				   /* 送到HI/LO暫存器模組和回寫階段的資訊 */
				   .wb_hi(wb_hi_i),
				   .wb_lo(wb_lo_i),
				   .wb_whilo(wb_whilo_i),
				   
				   /* 送到存取記憶體階段MEM模組的資訊 */
				   .wb_LLbit_we(wb_LLbit_we_i),
				   .wb_LLbit_value(wb_LLbit_value_i),
				   
				   /* 送到CP0模組的資訊 */
				   .wb_cp0_reg_we(wb_cp0_reg_we_i),
				   .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
				   .wb_cp0_reg_data(wb_cp0_reg_data_i)
	);
	
	/* HI、LO暫存器模組實體化 */
	hilo_reg hilo_reg0(.clk(clk),
					   .rst(rst),
					   
					   /* 寫入連接埠 */
					   .we(wb_whilo_i),
					   .hi_i(wb_hi_i),
					   .lo_i(wb_lo_i),
					   
					   /* 讀取連接埠1 */
					   .hi_o(hi),
					   .lo_o(lo)
	);	
	
	/* CTRL模組實體化 */
	ctrl ctrl0(.rst(rst),
	
			   /* 來自MEM模組的資訊 */
			   .excepttype_i(mem_excepttype_o),
			   .cp0_epc_i(latest_epc),
			   
			   .stallreq_from_if(stallreq_from_if),
			   .stallreq_from_id(stallreq_from_id),
			   .stallreq_from_ex(stallreq_from_ex),
			   .stallreq_from_mem(stallreq_from_mem),
			   
			   /* 送到PC模組的資訊 */
			   .new_pc(new_pc),
			   
			   .stall(stall),
			   .flush(flush)
	);
	
	/* DIV模組實體化 */
	div div0(.clk(clk),
			 .rst(rst),
			 
			 /* 來自EX模組的資訊 */
			 .signed_div_i(signed_div),
			 .opdata1_i(div_opdata1),
			 .opdata2_i(div_opdata2),
			 .start_i(div_start),
			 .annul_i(1'b0),
			 
			 /* 送到EX模組的資訊 */
			 .result_o(div_result),
			 .ready_o(div_ready)
	);
	
	/* LLbit模組實體化 */
	LLbit_reg LLbit_reg0(.clk(clk),
						 .rst(rst),
						 .flush(flush),
						 
						 /* 來自MEM/WB模組的資訊 */
						 .we(wb_LLbit_we_i),
						 .LLbit_i(wb_LLbit_value_i),
						 
						 /* 送到MEM模組的資訊 */
						 .LLbit_o(LLbit_o)
	);
	
	/* CP0模組實體化 */
	cp0_reg cp0_reg0(.clk(clk),
					 .rst(rst),
					 
					 /* 來自MEM/WB模組的資訊 */
					 .we_i(wb_cp0_reg_we_i),
					 .waddr_i(wb_cp0_reg_write_addr_i),
					 .data_i(wb_cp0_reg_data_i),
					 
					 /* 來自MEM模組的資訊 */
					 .excepttype_i(mem_excepttype_o),
					 .current_inst_addr_i(mem_current_inst_address_o),
					 .is_in_delayslot_i(mem_is_in_delayslot_o),
					 
					 /* 來自EX模組的資訊 */
					 .raddr_i(cp0_raddr_i),
					 
					 /* openmips的輸入 */
					 .int_i(int_i),
					 
					 /* 送到EX模組的資訊 */
					 .data_o(cp0_data_o),
					 
					 /* 送到MEM模組的資訊 */
					 .count_o(cp0_count),
					 .compare_o(cp0_compare),
					 .status_o(cp0_status),
					 .cause_o(cp0_cause),
					 .epc_o(cp0_epc),
					 .config_o(cp0_config),
					 .prid_o(cp0_prid),
					 
					 /* openmips的輸出 */
					 .timer_int_o(timer_int_o)
	);
	
	/* 資料Wishbone匯流排介面模組實體化 */
	wishbone_bus_if dwishbone_bus_if(.clk(clk),
									 .rst(rst),
									 
									 /* 來自控制模組CTRL的資訊 */
									 .stall_i(stall),
									 .flush_i(flush),
									 
									 /* CPU-side讀寫操作資訊 */
									 .cpu_ce_i(ram_ce_o),
									 .cpu_data_i(ram_data_o),
									 .cpu_addr_i(ram_addr_o),
									 .cpu_we_i(ram_we_o),
									 .cpu_sel_i(ram_sel_o),
									 .cpu_data_o(ram_data_i),
									 
									 /* Wishbone-side匯流排介面 */
									 .wishbone_data_i(dwishbone_data_i),
									 .wishbone_ack_i(dwishbone_ack_i),
									 .wishbone_addr_o(dwishbone_addr_o),
									 .wishbone_data_o(dwishbone_data_o),
									 .wishbone_we_o(dwishbone_we_o),
									 .wishbone_sel_o(dwishbone_sel_o),
									 .wishbone_stb_o(dwishbone_stb_o),
									 .wishbone_cyc_o(dwishbone_cyc_o),
									 
									 .stallreq(stallreq_from_mem)
	);
	
	/* 指令Wishbone匯流排介面模組實體化 */
	wishbone_bus_if iwishbone_bus_if(.clk(clk),
									 .rst(rst),
									 
									 /* 來自控制模組CTRL的資訊 */
									 .stall_i(stall),
									 .flush_i(flush),
									 
									 /* CPU-side讀寫操作資訊 */
									 .cpu_ce_i(ram_ce_o),
									 .cpu_data_i(32'h00000000),
									 .cpu_addr_i(pc),
									 .cpu_we_i(1'b0),
									 .cpu_sel_i(4'b1111),
									 .cpu_data_o(inst_i),
									 
									 /* Wishbone-side匯流排介面 */
									 .wishbone_data_i(iwishbone_data_i),
									 .wishbone_ack_i(iwishbone_ack_i),
									 .wishbone_addr_o(iwishbone_addr_o),
									 .wishbone_data_o(iwishbone_data_o),
									 .wishbone_we_o(iwishbone_we_o),
									 .wishbone_sel_o(iwishbone_sel_o),
									 .wishbone_stb_o(iwishbone_stb_o),
									 .wishbone_cyc_o(iwishbone_cyc_o),
									 
									 .stallreq(stallreq_from_if)
	);
	
endmodule
