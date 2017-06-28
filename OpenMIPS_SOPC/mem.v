`include "defines.v"

/* 由於ori指令不需要存取資料記憶體，所以在存取記憶體階段不做任何事，只是簡單地將執行階段的結果向回寫階段傳遞 */
module mem(rst, wd_i, wreg_i, wdata_i, hi_i, lo_i, whilo_i, aluop_i, mem_addr_i, reg2_i, mem_data_i, LLbit_i, wb_LLbit_we_i, wb_LLbit_value_i, cp0_reg_we_i, cp0_reg_write_addr_i, cp0_reg_data_i,
		   excepttype_i, is_in_delayslot_i, current_inst_address_i, cp0_status_i, cp0_cause_i, cp0_epc_i, wd_o, wreg_o, wdata_o, hi_o, lo_o, whilo_o, mem_addr_o, mem_we_o, mem_sel_o, mem_data_o, 
		   wb_cp0_reg_we, wb_cp0_reg_write_addr, wb_cp0_reg_data, mem_ce_o, LLbit_we_o, LLbit_value_o, cp0_reg_we_o, cp0_reg_write_addr_o, cp0_reg_data_o, excepttype_o, cp0_epc_o, is_in_delayslot_o,
		   current_inst_address_o);

	input wire 							rst;					/* 重設訊號 */
	
	/* 來自執行階段的資訊 */
	input wire [`RegAddrBus]			wd_i;					/* 存取記憶體階段的指令要寫入的目的暫存器位址 */
	input wire					 		wreg_i;					/* 存取記憶體階段的指令是否有要寫入的目的暫存器 */
	input wire [`RegBus]				wdata_i;				/* 存取記憶體階段的指令要寫入目的暫存器的值*/
	input wire [`RegBus]				hi_i;					/* 存取記憶體階段的指令要寫入HI暫存器的值 */
	input wire [`RegBus]				lo_i;					/* 存取記憶體階段的指令要寫入LO暫存器的值 */
	input wire							whilo_i;				/* 存取記憶體階段的指令是否要寫入HI、LO暫存器 */
	
	/* 新增的介面，來自執行階段的資訊 */
	input wire [`AluOpBus]				aluop_i;				/* 存取記憶體階段的指令要進行運算的子類型 */
	input wire [`RegBus]				mem_addr_i;				/* 存取記憶體階段的載入、儲存指令對應的記憶體位址 */
	input wire [`RegBus]				reg2_i;					/* 存取記憶體階段的儲存指令否儲存的資料，或者lwl、lwr指令要寫入的目的暫存器的原始值 */
	
	/* 來自外部資料記憶體RAM的資訊 */
	input wire [`RegBus]				mem_data_i;				/* 從資料記憶體讀取的資料 */
	
	/* 來自LLbit模組的資訊 */
	input wire							LLbit_i;				/* LLbit模組給出的LLbit暫存器的值 */
	
	/* 來自MEM/WB階段的資訊 */
	input wire							wb_LLbit_we_i;			/* 回寫階段的指令是否要寫入LLbit暫存器 */
	input wire							wb_LLbit_value_i;		/* 回寫階段要寫入LLbit暫存器的值 */
	
	input wire							cp0_reg_we_i;			/* 存取記憶體階段的指令是否要寫入CP0中的暫存器 */
	input wire [4:0]					cp0_reg_write_addr_i;	/* 存取記憶體階段的指令要寫入的CP0中暫存器的位址 */
	input wire [`RegBus]				cp0_reg_data_i;			/* 存取記憶體階段的指令要寫入CP0中暫存器的資料 */
	
	input wire [31:0]					excepttype_i;			/* 解碼、執行階段收集到的異常資訊 */
	input wire							is_in_delayslot_i;		/* 存取記憶體階段的指令是否是延遲槽指令 */
	input wire [`RegBus]				current_inst_address_i;	/* 存取記憶體階段指令的位址 */
	
	/* 來自CP0模組的資訊 */
	input wire [`RegBus]				cp0_status_i;			/* CP0中Status暫存器的值 */
	input wire [`RegBus]				cp0_cause_i;			/* CP0中Cause暫存器的值 */
	input wire [`RegBus]				cp0_epc_i;				/* CP0中EPC暫存器的值 */
	
	/* 來自回寫階段，是回寫階段的指令對CP0中暫存器的寫入資訊，用來檢測資料相依 */
	input wire							wb_cp0_reg_we;			/* 回寫階段的指令是否要寫入CP0中的暫存器 */
	input wire [4:0]					wb_cp0_reg_write_addr;	/* 回寫階段的指令要寫入的CP0中暫存器的位址 */
	input wire [`RegBus]				wb_cp0_reg_data;		/* 回寫階段的指令要寫入CP0中暫存器的值 */
	
	/* 存取記憶體階段的結果 */
	output reg [`RegAddrBus]			wd_o;					/* 存取記憶體階段的指令最終要寫入的目的暫存器位址 */
	output reg 							wreg_o;					/* 存取記憶體階段的指令最終是否有要寫入的目的暫存器 */
	output reg [`RegBus]				wdata_o;				/* 存取記憶體階段的指令最終要寫入目的暫存器的值 */
	output reg [`RegBus]				hi_o;					/* 存取記憶體階段的指令最終要寫入HI暫存器的值 */
	output reg [`RegBus]				lo_o;					/* 存取記憶體階段的指令最終要寫入LO暫存器的值 */
	output reg							whilo_o;				/* 存取記憶體階段的指令最終是否要寫入HI、LO暫存器 */
	
	output reg							LLbit_we_o;				/* 存取記憶體階段的指令是否要寫入LLbit暫存器 */
	output reg							LLbit_value_o;			/* 存取記憶體階段的指令要寫入LLbit暫存器的值 */
	
	output reg							cp0_reg_we_o;			/* 存取記憶體階段的指令最終是否要寫入CP0中的暫存器 */
	output reg [4:0]					cp0_reg_write_addr_o;	/* 存取記憶體階段的指令最終要寫入的CP0中暫存器的位址 */
	output reg [`RegBus]				cp0_reg_data_o;			/* 存取記憶體階段的指令最終要寫入CP0中暫存器的資料 */
	
	output reg [31:0]					excepttype_o;			/* 最終的異常類型 */
	output wire [`RegBus]				cp0_epc_o;				/* CP0中EPC暫存器的最新值 */
	output wire							is_in_delayslot_o;		/* 存取記憶體階段的指令是否是延遲槽指令 */
	output wire [`RegBus]				current_inst_address_o;	/* 存取記憶體階段指令的位址 */
	
	/* 送到外部資料記憶體RAM的資訊 */
	output reg [`RegBus]				mem_addr_o;				/* 要存取的資料記憶體的位址 */
	output wire							mem_we_o;				/* 是否是寫入操作，為1表示是寫入操作 */
	output reg [3:0]					mem_sel_o;				/* 位元組選擇訊號 */
	output reg [`RegBus]				mem_data_o;				/* 要寫入資料記憶體的資料 */
	output reg							mem_ce_o;				/* 資料記憶體啟用訊號 */			
	
	wire [`RegBus]	zero32;
	reg			  	mem_we;
	reg			  	LLbit;			/* 保存LLbit暫存器的最新值 */
	reg  [`RegBus]	cp0_status;		/* 用來保存CP0中Status暫存器的最新值 */
	reg  [`RegBus]	cp0_cause;		/* 用來保存CP0中Cause暫存器的最新值 */
	reg  [`RegBus]	cp0_epc;		/* 用來保存CP0中EPC暫存器的最新值 */
	
	assign zero32	= `ZeroWord;
	
	/* is_in_delayslot_o表示存取記憶體階段的指令是否是延遲槽指令 */
	assign is_in_delayslot_o = is_in_delayslot_i;
	
	/* current_inst_address_o是存取記憶體階段指令的位址 */
	assign current_inst_address_o = current_inst_address_i;
	
	/* 獲取LLbit暫存器的最新值，如果回寫階段的指令要寫入LLbit，那麼回寫階段要寫入的值就是LLbit暫存器的最新值，
	** 反之LLbit模組給出的值LLbit_i是最新值 */
	always @( * )
		begin
			if(rst == `RstEnable)
				LLbit <= 1'b0;
			else
				begin
					if(wb_LLbit_we_i == 1'b1)
						LLbit <= wb_LLbit_value_i;		/* 回寫階段的指令要寫入LLbit */
					else
						LLbit <= LLbit_i;
				end
		end
	
	/* 得到CP0中暫存器的最新值 */
	/* 得到CP0中Status暫存器最新值，步驟如下：
	** 判斷目前處於回寫階段的指令是否要寫入CP0中Status暫存器，如果要寫入，那麼要寫入的值就是Status暫存器的最新值，
	** 反之，從CP0模組透過cp0_status_i介面傳入的資料就是Status暫存器的最新值 */
	always @( * )
		begin
			if(rst == `RstEnable)
				cp0_status	<=	`ZeroWord;
			else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == `CP0_REG_STATUS))
				cp0_status	<=	wb_cp0_reg_data;
			else
				cp0_status	<=	cp0_status_i;
		end
		
	/* 得到CP0中EPC暫存器最新值，步驟如下：
	** 判斷目前處於回寫階段的指令是否要寫入CP0中EPC暫存器，如果要寫入，那麼要寫入的值就是EPC暫存器的最新值，
	** 反之，從CP0模組透過cp0_epc_i介面傳入的數據就是EPC暫存器的最新值 */
	always @( * )
		begin
			if(rst == `RstEnable)
				cp0_epc	<=	`ZeroWord;
			else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == `CP0_REG_EPC))
				cp0_epc	<=	wb_cp0_reg_data;
			else
				cp0_epc	<=	cp0_epc_i;
		end
		
	/* 將EPC暫存器的最新值透過介面cp0_epc_o輸出 */
	assign cp0_epc_o = cp0_epc;
	
	/* 得到CP0中Cause暫存器最新值，步驟如下：
	** 判斷目前處於回寫階段的指令是否要寫入CP0中Cause暫存器，如果要寫入，那麼要寫入的值就是Cause暫存器的最新值，
	** 不過要注意一點：Cause暫存器只有幾個欄位是可寫入的。反之，從CP0模組透過cp0_cause_i介面傳入的資料就是
	** Cause暫存器的最新值 */
	always @( * )
		begin
			if(rst == `RstEnable)
				cp0_cause	<=	`ZeroWord;
			else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == `CP0_REG_CAUSE))
				begin
					cp0_cause[9:8]	<=	wb_cp0_reg_data[9:8];		/* IP[1:0]欄位是可寫入的 */
					cp0_cause[22]	<=	wb_cp0_reg_data[22];		/* WP欄位是可寫入的 */
					cp0_cause[23]	<=	wb_cp0_reg_data[23];		/* IV欄位是可寫入的 */
				end
			else
				cp0_cause	<=	cp0_cause_i;
		end
	
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					wd_o					<=	`NOPRegAddr;
					wreg_o 					<=	`WriteDisable;
					wdata_o					<=	`ZeroWord;
					hi_o					<=	`ZeroWord;
					lo_o					<=	`ZeroWord;
					whilo_o					<=	`WriteDisable;
					mem_addr_o				<=	`ZeroWord;
					mem_we					<=	`WriteDisable;
					mem_sel_o				<=	4'b0000;
					mem_data_o				<=	`ZeroWord;
					mem_ce_o				<=	`ChipDisable;
					LLbit_we_o				<=	1'b0;
					LLbit_value_o			<=	1'b0;
					cp0_reg_we_o			<=	`WriteDisable;
					cp0_reg_write_addr_o	<=	5'b00000;
					cp0_reg_data_o			<=	`ZeroWord;
				end
			else
				begin
					wd_o					<=	wd_i;
					wreg_o 					<=	wreg_i;
					wdata_o					<=	wdata_i;
					hi_o					<=	hi_i;
					lo_o					<=	lo_i;
					whilo_o					<=	whilo_i;
					mem_we					<=	`WriteDisable;
					mem_addr_o				<=	`ZeroWord;
					mem_sel_o				<=	4'b1111;
					mem_ce_o				<=	`ChipDisable;
					LLbit_we_o				<=	1'b0;
					LLbit_value_o			<=	1'b0;
					cp0_reg_we_o			<=	cp0_reg_we_i;
					cp0_reg_write_addr_o	<=	cp0_reg_write_addr_i;
					cp0_reg_data_o			<=	cp0_reg_data_i;
					
					case(aluop_i)
						/* lb指令 */
						`EXE_LB_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteDisable;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											wdata_o		<=	{{24{mem_data_i[31]}}, mem_data_i[31:24]};
											mem_sel_o	<=	4'b1000;
										end
									2'b01:
										begin
											wdata_o		<=	{{24{mem_data_i[23]}}, mem_data_i[23:16]};
											mem_sel_o	<=	4'b0100;
										end
									2'b10:
										begin
											wdata_o		<=	{{24{mem_data_i[15]}}, mem_data_i[15:8]};
											mem_sel_o	<=	4'b0010;
										end
									2'b11:
										begin
											wdata_o		<=	{{24{mem_data_i[7]}}, mem_data_i[7:0]};
											mem_sel_o	<=	4'b0001;
										end
									default:
										begin
											wdata_o		<=	`ZeroWord;
										end
								endcase
							end
						/* lbu指令 */
						`EXE_LBU_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteDisable;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											wdata_o		<=	{{24{1'b0}}, mem_data_i[31:24]};
											mem_sel_o	<=	4'b1000;
										end
									2'b01:
										begin
											wdata_o		<=	{{24{1'b0}}, mem_data_i[23:16]};
											mem_sel_o	<=	4'b0100;
										end
									2'b10:
										begin
											wdata_o		<=	{{24{1'b0}}, mem_data_i[15:8]};
											mem_sel_o	<=	4'b0010;
										end
									2'b11:
										begin
											wdata_o		<=	{{24{1'b0}}, mem_data_i[7:0]};
											mem_sel_o	<=	4'b0001;
										end
									default:
										begin
											wdata_o		<=	`ZeroWord;
										end
								endcase
							end
						/* lh指令 */
						`EXE_LH_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteDisable;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											wdata_o		<=	{{16{mem_data_i[31]}}, mem_data_i[31:16]};
											mem_sel_o	<=	4'b1100;
										end
									2'b10:
										begin
											wdata_o		<=	{{16{mem_data_i[15]}}, mem_data_i[15:0]};
											mem_sel_o	<=	4'b0011;
										end
									default:
										begin
											wdata_o		<=	`ZeroWord;
										end
								endcase
							end
						/* lhu指令 */
						`EXE_LHU_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteDisable;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											wdata_o		<=	{{16{1'b0}}, mem_data_i[31:16]};
											mem_sel_o	<=	4'b1100;
										end
									2'b10:
										begin
											wdata_o		<=	{{16{1'b0}}, mem_data_i[15:0]};
											mem_sel_o	<=	4'b0011;
										end
									default:
										begin
											wdata_o		<=	`ZeroWord;
										end
								endcase
							end
						/* lw指令 */
						`EXE_LW_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteDisable;
								wdata_o		<=	mem_data_i;
								mem_sel_o	<=	4'b1111;
								mem_ce_o	<=	`ChipEnable;
							end
						/* lwl指令 */
						`EXE_LWL_OP:
							begin
								mem_addr_o	<=	{mem_addr_i[31:2], 2'b00};
								mem_we		<=	`WriteDisable;
								mem_sel_o	<=	4'b1111;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											wdata_o	<=	mem_data_i[31:0];
										end
									2'b01:
										begin
											wdata_o	<=	{mem_data_i[23:0], reg2_i[7:0]};
										end
									2'b10:
										begin
											wdata_o	<=	{mem_data_i[15:0], reg2_i[15:0]};
										end
									2'b11:
										begin
											wdata_o	<=	{mem_data_i[7:0], reg2_i[23:0]};
										end
									default:
										begin
											wdata_o	<=	`ZeroWord;
										end
								endcase
							end
						/* lwr指令 */
						`EXE_LWR_OP:
							begin
								mem_addr_o	<=	{mem_addr_i[31:2], 2'b00};
								mem_we		<=	`WriteDisable;
								mem_sel_o	<=	4'b1111;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											wdata_o	<=	{reg2_i[31:8], mem_data_i[31:24]};
										end
									2'b01:
										begin
											wdata_o	<=	{reg2_i[31:16], mem_data_i[31:16]};
										end
									2'b10:
										begin
											wdata_o	<=	{reg2_i[31:24], mem_data_i[31:8]};
										end
									2'b11:
										begin
											wdata_o	<=	mem_data_i;
										end
									default:
										begin
											wdata_o	<=	`ZeroWord;
										end
								endcase
							end
						/* ll指令 */
						`EXE_LL_OP:
							begin
								mem_addr_o		<=	mem_addr_i;
								mem_we			<=	`WriteDisable;
								wdata_o			<=	mem_data_i;
								LLbit_we_o		<=	1'b1;
								LLbit_value_o	<=	1'b1;
								mem_sel_o		<=	4'b1111;
								mem_ce_o		<=	`ChipEnable;
							end
						/* sb指令 */
						`EXE_SB_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteEnable;
								mem_data_o	<=	{reg2_i[7:0], reg2_i[7:0], reg2_i[7:0], reg2_i[7:0]};
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											mem_sel_o	<=	4'b1000;
										end
									2'b01:
										begin
											mem_sel_o	<=	4'b0100;
										end
									2'b10:
										begin
											mem_sel_o	<=	4'b0010;
										end
									2'b11:
										begin
											mem_sel_o	<=	4'b0001;
										end
									default:
										begin
											mem_sel_o	<=	4'b0000;
										end
								endcase
							end
						/* sh指令 */
						`EXE_SH_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteEnable;
								mem_data_o	<=	{reg2_i[15:0], reg2_i[15:0]};
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											mem_sel_o	<=	4'b1100;
										end
									2'b10:
										begin
											mem_sel_o	<=	4'b0011;
										end
									default:
										begin
											mem_sel_o	<=	4'b0000;
										end
								endcase
							end
						/* sw指令 */
						`EXE_SW_OP:
							begin
								mem_addr_o	<=	mem_addr_i;
								mem_we		<=	`WriteEnable;
								mem_data_o	<=	reg2_i;
								mem_sel_o	<=	4'b1111;
								mem_ce_o	<=	`ChipEnable;
							end
						/* swl指令 */
						`EXE_SWL_OP:
							begin
								mem_addr_o	<=	{mem_addr_i[31:2], 2'b00};
								mem_we		<=	`WriteEnable;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											mem_sel_o	<=	4'b1111;
											mem_data_o	<=	reg2_i;
										end
									2'b01:
										begin
											mem_sel_o	<=	4'b0111;
											mem_data_o	<=	{zero32[7:0], reg2_i[31:8]};
										end
									2'b10:
										begin
											mem_sel_o	<=	4'b0011;
											mem_data_o	<=	{zero32[15:0], zero32[31:16]};
										end
									2'b11:
										begin
											mem_sel_o	<=	4'b0001;
											mem_data_o	<=	{zero32[31:0], reg2_i[31:24]};
										end
									default:
										begin
											mem_sel_o	<=	4'b0000;
										end
								endcase
							end
						/* swr指令 */
						`EXE_SWR_OP:
							begin
								mem_addr_o	<=	{mem_addr_i[31:2], 2'b00};
								mem_we		<=	`WriteEnable;
								mem_ce_o	<=	`ChipEnable;
								
								case(mem_addr_i[1:0])
									2'b00:
										begin
											mem_sel_o	<=	4'b1000;
											mem_data_o	<=	{reg2_i[7:0], zero32[23:0]};
										end
									2'b01:
										begin
											mem_sel_o	<=	4'b1100;
											mem_data_o	<=	{reg2_i[15:0], zero32[15:0]};
										end
									2'b10:
										begin
											mem_sel_o	<=	4'b1110;
											mem_data_o	<=	{reg2_i[23:0], zero32[7:0]};
										end
									2'b11:
										begin
											mem_sel_o	<=	4'b1111;
											mem_data_o	<=	reg2_i[31:0];
										end
									default:
										begin
											mem_sel_o	<=	4'b0000;
										end
								endcase
							end
						/* sc指令 */
						`EXE_SC_OP:
							begin
								if(LLbit == 1'b1)
									begin
										LLbit_we_o		<=	1'b1;
										LLbit_value_o	<=	1'b0;
										mem_addr_o		<=	mem_addr_i;
										mem_we			<=	`WriteEnable;
										mem_data_o		<=	reg2_i;
										wdata_o			<=	32'b1;
										mem_sel_o		<=	4'b1111;
										mem_ce_o		<=	`ChipEnable;
									end
								else
									wdata_o <= 32'b0;
							end
						default:
							begin
							end
					endcase /* case by aluop_i */
				end
		end
		
	/* 給出最終的異常類型 */
	always @( * )
		begin
			if(rst == `RstEnable)
				excepttype_o	<=	`ZeroWord;
			else
				begin
					excepttype_o	<=	`ZeroWord;
					
					if(current_inst_address_i != `ZeroWord)
						begin
							/* interrupt */
							if(((cp0_cause[15:8] & cp0_status[15:8]) != 8'h00) &&
									(cp0_status[1] == 1'b0) && (cp0_status[0] == 1'b1))
								excepttype_o	<=	32'h00000001;
							/* syscall */
							else if(excepttype_i[8]  == 1'b1)
								excepttype_o	<=	32'h00000008;
							/* inst_invalid */
							else if(excepttype_i[9]  == 1'b1)
								excepttype_o	<=	32'h0000000a;
							/* trap */
							else if(excepttype_i[10] == 1'b1)
								excepttype_o	<=	32'h0000000d;
							/* ov */
							else if(excepttype_i[11] == 1'b1)
								excepttype_o	<=	32'h0000000c;
							/* eret */
							else if(excepttype_i[12] == 1'b1)
								excepttype_o	<=	32'h0000000e;
						end
				end
		end
	
	/* 給出對資料記憶體的寫入操作 */
	/* mem_we_o輸出到資料記憶體，表示是否是對資料記憶體的寫入操作，如果發現了異常，那麼需要取消對資料記憶體的寫入操作 */
	assign mem_we_o = mem_we & (~(|excepttype_o));
		
endmodule
