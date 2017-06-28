`include "defines.v"

/* 依據運算類型、運算子類型、來源運算元1、來源運算元2、要寫入的目的暫存器位址來進行運算 */
module ex(rst, alusel_i, aluop_i, reg1_i, reg2_i, wd_i, wreg_i, inst_i, excepttype_i, current_inst_address_i, hi_i, lo_i, wb_hi_i, wb_lo_i, wb_whilo_i, mem_hi_i, mem_lo_i, mem_whilo_i,
		  is_in_delayslot_i, link_address_i, hilo_temp_i, cnt_i, div_result_i, div_ready_i, wd_o, wreg_o, wdata_o, hi_o, lo_o, whilo_o,
		  mem_cp0_reg_we, mem_cp0_reg_write_addr, mem_cp0_reg_data, wb_cp0_reg_we, wb_cp0_reg_write_addr, wb_cp0_reg_data, cp0_reg_data_i, cp0_reg_read_addr_o,
		  hilo_temp_o, cnt_o, div_opdata1_o, div_opdata2_o, div_start_o, signed_div_o, cp0_reg_we_o, cp0_reg_write_addr_o, cp0_reg_data_o, aluop_o,
		  mem_addr_o, reg2_o, excepttype_o, is_in_delayslot_o, current_inst_address_o, stallreq);

	input wire 							rst;					/* 重設訊號 */
	
	/* 解碼階段送到執行階段的資訊 */
	input wire [`AluOpBus]				aluop_i;				/* 執行階段要進行的運算的子類型 */
	input wire [`AluSelBus]	 			alusel_i;				/* 執行階段要進行的運算的類型 */
	input wire [`RegBus]				reg1_i;					/* 參與運算的來源運算元1 */
	input wire [`RegBus]				reg2_i;					/* 參與運算的來源運算元2 */
	input wire [`RegAddrBus] 			wd_i;					/* 指令執行要寫入的目的暫存器位址 */
	input wire							wreg_i;					/* 是否有要寫入的目的暫存器 */
	input wire [`RegBus]				inst_i;					/* 目前處於執行階段的指令 */
	input wire [31:0]					excepttype_i;			/* 解碼階段收集到的異常資訊 */
	input wire [`RegBus]				current_inst_address_i;	/* 執行階段指令的位址 */
	
	/* HILO模組給出的HI、LO暫存器的值 */
	input wire [`RegBus]				hi_i;					/* HILO模組給出的HI暫存器的值 */
	input wire [`RegBus]				lo_i;					/* HILO模組給出的LO暫存器的值 */
	
	/* 回寫階段的指令是否要寫入HI、LO，用於檢測HI、LO暫存器帶來的資料相依問題 */
	input wire [`RegBus]				wb_hi_i;				/* 處於回寫階段的指令要寫入HI暫存器的值 */
	input wire [`RegBus]				wb_lo_i;				/* 處於回寫階段的指令要寫入LO暫存器的值 */
	input wire							wb_whilo_i;				/* 處於回寫階段的指令是否要寫入HI、LO暫存器 */
	
	/* 存取記憶體階段的指令是否要寫入HI、LO，用於檢測HI、LO暫存器帶來的資料相依問題 */
	input wire [`RegBus]				mem_hi_i;				/* 處於存取記憶體階段的指令要寫入HI暫存器的值 */
	input wire [`RegBus]				mem_lo_i;				/* 處於存取記憶體階段的指令要寫入LO暫存器的值 */
	input wire							mem_whilo_i;			/* 處於存取記憶體階段的指令是否要寫入HI、LO暫存器 */
	
	/* 用於乘累加、乘累減指令 */
	input wire [`DoubleRegBus]			hilo_temp_i;			/* 第一個執行週期得到的乘法結果 */
	input wire [1:0]					cnt_i;					/* 目前處於執行階段的第幾個時脈週期 */
	
	/* 與除法模組相連 */
	input wire [`DoubleRegBus]			div_result_i;			/* 除法運算結果 */
	input wire							div_ready_i;			/* 除法運算是否結束 */
	
	/* 來自ID/EX的資訊*/
	/*是否轉移、以及link address */
	input wire							is_in_delayslot_i;		/* 目前處於執行階段的指令是否位於延遲槽 */
	input wire [`RegBus]				link_address_i;			/* 處於執行階段的轉移指令要保存的返回位址 */
	
	/* 存取記憶體階段的指令是否要寫入CP0中的暫存器，用來檢測資料相依 */
	input wire							mem_cp0_reg_we;			/* 存取記憶體階段的指令是否要寫入CP0中的暫存器 */
	input wire [4:0]					mem_cp0_reg_write_addr;	/* 存取記憶體階段的指令要寫入的CP0中暫存器的位址 */
	input wire [`RegBus]				mem_cp0_reg_data;		/* 存取記憶體階段的指令要寫入CP0中暫存器的資料 */
	
	/* 回寫階段的指令是否要寫入CP0中的暫存器，也是用來檢測資料相依 */
	input wire							wb_cp0_reg_we;			/* 回寫階段的指令是否要寫入CP0中的暫存器 */
	input wire [4:0]					wb_cp0_reg_write_addr;	/* 回寫階段的指令要寫入的CP0中暫存器的位址 */
	input wire [`RegBus]				wb_cp0_reg_data;		/* 回寫階段的指令要寫入CP0中暫存器的資料 */
	
	/* 與CP0直接相連，用於讀取其中指定暫存器的值 */
	input wire [`RegBus]				cp0_reg_data_i;			/* 從CP0模組讀取的指定暫存器的值 */
	output reg [4:0]					cp0_reg_read_addr_o;	/* 執行階段的指令要讀取CP0中暫存器的位址 */
	
	/* 執行的結果 */
	output reg [`RegAddrBus] 			wd_o;					/* 執行階段的指令最終要寫入的目的暫存器位址 */
	output reg 							wreg_o;					/* 執行階段的指令最終是否有要寫入的目的暫存器 */
	output reg [`RegBus]				wdata_o;				/* 執行階段的指令最終要寫入目的暫存器的值 */
	
	/* 處於執行階段的指令對HI、LO暫存器的寫入操作請求 */
	output reg [`RegBus]				hi_o;					/* 執行階段的指令要寫入HI暫存器的值 */
	output reg [`RegBus]				lo_o;					/* 執行階段的指令要寫入LO暫存器的值 */
	output reg							whilo_o;				/* 執行階段的指令是否要寫入HI、LO暫存器 */
	
	/* 用於乘累加、乘累減指令 */
	output reg [`DoubleRegBus]			hilo_temp_o;			/* 第一個執行週期得到的乘法結果 */
	output reg [1:0]					cnt_o;					/* 下一個時脈週期處於執行階段的第幾個時脈週期 */
	
	/* 新增到除法模組的輸出 */
	output reg [`RegBus]				div_opdata1_o;			/* 被除數 */
	output reg [`RegBus]				div_opdata2_o;			/* 除數 */
	output reg							div_start_o;			/* 是否開始除法運算 */
	output reg							signed_div_o;			/* 是否小於零，進而判斷第一個運算元reg1_i是否小於第二個運算元reg2_i */
	
	/* 向管線下一級傳遞，用於寫入CP0中的指定暫存器 */
	output reg							cp0_reg_we_o;			/* 執行階段的指令是否要寫入CP0中的暫存器 */
	output reg [4:0]					cp0_reg_write_addr_o;	/* 執行階段的指令要寫入CP0中暫存器的位址 */
	output reg [`RegBus]				cp0_reg_data_o;			/* 執行階段的指令要寫入CP0中暫存器的資料 */
	
	/* 用於載入、儲存指令 */
	output wire [`AluOpBus]				aluop_o;				/* 執行階段的指令要進行的運算子類型 */
	output wire [`RegBus]				mem_addr_o;				/* 載入、儲存指令對應的記憶體位址 */
	output wire [`RegBus]				reg2_o;					/* 儲存指令要儲存的資料，或者lwl、lwr指令要載入到的目的暫存器的原始值 */

	/* 用於異常處理 */
	output wire [31:0]					excepttype_o;			/* 解碼階段、執行階段收集到的異常資訊 */
	output wire							is_in_delayslot_o;		/* 執行階段的指令是否是延遲槽的指令 */
	output wire [`RegBus]				current_inst_address_o;	/* 執行階段指令的位址 */
	
	/* 送到控制模組與除法模組的資訊 */
	output reg							stallreq;				/* 管線暫停訊號 */
	
	reg [`RegBus] 			logicout;							/* 保存邏輯運算結果 */	
	reg [`RegBus] 			shiftres;							/* 保存移位運算結果 */
	reg [`RegBus] 			moveres;							/* 移動操作結果 */
	reg [`RegBus] 			HI;									/* 保存HI暫存器的最新值 */	
	reg [`RegBus] 			LO;									/* 保存LO暫存器的最新值 */
	wire 				 	ov_sum;								/* 保存溢位情況 */
	wire 				 	reg1_eq_reg2;						/* 第一個運算元是否等於第二個運算元 */
	wire 					reg1_lt_reg2;						/* 第一個運算元是否小於第二個運算元 */
	reg	 [`RegBus] 			arithmeticres;						/* 保存算術運算的結果 */
	wire [`RegBus] 			reg2_i_mux;							/* 保存輸入的第二個運算元reg2_i的補碼 */
	wire [`RegBus] 			reg1_i_not;							/* 保存輸入的第一個運算元reg1_i取反後的值 */
	wire [`RegBus] 			result_sum;							/* 保存加法結果 */
	wire [`RegBus] 			opdata1_mult;						/* 乘法運算中的被乘數 */
	wire [`RegBus] 			opdata2_mult;						/* 乘法運算中的乘數 */
	wire [`DoubleRegBus]	hilo_temp;							/* 臨時保存乘法結果，寬度為64位元 */
	reg  [`DoubleRegBus]	hilo_temp1;							/* 臨時保存乘法結果，用在乘累加、乘累減指令 */
	reg	 [`DoubleRegBus]	mulres;								/* 保存乘法結果，寬度為64位元 */
	reg						stallreq_for_madd_msub;				/* 給乘累加、乘累減的管線暫停訊號 */
	reg  					stallreq_for_div;					/* 是否由於除法運算導致管線暫停 */
	reg						trapassert;							/* 表示是否有自陷異常 */
	reg						ovassert;							/* 表示是否有溢位異常 */
	
	/* aluop_o會傳遞到存取記憶體階段，屆時將利用其確定載入、儲存類型 */
	assign aluop_o = aluop_i;
	
	/* mem_addr_o會傳遞到存取記憶體階段，是載入、儲存指令對應的記憶體位址，此處的reg1_i就是載入、儲存指令中位址為base的通用暫存器的值，
	** inst_i[15:0]就是指令中的offset。*/
	assign mem_addr_o = reg1_i + {{16{inst_i[15]}}, inst_i[15:0]};
	
	/* reg2_i是儲存指令要儲存的資料，或者lwl、lwr指令要載入到的目的暫存器的原始值，該值將透過reg2_o介面傳遞到存取記憶體階段 */
	assign reg2_o = reg2_i;
	
	/* 執行階段輸出的異常資訊就是解碼階段的異常資訊加上自陷異常、溢位異常的資訊，其中第10bit表示是否有自陷異常，第11bit表示是否有溢位異常 */
	assign excepttype_o = {excepttype_i[31:12], ovassert, trapassert, excepttype_i[9:8], 8'h00};
	
	/* is_in_delayslot_i表示目前指令是否在延遲槽中 */
	assign is_in_delayslot_o = is_in_delayslot_i;
	
	/* 目前執行階段指令的位址 */
	assign current_inst_address_o = current_inst_address_i;
		
	/* 得到最新的HI、LO暫存器的值，此處要解決資料相依問題 */
	always @( * )
		begin
			if(rst == `RstEnable)
				{HI, LO} <= {`ZeroWord, `ZeroWord};
			/* 存取記憶體階段的指令要寫入HI、LO暫存器 */
			else if(mem_whilo_i == `WriteEnable)
				{HI, LO} <= {mem_hi_i, mem_lo_i};
			/* 回寫階段的指令要寫入HI、LO暫存器 */
			else if(wb_whilo_i == `WriteEnable)
				{HI, LO} <= {wb_hi_i, wb_lo_i};
			else
				{HI, LO} <= {hi_i, lo_i};
		end
	
	/* 依據aluop_i指示的運算子類型進行邏輯運算 */
	always @( * )
		begin
			if(rst == `RstEnable)
				logicout <= `ZeroWord;
			else
				begin
					case(aluop_i)
						/* 邏輯 "或" 運算 */
						`EXE_OR_OP:
							logicout <= reg1_i | reg2_i;
						/* 邏輯 "與" 運算 */
						`EXE_AND_OP:
							logicout <= reg1_i & reg2_i;
						/* 邏輯 "或非" 運算 */
						`EXE_NOR_OP:
							logicout <= ~(reg1_i | reg2_i);
						/* 邏輯 "異或" 運算 */
						`EXE_XOR_OP:
							logicout <= reg1_i ^ reg2_i;
						default:
							logicout <= `ZeroWord;
					endcase
				end /* if rst */
		end /* always */
		
	/* 依據aluop_i指示的運算子類型進行移位運算 */
	always @( * )
		begin
			if(rst == `RstEnable)
				shiftres <= `ZeroWord;
			else
				begin
					case(aluop_i)
						/* 邏輯左移 */
						`EXE_SLL_OP:
							shiftres <= reg2_i << reg1_i[4:0];
						/* 邏輯右移 */
						`EXE_SRL_OP:
							shiftres <= reg2_i >> reg1_i[4:0];
						/* 算術右移 */
						`EXE_SRA_OP:
							shiftres <= ({32{reg2_i[31]}} << (6'd32 - {1'b0, reg1_i[4:0]})) | reg2_i >> reg1_i[4:0];
						default:
							shiftres <= `ZeroWord;
					endcase
				end /* if rst */
		end /* always */
	
	/* 計算以下5個變數的值 */
	/* (1)如果是減法運算、有號比較運算、有號自陷指令，那麼reg2_i_mux等於第二個運算元reg2_i的補碼，否則reg2_i_mux就等於第二個運算元reg2_i */
	assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP)  || (aluop_i == `EXE_SUBU_OP) || (aluop_i == `EXE_SLT_OP) || (aluop_i == `EXE_TLT_OP) ||
						 (aluop_i == `EXE_TLTI_OP) || (aluop_i == `EXE_TGE_OP)  || (aluop_i == `EXE_TGEI_OP))
							? (~reg2_i) + 1 : reg2_i;
	
	/* (2)計算變數result_sum的值，分三種情況：
	**		A. 如果是加法運算，此時reg2_i_mux就是第二個運算元reg2_i，所以result_sum就是加法運算的結果
	**		B. 如果是減法運算，此時reg2_i_mux就是第二個運算元reg2_i的補碼，所以result_sum就是減法運算的結果
	**		C. 如果是有號比較運算或有號自陷指令，此時reg2_i_mux也等於reg2_i的補碼，所以result_sum就是減法運算的結果，可以透過判斷減法的結果
	**		   是否小於零，進而判斷第一個運算元reg1_i是否小於第二個運算元reg2_i */
	assign result_sum = reg1_i + reg2_i_mux;
	
	/* (3)計算是否溢位，加法指令(add和addi)、減法指令(sub)執行的時候，需要判斷是否溢位，滿足以下兩種情況之一時，有溢位：
	**		A. reg1_i為正數，reg2_i_mux為正數，但是兩者之和為負數
	**		B. reg1_i為負數，reg2_i_mux為負數，但是兩者之和為正數*/
	assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));
	
	/* (4)計算運算元1是否小於運算元2，分兩種情況：
	**		A. 目前指令為有號比較指令或者有號自陷異常指令的時候，此時又分3種情況
	**			A1. reg1_i為負數、reg2_i為正數，顯然reg1_i小於reg2_i
	**			A2. reg1_i為正數、reg2_i為正數，並且reg1_i減去reg2_i的值小於0(即result_sum為負)，此時也有reg1_i小於reg2_i
	**			A3. reg1_i為負數、reg2_i為負數，並且reg1_i減去reg2_i的值小於0(即result_sum為負)，此時也有reg1_i小於reg2_i
	**		B. 目前指令為無號比較指令或者無號自陷異常指令的時候，直接使用比較運算子比較reg1_i與reg2_i*/
	assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP) || (aluop_i == `EXE_TLT_OP) || (aluop_i == `EXE_TLTI_OP) || (aluop_i == `EXE_TGE_OP) ||
						   (aluop_i == `EXE_TGEI_OP))
							  ? ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i && result_sum[31]) || 
							    (reg1_i[31] && reg2_i[31] && result_sum[31])) : (reg1_i < reg2_i);
	
	/* (5)對運算元1逐位取反，指派給reg1_i_not */
	assign reg1_i_not = ~reg1_i;
	
	/* 依據不同的算術運算類型，給arithmeticres變數指派 */
	always @( * )
		begin
			if(rst == `RstEnable)
				arithmeticres <= `ZeroWord;
			else
				begin
					/* aluop_i為運算類型 */
					case(aluop_i)
						/* 比較運算 */
						`EXE_SLT_OP, `EXE_SLTU_OP:
							arithmeticres <= reg1_lt_reg2;
						/* 加法運算 */
						`EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP:
							arithmeticres <= result_sum;
						/* 減法運算 */
						`EXE_SUB_OP, `EXE_SUBU_OP:
							arithmeticres <= result_sum;
						/* 計數運算clz */
						`EXE_CLZ_OP:
							arithmeticres <= reg1_i[31] ? 0  : reg1_i[30] ? 1  : reg1_i[29] ? 2  :
											 reg1_i[28] ? 3  : reg1_i[27] ? 4  : reg1_i[26] ? 5  :
											 reg1_i[25] ? 6  : reg1_i[24] ? 7  : reg1_i[23] ? 8  :
											 reg1_i[22] ? 9  : reg1_i[21] ? 10 : reg1_i[20] ? 11 :
											 reg1_i[19] ? 12 : reg1_i[18] ? 13 : reg1_i[17] ? 14 :
											 reg1_i[16] ? 15 : reg1_i[15] ? 16 : reg1_i[14] ? 17 :
											 reg1_i[13] ? 18 : reg1_i[12] ? 19 : reg1_i[11] ? 20 :
											 reg1_i[10] ? 21 : reg1_i[9]  ? 22 : reg1_i[8]  ? 23 :
											 reg1_i[7]  ? 24 : reg1_i[6]  ? 25 : reg1_i[5]  ? 26 :
											 reg1_i[4]  ? 27 : reg1_i[3]  ? 28 : reg1_i[2]  ? 29 :
											 reg1_i[1]  ? 30 : reg1_i[0]  ? 31 : 32;
						/* 計數運算clo */
						`EXE_CLO_OP:
							arithmeticres <= (reg1_i_not[31] ? 0  : reg1_i_not[30] ? 1  : reg1_i_not[29] ? 2  :
											  reg1_i_not[28] ? 3  : reg1_i_not[27] ? 4  : reg1_i_not[26] ? 5  :
											  reg1_i_not[25] ? 6  : reg1_i_not[24] ? 7  : reg1_i_not[23] ? 8  :
											  reg1_i_not[22] ? 9  : reg1_i_not[21] ? 10 : reg1_i_not[20] ? 11 :
											  reg1_i_not[19] ? 12 : reg1_i_not[18] ? 13 : reg1_i_not[17] ? 14 :
											  reg1_i_not[16] ? 15 : reg1_i_not[15] ? 16 : reg1_i_not[14] ? 17 :
											  reg1_i_not[13] ? 18 : reg1_i_not[12] ? 19 : reg1_i_not[11] ? 20 :
											  reg1_i_not[10] ? 21 : reg1_i_not[9]  ? 22 : reg1_i_not[8]  ? 23 :
											  reg1_i_not[7]  ? 24 : reg1_i_not[6]  ? 25 : reg1_i_not[5]  ? 26 :
											  reg1_i_not[4]  ? 27 : reg1_i_not[3]  ? 28 : reg1_i_not[2]  ? 29 :
											  reg1_i_not[1]  ? 30 : reg1_i_not[0]  ? 31 : 32);
						default:					 
							begin
								arithmeticres <= `ZeroWord;
							end							
					endcase /* case aluop_i */
				end
		end
		
	/* 判斷是否發生自陷異常 */
	/* 依據上面得到的比較結果，判斷是否滿足自陷指令的條件，從而給出變數trapassert的值 */
	always @( * )
		begin
			if(rst == `RstEnable)
				trapassert	<=	`TrapNotAssert;
			else
				begin
					/* 預設沒有自陷異常 */
					trapassert	<=	`TrapNotAssert;
					
					case(aluop_i)
						/* teq、teqi指令 */
						`EXE_TEQ_OP, `EXE_TEQI_OP:
							begin
								if(reg1_i == reg2_i)
									trapassert	<=	`TrapAssert;
							end
						/* tge、tgei、tgeiu、tgeu指令 */
						`EXE_TGE_OP, `EXE_TGEI_OP, `EXE_TGEIU_OP, `EXE_TGEU_OP:
							begin
								if(~reg1_lt_reg2)
									trapassert	<=	`TrapAssert;
							end
						/* tlt、tlti、tltiu、tltu指令 */
						`EXE_TLT_OP, `EXE_TLTI_OP, `EXE_TLTIU_OP, `EXE_TLTU_OP:
							begin
								if(reg1_lt_reg2)
									trapassert	<=	`TrapAssert;
							end
						/* tne、tnei指令 */
						`EXE_TNE_OP, `EXE_TNEI_OP:
							begin
								if(reg1_i != reg2_i)
									trapassert	<=	`TrapAssert;
							end
						default:
							begin
								trapassert	<=	`TrapNotAssert;
							end
					endcase /* case aluop_i */
				end
		end
		
	/* 進行乘法運算 */
	/* (1)取得乘法運算的被乘數，指令madd、msub都是有號乘法，如果第一個運算元reg1_i是負數，那麼取reg1_i的補碼作為被乘數；
	**    反之，直接使用reg1_i作為被乘數 */
	assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && (reg1_i[31] == 1'b1))
								? (~reg1_i + 1) : reg1_i;
	
	/* (2)取得乘法運算的乘數，指令madd、msub都是有號乘法，如果第二個運算元reg2_i是負數，那麼取reg2_i的補碼作為被乘數；
    **    反之，直接使用reg2_i作為乘數 */
	assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && (reg2_i[31] == 1'b1))
								? (~reg2_i + 1) : reg2_i;
								
	/* (3)得到臨時乘法結果，保存在變數hilo_temp中 */
	assign hilo_temp = opdata1_mult * opdata2_mult;
	
	/* (4)對臨時乘法結果進行修正，最終的乘法結果保存在變數mulres中，主要有兩點：
	**		A. 如果是有號乘法運算madd、msub，那麼需要修正臨時乘法結果，如下：
	**			A1. 如果被乘數與乘數兩者一正一負，那麼需要對臨時乘法結果hilo_temp求補碼，作為最終的乘法結果，指派給變數mulres。
	**			A2. 如果被乘數與乘數同號，那麼hilo_temp的值就作mulres的值。
	**		B. 如果是無號乘法運算maddu、msubu，那麼hilo_temp的值就作為最終的乘法結果，指派給變數mulres */
	always @( * )
		begin
			if(rst == `RstEnable)
				mulres <= {`ZeroWord, `ZeroWord};
			else if((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP))
				begin
					if(reg1_i[31] ^ reg2_i[31] == 1'b1)
						mulres <= ~hilo_temp + 1;
					else
						mulres <= hilo_temp;
				end
			else
				mulres <= hilo_temp;
		end
							  
	/* MFHI、MFLO、MOVN、MOVZ指令 */
	/* 獲得CP0中指定暫存器的值 */
	always @( * )
		begin
			if(rst == `RstEnable)
				moveres <= `ZeroWord;
			else
				begin
					moveres <= `ZeroWord;
					
					case(aluop_i)
						/* 如果是mfhi指令，那麼將HI的值作為移動操作的結果 */
						`EXE_MFHI_OP:
							moveres <= HI;
						/* 如果是mflo指令，那麼將LO的值作為移動操作的結果 */
						`EXE_MFLO_OP:
							moveres <= LO;
						/* 如果是movz指令，那麼將reg1_i的值作為移動操作的結果 */
						`EXE_MOVZ_OP:
							moveres <= reg1_i;
						/* 如果是movn指令，那麼將reg1_i的值作為移動操作的結果 */
						`EXE_MOVN_OP:
							moveres <= reg1_i;
						`EXE_MFC0_OP:
							begin
								/* 要從CP0中讀取的暫存器的位址 */
								cp0_reg_read_addr_o	<=	inst_i[15:11];
								
								/* 讀取到的CP0中指定暫存器的值 */
								moveres				<=	cp0_reg_data_i;
								
								/* 判斷是否存在資料相依 */
								if((mem_cp0_reg_we == `WriteEnable) && (mem_cp0_reg_write_addr == inst_i[15:11]))
									begin
										/* 與資料記憶體階段存在資料相依 */
										moveres		<=	mem_cp0_reg_data;
									end
								else if((wb_cp0_reg_we == `WriteEnable) && (wb_cp0_reg_write_addr == inst_i[15:11]))
									begin
										/* 與回寫階段存在資料相依 */
										moveres		<=	wb_cp0_reg_data;
									end
							end
						default:
							begin
							end						
					endcase /* case aluop_i*/
				end				
		end
	
	/* MADD、MADDU、MSUB、MSUBU指令 */
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					hilo_temp_o 			<= {`ZeroWord, `ZeroWord};
					cnt_o					<= 2'b00;
					stallreq_for_madd_msub 	<= `NoStop;
				end
			else
				begin
					case(aluop_i)
						/* madd、maddu指令 */
						`EXE_MADD_OP, `EXE_MADDU_OP:
							begin
								/* 執行階段第一個時脈週期 */
								if(cnt_i == 2'b00)
									begin
										hilo_temp_o 			<= mulres;
										cnt_o					<= 2'b01;
										hilo_temp1				<= {`ZeroWord, `ZeroWord};
										stallreq_for_madd_msub 	<= `Stop;
									end
								/* 執行階段第二個時脈週期 */
								else if(cnt_i == 2'b01)
									begin
										hilo_temp_o				<= {`ZeroWord, `ZeroWord};
										cnt_o					<= 2'b10;
										hilo_temp1				<= hilo_temp_i + {HI, LO};
										stallreq_for_madd_msub	<= `NoStop;
									end
							end
						/* msub、msubu指令 */
						`EXE_MSUB_OP, `EXE_MSUBU_OP:
							begin
								/* 執行階段第一個時脈週期 */
								if(cnt_i == 2'b00)
									begin
										hilo_temp_o 			<= ~mulres + 1;
										cnt_o					<= 2'b01;
										stallreq_for_madd_msub 	<= `Stop;
									end
								/* 執行階段第二個時脈週期 */
								else if(cnt_i == 2'b01)
									begin
										hilo_temp_o				<= {`ZeroWord, `ZeroWord};
										cnt_o					<= 2'b10;
										hilo_temp1				<= hilo_temp_i + {HI, LO};
										stallreq_for_madd_msub	<= `NoStop;
									end
							end
						default:
							begin
								hilo_temp_o				<= {`ZeroWord, `ZeroWord};
								cnt_o					<= 2'b00;
								stallreq_for_madd_msub	<= `NoStop;
							end
					endcase /* case aluop_i */
				end
		end
		
	/* DIV、DIVU指令 */
	/* 輸出DIV模組控制資訊，獲取DIV模組給出的結果 */
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					stallreq_for_div <= `NoStop;
					div_opdata1_o	 <= `ZeroWord;
					div_opdata2_o	 <= `ZeroWord;
					div_start_o		 <= `DivStop;
					signed_div_o	 <= 1'b0;
				end
			else
				begin
					stallreq_for_div <= `NoStop;
					div_opdata1_o	 <= `ZeroWord;
					div_opdata2_o	 <= `ZeroWord;
					div_start_o		 <= `DivStop;
					signed_div_o	 <= 1'b0;
					
					case(aluop_i)
						/* div指令 */
						`EXE_DIV_OP:
							begin
								if(div_ready_i == `DivResultNotReady)
									begin
										div_opdata1_o	 <= reg1_i;			/* 被除數 */
										div_opdata2_o	 <= reg2_i;			/* 除數 */
										div_start_o		 <= `DivStart;		/* 開始除法運算 */
										signed_div_o	 <= 1'b1;			/* 有號除法 */
										stallreq_for_div <= `Stop;			/* 請求管線暫停 */
									end
								else if(div_ready_i == `DivResultReady)
									begin
										div_opdata1_o	 <= reg1_i;			
										div_opdata2_o	 <= reg2_i;			
										div_start_o		 <= `DivStop;		/* 結束除法運算 */
										signed_div_o	 <= 1'b1;			
										stallreq_for_div <= `NoStop;		/* 不再請求管線暫停 */
									end
								else
									begin
										div_opdata1_o	 <= `ZeroWord;
										div_opdata2_o	 <= `ZeroWord;
										div_start_o		 <= `DivStop;
										signed_div_o	 <= 1'b0;
										stallreq_for_div <= `NoStop;
									end
							end
						/* divu指令 */
						`EXE_DIVU_OP:
							begin
								if(div_ready_i == `DivResultNotReady)
									begin
										div_opdata1_o	 <= reg1_i;			/* 被除數 */
										div_opdata2_o	 <= reg2_i;			/* 除數 */
										div_start_o		 <= `DivStart;		/* 開始除法運算 */
										signed_div_o	 <= 1'b0;			/* 無號除法 */
										stallreq_for_div <= `Stop;			/* 請求管線暫停 */
									end
								else if(div_ready_i == `DivResultReady)
									begin
										div_opdata1_o	 <= reg1_i;
										div_opdata2_o	 <= reg2_i;
										div_start_o		 <= `DivStop;
										signed_div_o	 <= 1'b0;
										stallreq_for_div <= `NoStop;
									end
								else
									begin
										div_opdata1_o	 <= `ZeroWord;
										div_opdata2_o	 <= `ZeroWord;
										div_start_o		 <= `DivStop;
										signed_div_o	 <= 1'b0;
										stallreq_for_div <= `NoStop;
									end
							end
						default:
							begin
							end
					endcase /* case aluop_i */
				end
		end
		
	/* 暫停管線 */
	/* 目前只有乘累加、乘累減指令會導致管線暫停，所以stallreq就直接等於stallreq_for_madd_msub的值 */
	always @( * )
		begin
			stallreq = stallreq_for_madd_msub || stallreq_for_div;
		end
	
	/* 確定最終要寫入目的暫存器的值 */
	/* 依據指令類型以及ov_sum的值，判斷是否發生溢位異常，從而給出變數ovassert的值 */
	always @( * )
		begin
			wd_o <= wd_i;
			
			/* 如果是add、addi、sub、subi指令，且發生溢位，那麼設定wreg_o為WriteDisable，表示不寫入目的暫存器 */
			if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1))
				begin
					wreg_o 	 <= `WriteDisable;
					ovassert <= 1'b1;				/* 發生了溢位異常 */
				end
			else
				begin
					wreg_o 	 <= wreg_i;
					ovassert <=	1'b0;				/* 沒有發生溢位異常 */
				end
				
			case(alusel_i)
				/* 選擇邏輯運算結果為最終運算結果 */
				`EXE_RES_LOGIC:
					wdata_o <= logicout;
				/* 選擇移位運算結果為最終運算結果 */
				`EXE_RES_SHIFT:
					wdata_o <= shiftres;
				/* 選擇移動操作結果為最終運算結果 */
				`EXE_RES_MOVE:
					wdata_o <= moveres;
				/* 除乘法外的簡單算數指令 */
				`EXE_RES_ARITHMETIC:
					wdata_o <= arithmeticres;
				/* 乘法指令mul */
				`EXE_RES_MUL:
					wdata_o <= mulres[31:0];
				`EXE_RES_JUMP_BRANCH:
					wdata_o <= link_address_i;
				default:
					wdata_o <= `ZeroWord;
			endcase /* case alusel_i */
		end
	
	/* 確定對HI、LO暫存器的操作資訊 */
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					whilo_o <= `WriteDisable;
					hi_o 	<= `ZeroWord;
					lo_o	<= `ZeroWord;
				end
			else if((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP))
				begin
					whilo_o <= `WriteEnable;
					hi_o	<= mulres[63:32];
					lo_o	<= mulres[31:0];
				end
			else if((aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MADDU_OP))
				begin
					whilo_o <= `WriteEnable;
					hi_o	<= hilo_temp1[63:32];
					lo_o	<= hilo_temp1[31:0];
				end
			else if((aluop_i == `EXE_MSUB_OP) || (aluop_i == `EXE_MSUBU_OP))
				begin
					whilo_o <= `WriteEnable;
					hi_o	<= hilo_temp1[63:32];
					lo_o	<= hilo_temp1[31:0];
				end
			else if((aluop_i == `EXE_DIV_OP) || (aluop_i == `EXE_DIVU_OP))
				begin
					whilo_o <= `WriteEnable;
					hi_o	<= div_result_i[63:32];
					lo_o	<= div_result_i[31:0];
				end
			else if(aluop_i == `EXE_MTHI_OP)
				begin
					whilo_o <= `WriteEnable;
					hi_o	<= reg1_i;
					lo_o	<= LO;				/* 寫入HI暫存器，所以LO保持不變 */
				end
			else if(aluop_i == `EXE_MTLO_OP)
				begin
					whilo_o <= `WriteEnable;
					hi_o	<= HI;				/* 寫入LO暫存器，所以HI保持不變 */
					lo_o	<= reg1_i;
				end
			else
				begin
					whilo_o <= `WriteDisable;
					hi_o	<= `ZeroWord;
					lo_o	<= `ZeroWord;
				end
		end
	
	/* 給出mtc0指令的執行結果 */
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					cp0_reg_write_addr_o	<=	5'b00000;
					cp0_reg_we_o			<=	`WriteDisable;
					cp0_reg_data_o			<=	`ZeroWord;
				end
			/* 是mtc0指令 */
			else if(aluop_i == `EXE_MTC0_OP)
				begin
					cp0_reg_write_addr_o	<=	inst_i[15:11];
					cp0_reg_we_o			<=	`WriteEnable;
					cp0_reg_data_o			<=	reg1_i;
				end
			else
				begin
					cp0_reg_write_addr_o	<=	5'b00000;
					cp0_reg_we_o			<=	`WriteDisable;
					cp0_reg_data_o			<=	`ZeroWord;
				end
		end
		
endmodule
