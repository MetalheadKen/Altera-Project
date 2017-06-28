`include "defines.v"

/* 解碼的工作主要內容是：確定要讀取的暫存器情況、要執行的運算和要寫入的目的暫存器三方面的資訊 */
/* 對指令進行解碼，得到最終運算的類型、子類型、來源運算元1、來源運算元2、要寫入的目的暫存器位址等資訊 */
module id(rst, pc_i, inst_i, reg1_data_i, reg2_data_i, ex_wreg_i, ex_wdata_i, ex_wd_i, ex_aluop_i, mem_wreg_i, mem_wdata_i, mem_wd_i, is_in_delayslot_i,
		  reg1_read_o, reg2_read_o, reg1_addr_o, reg2_addr_o, aluop_o, alusel_o, reg1_o, reg2_o, wd_o, wreg_o, inst_o, branch_flag_o, 
		  branch_target_address_o, is_in_delayslot_o, link_addr_o, next_inst_in_delayslot_o, excepttype_o, current_inst_address_o, stallreq);

	input wire 							rst;						/* 重設訊號 */
	input wire [`InstAddrBus]			pc_i;						/* 解碼階段的指令對應的位址 */
	input wire [`InstBus]	 			inst_i;						/* 解碼階段的指令 */
	
	/* 讀取的Regfile的值 */
	input wire [`RegBus]				reg1_data_i;				/* 從Regfile輸入的第一個讀取暫存器連接埠的輸入 */
	input wire [`RegBus]				reg2_data_i;				/* 從Regfile輸入的第二個讀取暫存器連接埠的輸入 */
	
	/* 處於執行階段的指令的運算結果 */
	input wire							ex_wreg_i;					/* 處於執行階段的指令是否要寫入目的暫存器 */
	input wire [`RegBus]				ex_wdata_i;					/* 處於執行階段的指令要寫入的目的暫存器位址 */
	input wire [`RegAddrBus]			ex_wd_i;					/* 處於執行階段的指令要寫入目的暫存器的資料 */
	
	/* 來自執行階段的資訊，用來解決load相依 */
	input wire [`AluOpBus]				ex_aluop_i;					/* 處於執行階段指令的運算子類型 */
	
	/* 處於存取記憶體階段的指令的運算結果 */
	input wire							mem_wreg_i;					/* 處於存取記憶體階段的指令是否要寫入目的暫存器 */
	input wire [`RegBus]				mem_wdata_i;				/* 處於存取記憶體階段的指令要寫入的目的暫存器位址 */
	input wire [`RegAddrBus]			mem_wd_i;					/* 處於存取記憶體階段的指令要寫入目的暫存器的資料 */
	
	/* 來自ID/EX模組的資訊 */
	/* 如果上一條指令是轉移指令，那麼下一條指令在解碼的時候is_in_delayslot為true */
	input wire							is_in_delayslot_i;			/* 目前處於解碼階段的指令是否位於延遲槽 */
	
	/* 輸出到Regfile的資訊 */
	output reg 							reg1_read_o;				/* Regfile模組的第一個讀取暫存器連接埠的讀取啟用訊號 */
	output reg 							reg2_read_o;				/* Regfile模組的第二個讀取暫存器連接埠的讀取啟用訊號 */
	output reg [`RegAddrBus]			reg1_addr_o;				/* Regfile模組的第一個讀取暫存器連接埠的讀取位址訊號 */
	output reg [`RegAddrBus]			reg2_addr_o;				/* Regfile模組的第二個讀取暫存器連接埠的讀取位址訊號 */	
	
	/* 送到執行階段的資訊 */
	output reg  [`AluOpBus]				aluop_o;					/* 解碼階段的指令要進行的運算的子類型 */
	output reg  [`AluSelBus] 			alusel_o;					/* 解碼階段的指令要進行的運算的類型 */
	output reg  [`RegBus]				reg1_o;						/* 解碼階段的指令要進行的運算的來源運算元1 */
	output reg  [`RegBus]				reg2_o;						/* 解碼階段的指令要進行的運算的來源運算元2 */
	output reg  [`RegAddrBus] 			wd_o;						/* 解碼階段的指令要寫入的目的暫存器位址 */
	output reg 							wreg_o;						/* 解碼階段的指令是否有要寫入的目的暫存器 */
	output wire [`RegBus]				inst_o;						/* 解碼階段的指令 */
	
	output reg							is_in_delayslot_o;			/* 目前處於解碼階段的指令是否位於延遲槽 */
	output reg  [`RegBus]				link_addr_o;				/* 轉移指令要保存的返回位址 */
	output reg							next_inst_in_delayslot_o;	/* 下一條進入解碼階段的階段的指令是否位於延遲槽 */
	
	output wire [31:0]					excepttype_o;				/* 收集的異常資訊 */
	output wire [`RegBus]				current_inst_address_o;		/* 解碼階段指令的位址 */
	
	/* 送到PC模組的資訊 */
	output reg							branch_flag_o;				/* 是否發生轉移 */
	output reg [`RegBus]				branch_target_address_o;	/* 轉移到的目標位址 */
	
	/* 送到控制模組的資訊 */
	output wire							stallreq;					/* 管線暫停訊號 */
	
	/* 取得指令的指令碼、功能碼 */
	wire [5:0] op 	= inst_i[31:26];	/* 指令碼 */
	wire [4:0] op2 	= inst_i[10:6];
	wire [5:0] op3 	= inst_i[5:0];		/* 功能碼 */
	wire [4:0] op4 	= inst_i[20:16];
	
	/* 保存指令需要的立即數 */		
	reg [`RegBus] imm;
	
	/* 指示指令是否有效 */
	reg instvalid;
	
	wire [`RegBus] pc_plus_8;
	wire [`RegBus] pc_plus_4;
	wire [`RegBus] imm_sll2_signedext;
	
	/* 要讀取的暫存器1是否與上一條指令存在load相依 */
	reg stallreq_for_reg1_loadrelate;
	
	/* 要讀取的暫存器2是否與上一條指令存在load相依 */
	reg stallreq_for_reg2_loadrelate;
	
	/* 上一條指令是否是載入指令 */
	wire pre_inst_is_load;
	
	/* 是否是系統呼叫異常syscall */
	reg excepttype_is_syscall;
	
	/* 是否是異常返回指令eret */
	reg excepttype_is_eret;
	
	assign pc_plus_8 = pc_i + 8;		/* 保存目前解碼階段指令後面的第2條指令的位址 */	
	assign pc_plus_4 = pc_i + 4;		/* 保存目前解碼階段指令後面的緊接者的指令的位址 */
	
	/* imm_sll2_signedext對應分支指令中的offset左移兩位，再加減號擴充至32位元的值 */
	assign imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};
	assign inst_o	= inst_i;
	
	/* stallreq_for_reg1_loadrelate為Stop或者stallreq_for_reg1_loadrelate為Stop，都表示存在load相依，
	** 從而要求管線暫停，設定stallreq為Stop */
	assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
	
	/* 依據輸入訊號ex_aluop_i的值，判斷上一條指令是否是載入指令。如果是載入指令，那麼設定pre_inst_is_load為1，反之設定為0 */
	assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP)  || (ex_aluop_i == `EXE_LBU_OP) ||
							   (ex_aluop_i == `EXE_LH_OP)  || (ex_aluop_i == `EXE_LHU_OP) ||
							   (ex_aluop_i == `EXE_LW_OP)  || (ex_aluop_i == `EXE_LWR_OP) ||
							   (ex_aluop_i == `EXE_LWL_OP) || (ex_aluop_i == `EXE_LL_OP)  ||
							   (ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;
							   
	/* excepttype_o的低8bit留給外部中斷，第8bit表示是否是syscall指令引起的系統呼叫異常，第9bit表示是否是無效指令引起的異常，
	** 第12bit表示是否是eret指令，eret指令可以認為是一種特殊的異常——返回異常 */
	assign excepttype_o = {19'b0, excepttype_is_eret, 2'b0, instvalid, excepttype_is_syscall, 8'b0};
	
	/* 輸入訊號pc_i就是目前處於解碼階段的指令的位址 */
	assign current_inst_address_o = pc_i;
							   	
	/* 對指令進行解碼 */
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					aluop_o 					<= `EXE_NOP_OP;
					alusel_o 					<= `EXE_RES_NOP;
					wd_o 						<= `NOPRegAddr;
					wreg_o 						<= `WriteDisable;
					instvalid 					<= `InstValid;
					reg1_read_o 				<= 1'b0;
					reg2_read_o 				<= 1'b0;
					reg1_addr_o 				<= `NOPRegAddr;
					reg2_addr_o 				<= `NOPRegAddr;
					imm 						<= 32'h0;
					link_addr_o					<= `ZeroWord;
					branch_target_address_o		<= `ZeroWord;
					branch_flag_o				<= `NotBranch;
					next_inst_in_delayslot_o	<= `NotInDelaySlot;
					excepttype_is_syscall		<= `False_v;
					excepttype_is_eret			<= `False_v;
					instvalid					<= `InstInvalid;
				end
			else
				begin
					aluop_o 					<= `EXE_NOP_OP;
					alusel_o 					<= `EXE_RES_NOP;
					wd_o 						<= inst_i[15:11];		/* 預設的目的暫存器位址wd_o */
					wreg_o 						<= `WriteDisable;
					instvalid 					<= `InstInvalid;
					reg1_read_o 				<= 1'b0;
					reg2_read_o 				<= 1'b0;
					reg1_addr_o 				<= inst_i[25:21];		/* 預設的reg1_addr_o */
					reg2_addr_o 				<= inst_i[20:16];		/* 預設的reg2_addr_o */
					imm							<= `ZeroWord;
					link_addr_o					<= `ZeroWord;
					branch_target_address_o		<= `ZeroWord;
					branch_flag_o				<= `NotBranch;
					next_inst_in_delayslot_o	<= `NotInDelaySlot;
					excepttype_is_syscall		<= `False_v;			/* 預設沒有系統呼叫異常 */
					excepttype_is_eret			<= `False_v;			/* 預設不是eret指令 */
					instvalid					<= `InstInvalid;		/* 預設是無效指令 */
					
					case(op)
						`EXE_SPECIAL_INST:
							begin
								case(op2)
									5'b00000:
										begin
											/* 依據功能碼判斷是哪種指令 */
											case(op3)
												/* or指令 */
												`EXE_OR:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_OR_OP;					
														alusel_o 		<= 	`EXE_RES_LOGIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end													
												/* and指令 */
												`EXE_AND:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_AND_OP;					
														alusel_o 		<= 	`EXE_RES_LOGIC;		/* 進行邏輯 "與" 操作 */		
														reg1_read_o 	<= 	1'b1;				/* 讀取rs暫存器的值 */
														reg2_read_o 	<= 	1'b1;				/* 讀取rt暫存器的值 */
														instvalid		<=	`InstValid;
													end													
												/* xor指令 */
												`EXE_XOR:
													begin								
														wreg_o 			<=	`WriteEnable;
														aluop_o 		<=	`EXE_XOR_OP;
														alusel_o 		<= 	`EXE_RES_LOGIC;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* nor指令 */
												`EXE_NOR:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_NOR_OP;					
														alusel_o 		<= 	`EXE_RES_LOGIC;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* sllv指令 */
												`EXE_SLLV:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_SLL_OP;					
														alusel_o 		<= 	`EXE_RES_SHIFT;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* srlv指令 */
												`EXE_SRLV:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_SRL_OP;					
														alusel_o 		<= 	`EXE_RES_SHIFT;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* srav指令 */
												`EXE_SRAV:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_SRA_OP;					
														alusel_o 		<= 	`EXE_RES_SHIFT;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* sync指令 */
												`EXE_SYNC:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_NOP_OP;					
														alusel_o 		<= 	`EXE_RES_NOP;				
														reg1_read_o 	<= 	1'b0;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* mfhi指令 */
												`EXE_MFHI:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_MFHI_OP;					
														alusel_o 		<= 	`EXE_RES_MOVE;				
														reg1_read_o 	<= 	1'b0;						
														reg2_read_o 	<= 	1'b0;		
														instvalid		<=	`InstValid;					
													end
												/* mflo指令 */
												`EXE_MFLO:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_MFLO_OP;					
														alusel_o 		<= 	`EXE_RES_MOVE;				
														reg1_read_o 	<= 	1'b0;						
														reg2_read_o 	<= 	1'b0;		
														instvalid		<=	`InstValid;					
													end
												/* mthi指令 */
												`EXE_MTHI:
													begin								
														wreg_o 			<=	`WriteDisable;				
														aluop_o 		<=	`EXE_MTHI_OP;					
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b0;		
														instvalid		<=	`InstValid;					
													end
												/* mtlo指令 */
												`EXE_MTLO:
													begin								
														wreg_o 			<=	`WriteDisable;				
														aluop_o 		<=	`EXE_MTLO_OP;					
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b0;		
														instvalid		<=	`InstValid;					
													end
												/* movn指令 */
												`EXE_MOVN:
													begin								
														aluop_o 		<=	`EXE_MOVN_OP;					
														alusel_o 		<= 	`EXE_RES_MOVE;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;
														
														/* reg2_o的值就是位址為rt的通用暫存器 */
														if(reg2_o != `ZeroWord)
															wreg_o <= `WriteEnable;
														else
															wreg_o <= `WriteDisable;
													end
												/* movz指令 */
												`EXE_MOVZ:
													begin								
														aluop_o 		<=	`EXE_MOVZ_OP;					
														alusel_o 		<= 	`EXE_RES_MOVE;				
														reg1_read_o 	<= 	1'b1;						
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;
																	
														/* reg2_o的值就是位址為rt的通用暫存器 */
														if(reg2_o == `ZeroWord)
															wreg_o <= `WriteEnable;
														else
															wreg_o <= `WriteDisable;
													end
												/* slt指令 */
												`EXE_SLT:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_SLT_OP;					
														alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* sltu指令 */
												`EXE_SLTU:
													begin								
														wreg_o 			<=	`WriteEnable;
														aluop_o 		<=	`EXE_SLTU_OP;					
														alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* add指令 */
												`EXE_ADD:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_ADD_OP;					
														alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end	
												/* addu指令 */
												`EXE_ADDU:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_ADDU_OP;					
														alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* sub指令 */
												`EXE_SUB:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_SUB_OP;					
														alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* subu指令 */
												`EXE_SUBU:
													begin								
														wreg_o 			<=	`WriteEnable;				
														aluop_o 		<=	`EXE_SUBU_OP;					
														alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* mult指令 */
												`EXE_MULT:
													begin								
														wreg_o 			<=	`WriteDisable;				
														aluop_o 		<=	`EXE_MULT_OP;					
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* multu指令 */
												`EXE_MULTU:
													begin								
														wreg_o 			<=	`WriteDisable;				
														aluop_o 		<=	`EXE_MULTU_OP;					
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* div指令 */
												`EXE_DIV:
													begin								
														wreg_o 			<=	`WriteDisable;				
														aluop_o 		<=	`EXE_DIV_OP;					
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* divu指令 */
												`EXE_DIVU:
													begin								
														wreg_o 			<=	`WriteDisable;				
														aluop_o 		<=	`EXE_DIVU_OP;
														reg1_read_o 	<= 	1'b1;
														reg2_read_o 	<= 	1'b1;		
														instvalid		<=	`InstValid;					
													end
												/* jr指令 */
												`EXE_JR:
													begin
														wreg_o						<=	`WriteDisable;			/* 不需要保存返回位址 */
														aluop_o						<=	`EXE_JR_OP;
														alusel_o					<=	`EXE_RES_JUMP_BRANCH;
														reg1_read_o					<=	1'b1;
														reg2_read_o					<=	1'b0;
														link_addr_o					<=	`ZeroWord;				/* 不需要保存返回位址，故為0 */
														branch_target_address_o		<=	reg1_o;					/* 設定轉移目標位址 */
														branch_flag_o				<=	`Branch;				/* 要轉移 */
														next_inst_in_delayslot_o	<=	`InDelaySlot;			/* 下一條指令是延遲槽指令 */
														instvalid					<=	`InstValid;
													end
												/* jalr指令 */
												`EXE_JALR:
													begin
														wreg_o						<=	`WriteEnable;			/* 需要保存返回位址 */
														aluop_o						<=	`EXE_JALR_OP;
														alusel_o					<=	`EXE_RES_JUMP_BRANCH;
														reg1_read_o					<=	1'b1;
														reg2_read_o					<=	1'b0;
														wd_o						<=	inst_i[15:11];
														link_addr_o					<=	pc_plus_8;				/* 設定返回位址為目前轉移指令後2條指令的位址 */
														branch_target_address_o		<=	reg1_o;
														branch_flag_o				<=	`Branch;
														next_inst_in_delayslot_o	<=	`InDelaySlot;
														instvalid					<=	`InstValid;
													end
												default:
													begin
													end
											endcase /* case op3 */
										end
									default:
										begin
										end
								endcase /* case op2 */
								
								case(op3)
									/* teq指令 */
									`EXE_TEQ:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TEQ_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;
											instvalid		<=	`InstValid;		
										end
									/* tge指令 */
									`EXE_TGE:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TGE_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;
											instvalid		<=	`InstValid;		
										end
									/* tgeu指令 */
									`EXE_TGEU:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TGEU_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;
											instvalid		<=	`InstValid;		
										end
									/* tlt指令 */
									`EXE_TLT:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TLT_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;
											instvalid		<=	`InstValid;		
										end
									/* tltu指令 */
									`EXE_TLTU:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TLTU_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;
											instvalid		<=	`InstValid;		
										end
									/* tne指令 */
									`EXE_TNE:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TNE_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;
											instvalid		<=	`InstValid;		
										end
									/* syscall指令 */
									`EXE_SYSCALL:
										begin
											wreg_o 					<=	`WriteDisable;				
											aluop_o 				<=	`EXE_SYSCALL_OP;					
											alusel_o 				<= 	`EXE_RES_NOP;				
											reg1_read_o 			<= 	1'b0;						
											reg2_read_o 			<= 	1'b0;
											instvalid				<=	`InstValid;		
											excepttype_is_syscall	<=	`True_v;
										end
									default:
										begin
										end
								endcase /* case op3 */
							end
						/* 依據op的值判斷是否是ori指令 */
						`EXE_ORI:
							begin								
								wreg_o 			<=	`WriteEnable;				/* ori指令需要將結果寫入目的暫存器，所以wreg_o為WriteEnable */		
								aluop_o 		<=	`EXE_OR_OP;					/* 運算的子類型是邏輯 "或" 運算 */
								alusel_o 		<= 	`EXE_RES_LOGIC;				/* 運算的類型是邏輯運算 */
								reg1_read_o 	<= 	1'b1;						/* 需要透過Regfile的讀取連接埠1讀取暫存器 */
								reg2_read_o 	<= 	1'b0;						/* 因ori所需的另一個運算元是立即數，故不需要透過Regfile的讀取連接埠2讀取暫存器 */
								imm				<= 	{16'h0, inst_i[15:0]};		/* 指令執行需要的立即數 */
								wd_o			<=	inst_i[20:16];				/* 指令執行要寫入的目的暫存器位址 */
								instvalid		<=	`InstValid;					/* ori指令是有效指令 */
							end
						/* andi指令 */
						`EXE_ANDI:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_AND_OP;					
								alusel_o 		<= 	`EXE_RES_LOGIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{16'h0, inst_i[15:0]};		
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* xori指令 */
						`EXE_XORI:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_XOR_OP;					
								alusel_o 		<= 	`EXE_RES_LOGIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{16'h0, inst_i[15:0]};		
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* lui指令 */
						`EXE_LUI:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_OR_OP;					
								alusel_o 		<= 	`EXE_RES_LOGIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{inst_i[15:0], 16'h0};		
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* pref指令 */
						`EXE_PREF:
							begin								
								wreg_o 			<=	`WriteDisable;				
								aluop_o 		<=	`EXE_NOP_OP;					
								alusel_o 		<= 	`EXE_RES_NOP;				
								reg1_read_o 	<= 	1'b0;						
								reg2_read_o 	<= 	1'b0;								
								instvalid		<=	`InstValid;					
							end
						/* slti指令 */
						`EXE_SLTI:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_SLT_OP;					
								alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{{16{inst_i[15]}}, inst_i[15:0]};	/* 帶符號擴充立即數 */	
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* sltiu指令 */
						`EXE_SLTIU:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_SLTU_OP;					
								alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{{16{inst_i[15]}}, inst_i[15:0]};		
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* addi指令 */
						`EXE_ADDI:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_ADDI_OP;					
								alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{{16{inst_i[15]}}, inst_i[15:0]};		
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* addiu指令 */
						`EXE_ADDIU:
							begin								
								wreg_o 			<=	`WriteEnable;				
								aluop_o 		<=	`EXE_ADDIU_OP;					
								alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
								reg1_read_o 	<= 	1'b1;						
								reg2_read_o 	<= 	1'b0;						
								imm				<= 	{{16{inst_i[15]}}, inst_i[15:0]};		
								wd_o			<=	inst_i[20:16];				
								instvalid		<=	`InstValid;					
							end
						/* j指令 */
						`EXE_J:
							begin
								wreg_o						<=	`WriteDisable;
								aluop_o						<=	`EXE_J_OP;
								alusel_o					<=	`EXE_RES_JUMP_BRANCH;
								reg1_read_o					<=	1'b0;
								reg2_read_o					<=	1'b0;
								link_addr_o					<=	`ZeroWord;
								branch_flag_o				<=	`Branch;
								next_inst_in_delayslot_o	<=	`InDelaySlot;
								instvalid					<=	`InstValid;
								branch_target_address_o		<=	{pc_plus_4[31:28], inst_i[25:0], 2'b00};
							end
						/* jal指令 */
						`EXE_JAL:
							begin
								wreg_o						<=	`WriteEnable;
								aluop_o						<=	`EXE_JAL_OP;
								alusel_o					<=	`EXE_RES_JUMP_BRANCH;
								reg1_read_o					<=	1'b0;
								reg2_read_o					<=	1'b0;
								wd_o						<=	5'b11111;				/* 將返回位址寫到暫存器$31中 */
								link_addr_o					<=	pc_plus_8;
								branch_flag_o				<=	`Branch;
								next_inst_in_delayslot_o	<=	`InDelaySlot;
								instvalid					<=	`InstValid;
								branch_target_address_o		<=	{pc_plus_4[31:28], inst_i[25:0], 2'b00};
							end
						/* beq指令 */
						`EXE_BEQ:
							begin
								wreg_o						<=	`WriteDisable;
								aluop_o						<=	`EXE_BEQ_OP;
								alusel_o					<=	`EXE_RES_JUMP_BRANCH;
								reg1_read_o					<=	1'b1;
								reg2_read_o					<=	1'b1;
								instvalid					<=	`InstValid;
								/* 若兩暫存器相等，那麼轉移發生 */
								if(reg1_o == reg2_o)
									begin
										branch_flag_o				<=	`Branch;
										next_inst_in_delayslot_o	<=	`InDelaySlot;
										branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
									end
							end
						/* bgtz指令 */
						`EXE_BGTZ:
							begin
								wreg_o						<=	`WriteDisable;
								aluop_o						<=	`EXE_BGTZ_OP;
								alusel_o					<=	`EXE_RES_JUMP_BRANCH;
								reg1_read_o					<=	1'b1;
								reg2_read_o					<=	1'b0;
								instvalid					<=	`InstValid;
								/* 若讀取的位址rs的通用暫存器的值大於0，那麼轉移發生 */
								if((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord))
									begin
										branch_flag_o				<=	`Branch;
										next_inst_in_delayslot_o	<=	`InDelaySlot;
										branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
									end
							end
						/* blez指令 */
						`EXE_BLEZ:
							begin
								wreg_o						<=	`WriteDisable;
								aluop_o						<=	`EXE_BLEZ_OP;
								alusel_o					<=	`EXE_RES_JUMP_BRANCH;
								reg1_read_o					<=	1'b1;
								reg2_read_o					<=	1'b0;
								instvalid					<=	`InstValid;
								if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord))
									begin
										branch_flag_o				<=	`Branch;
										next_inst_in_delayslot_o	<=	`InDelaySlot;
										branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
									end
							end
						/* bne指令 */
						`EXE_BNE:
							begin
								wreg_o						<=	`WriteDisable;
								aluop_o						<=	`EXE_BGTZ_OP;
								alusel_o					<=	`EXE_RES_JUMP_BRANCH;
								reg1_read_o					<=	1'b1;
								reg2_read_o					<=	1'b1;
								instvalid					<=	`InstValid;
								if(reg1_o != reg2_o)
									begin
										branch_flag_o				<=	`Branch;
										next_inst_in_delayslot_o	<=	`InDelaySlot;
										branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
									end
							end
						/* lb指令 */
						`EXE_LB:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LB_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b0;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* lbu指令 */
						`EXE_LBU:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LBU_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b0;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* lh指令 */
						`EXE_LH:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LH_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b0;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* lhu指令 */
						`EXE_LHU:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LHU_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b0;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* lw指令 */
						`EXE_LW:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LW_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b0;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* lwl指令 */
						`EXE_LWL:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LWL_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* lwr指令 */
						`EXE_LWR:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LWR_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* ll指令 */
						`EXE_LL:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_LL_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b0;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
							end
						/* sb指令 */
						`EXE_SB:
							begin
								wreg_o		<=	`WriteDisable;
								aluop_o		<=	`EXE_SB_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								instvalid	<=	`InstValid;
							end
						/* sh指令 */
						`EXE_SH:
							begin
								wreg_o		<=	`WriteDisable;
								aluop_o		<=	`EXE_SH_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								instvalid	<=	`InstValid;
							end
						/* sw指令 */
						`EXE_SW:
							begin
								wreg_o		<=	`WriteDisable;
								aluop_o		<=	`EXE_SW_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								instvalid	<=	`InstValid;
							end
						/* swl指令 */
						`EXE_SWL:
							begin
								wreg_o		<=	`WriteDisable;
								aluop_o		<=	`EXE_SWL_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								instvalid	<=	`InstValid;
							end
						/* swr指令 */
						`EXE_SWR:
							begin
								wreg_o		<=	`WriteDisable;
								aluop_o		<=	`EXE_SWR_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								instvalid	<=	`InstValid;
							end
						/* sc指令 */
						`EXE_SC:
							begin
								wreg_o		<=	`WriteEnable;
								aluop_o		<=	`EXE_SC_OP;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
								reg1_read_o	<=	1'b1;
								reg2_read_o	<=	1'b1;
								wd_o		<=	inst_i[20:16];
								instvalid	<=	`InstValid;
								alusel_o	<=	`EXE_RES_LOAD_STORE;
							end
						`EXE_REGIMM_INST:
							begin
								case(op4)
									/* bgez指令 */
									`EXE_BGEZ:
										begin
											wreg_o			<=	`WriteDisable;
											aluop_o			<=	`EXE_BGEZ_OP;
											alusel_o		<=	`EXE_RES_JUMP_BRANCH;
											reg1_read_o		<=	1'b1;
											reg2_read_o		<=	1'b0;
											instvalid		<=	`InstValid;
											if(reg1_o[31] == 1'b0)
												begin
													branch_flag_o				<=	`Branch;
													next_inst_in_delayslot_o	<=	`InDelaySlot;
													branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
												end
										end
									/* bgezal指令 */
									`EXE_BGEZAL:
										begin
											wreg_o			<=	`WriteEnable;
											aluop_o			<=	`EXE_BGEZAL_OP;
											alusel_o		<=	`EXE_RES_JUMP_BRANCH;
											reg1_read_o		<=	1'b1;
											reg2_read_o		<=	1'b0;
											link_addr_o		<=	pc_plus_8;
											wd_o			<=	5'b11111;
											instvalid		<=	`InstValid;
											/* 位址為rs的通用暫存器的值大於等於0 */
											if(reg1_o[31] == 1'b0)
												begin
													branch_flag_o				<=	`Branch;
													next_inst_in_delayslot_o	<=	`InDelaySlot;
													branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
												end
										end
									/* bltz指令 */
									`EXE_BLTZ:
										begin
											wreg_o			<=	`WriteEnable;
											aluop_o			<=	`EXE_BGEZAL_OP;
											alusel_o		<=	`EXE_RES_JUMP_BRANCH;
											reg1_read_o		<=	1'b1;
											reg2_read_o		<=	1'b0;
											instvalid		<=	`InstValid;
											if(reg1_o[31] == 1'b1)
												begin
													branch_flag_o				<=	`Branch;
													next_inst_in_delayslot_o	<=	`InDelaySlot;
													branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
												end
										end
									/* bltzal指令 */
									`EXE_BLTZAL:
										begin
											wreg_o			<=	`WriteEnable;
											aluop_o			<=	`EXE_BGEZAL_OP;
											alusel_o		<=	`EXE_RES_JUMP_BRANCH;
											reg1_read_o		<=	1'b1;
											reg2_read_o		<=	1'b0;
											link_addr_o		<=	pc_plus_8;
											wd_o			<=	5'b11111;
											instvalid		<=	`InstValid;
											if(reg1_o[31] == 1'b1)
												begin
													branch_flag_o				<=	`Branch;
													next_inst_in_delayslot_o	<=	`InDelaySlot;
													branch_target_address_o		<=	pc_plus_4 + imm_sll2_signedext;
												end
										end
									/* teqi指令 */
									`EXE_TEQI:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TEQI_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;
											imm				<=	{{16{inst_i[15]}}, inst_i[15:0]};
											instvalid		<=	`InstValid;		
										end
									/* tgei指令 */
									`EXE_TGEI:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TGEI_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;
											imm				<=	{{16{inst_i[15]}}, inst_i[15:0]};
											instvalid		<=	`InstValid;		
										end
									/* tgeiu指令 */
									`EXE_TGEIU:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TGEIU_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;
											imm				<=	{{16{inst_i[15]}}, inst_i[15:0]};
											instvalid		<=	`InstValid;		
										end
									/* tlti指令 */
									`EXE_TLTI:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TLTI_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;
											imm				<=	{{16{inst_i[15]}}, inst_i[15:0]};
											instvalid		<=	`InstValid;		
										end
									/* tltiu指令 */
									`EXE_TLTIU:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TLTIU_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;
											imm				<=	{{16{inst_i[15]}}, inst_i[15:0]};
											instvalid		<=	`InstValid;		
										end
									/* tnei指令 */
									`EXE_TNEI:
										begin
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_TNEI_OP;					
											alusel_o 		<= 	`EXE_RES_NOP;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;
											imm				<=	{{16{inst_i[15]}}, inst_i[15:0]};
											instvalid		<=	`InstValid;		
										end
									default:
										begin
										end
								endcase /* case op4 */
							end
						/* SPECIAL2類指令 */
						`EXE_SPECIAL2_INST:
							begin
								case(op3)
									/* clz指令 */
									`EXE_CLZ:
										begin								
											wreg_o 			<=	`WriteEnable;				
											aluop_o 		<=	`EXE_CLZ_OP;					
											alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;						
											instvalid		<=	`InstValid;					
										end
									/* clo指令 */
									`EXE_CLO:
										begin								
											wreg_o 			<=	`WriteEnable;				
											aluop_o 		<=	`EXE_CLO_OP;					
											alusel_o 		<= 	`EXE_RES_ARITHMETIC;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b0;						
											instvalid		<=	`InstValid;					
										end
									/* mul指令 */
									`EXE_MUL:
										begin								
											wreg_o 			<=	`WriteEnable;				
											aluop_o 		<=	`EXE_MUL_OP;					
											alusel_o 		<= 	`EXE_RES_MUL;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;						
											instvalid		<=	`InstValid;					
										end
									/* madd指令 */
									`EXE_MADD:
										begin								
											wreg_o 			<=	`WriteDisable;	/* 因是寫入HI、LO暫存器，而不是寫入通用暫存器 */		
											aluop_o 		<=	`EXE_MADD_OP;					
											alusel_o 		<= 	`EXE_RES_MUL;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;						
											instvalid		<=	`InstValid;					
										end
									/* maddu指令 */
									`EXE_MADDU:
										begin								
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_MADDU_OP;					
											alusel_o 		<= 	`EXE_RES_MUL;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;						
											instvalid		<=	`InstValid;					
										end
									/* msub指令 */
									`EXE_MSUB:
										begin								
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_MSUB_OP;					
											alusel_o 		<= 	`EXE_RES_MUL;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;						
											instvalid		<=	`InstValid;					
										end
									/* msubu指令 */
									`EXE_MSUBU:
										begin								
											wreg_o 			<=	`WriteDisable;				
											aluop_o 		<=	`EXE_MSUBU_OP;					
											alusel_o 		<= 	`EXE_RES_MUL;				
											reg1_read_o 	<= 	1'b1;						
											reg2_read_o 	<= 	1'b1;						
											instvalid		<=	`InstValid;					
										end
									default:
										begin
										end
								endcase /* case EXE_SPECIAL2_INST */
							end
						default:
							begin
							end
					endcase /* case op */
					
					if(inst_i[31:21] == 11'b00000000000)
						begin
							/* sll指令 */
							if(op3 == `EXE_SLL)
								begin								
									wreg_o 			<=	`WriteEnable;				
									aluop_o 		<=	`EXE_SLL_OP;					
									alusel_o 		<= 	`EXE_RES_SHIFT;				
									reg1_read_o 	<= 	1'b0;						
									reg2_read_o 	<= 	1'b1;						
									imm[4:0]		<= 	inst_i[10:6];		
									wd_o			<=	inst_i[15:11];				
									instvalid		<=	`InstValid;					
								end
							/* srl指令 */
							else if(op3 == `EXE_SRL)
								begin								
									wreg_o 			<=	`WriteEnable;				
									aluop_o 		<=	`EXE_SRL_OP;					
									alusel_o 		<= 	`EXE_RES_SHIFT;				
									reg1_read_o 	<= 	1'b0;						
									reg2_read_o 	<= 	1'b1;						
									imm[4:0]		<= 	inst_i[10:6];		
									wd_o			<=	inst_i[15:11];				
									instvalid		<=	`InstValid;					
								end
							/* sra指令 */
							else if(op3 == `EXE_SRA)
								begin								
									wreg_o 			<=	`WriteEnable;				
									aluop_o 		<=	`EXE_SRA_OP;					
									alusel_o 		<= 	`EXE_RES_SHIFT;				
									reg1_read_o 	<= 	1'b0;						
									reg2_read_o 	<= 	1'b1;						
									imm[4:0]		<= 	inst_i[10:6];		
									wd_o			<=	inst_i[15:11];				
									instvalid		<=	`InstValid;					
								end
						end /* if inst_i[31:21] */
					
					/* eret指令 */
					if(inst_i == `EXE_ERET)
						begin
							wreg_o 					<=	`WriteDisable;				
							aluop_o 				<=	`EXE_ERET_OP;					
							alusel_o 				<= 	`EXE_RES_NOP;				
							reg1_read_o 			<= 	1'b0;						
							reg2_read_o 			<= 	1'b0;
							instvalid				<=	`InstValid;
							excepttype_is_eret		<=	`True_v;		
						end
					/* mfc0指令 */
					else if((inst_i[31:21] == 11'b01000000000) && (inst_i[10:0] == 11'b00000000000))
						begin
							aluop_o					<=	`EXE_MFC0_OP;
							alusel_o				<=	`EXE_RES_MOVE;
							wd_o					<=	inst_i[20:16];
							wreg_o					<=	`WriteEnable;
							instvalid				<=	`InstValid;
							reg1_read_o				<=	1'b0;
							reg2_read_o				<=	1'b0;
						end					
					/* mtc0指令 */
					else if((inst_i[31:21] == 11'b01000000100) && (inst_i[10:0] == 11'b00000000000))
						begin
							aluop_o					<=	`EXE_MTC0_OP;
							alusel_o				<=	`EXE_RES_NOP;
							wreg_o					<=	`WriteDisable;
							instvalid				<=	`InstValid;
							reg1_read_o				<=	1'b1;
							reg1_addr_o				<=	inst_i[20:16];
							reg2_read_o				<=	1'b0;
						end
				end /* if rst */
		end /* always */
	
	/* 輸出變數is_in_delayslot_o表示目前解碼階段指令是否是延遲槽指令 */
	always @( * )
		begin
			if(rst == `RstEnable)
				is_in_delayslot_o	<=	`NotInDelaySlot;
			else
				is_in_delayslot_o	<=	is_in_delayslot_i;	/* 直接等於is_in_delayslot_i */
		end
		
	/* 確定進行運算的來源運算元1 */			
	/* 如果上一條指令是載入指令，且該載入指令要載入到的目的暫存器就是目前指令要透過Regfile模組讀取連接埠1讀取的通用暫存器，
	** 那麼存在load相依，設定stallreq_for_reg1_loadrelate為Stop */
	always @ ( * )
		begin
			stallreq_for_reg1_loadrelate <= `NoStop;
			
			if(rst == `RstEnable)
				reg1_o <= `ZeroWord;
			else if((pre_inst_is_load == 1'b1) && (ex_wd_i == reg1_addr_o) && (reg1_read_o == 1'b1))
				stallreq_for_reg1_loadrelate <=	`Stop;
			else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o))
				reg1_o <= ex_wdata_i;
			else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o))
				reg1_o <= mem_wdata_i;
			else if(reg1_read_o == 1'b1)
				reg1_o <= reg1_data_i;		/* Regfile讀取連接埠1(inst_i[25:21])的輸出值 */
			else if(reg1_read_o == 1'b0)
				reg1_o <= imm;				/* 立即數 */
			else
				reg1_o <= `ZeroWord;
		end
		
	/* 確定進行運算的來源運算元2 */			
	/* 如果上一條指令是載入指令，且該載入指令要載入到的目的暫存器就是目前指令要透過Regfile模組讀取連接埠2讀取的通用暫存器，
	** 那麼存在load相依，設定stallreq_for_reg2_loadrelate為Stop */
	always @ ( * )
		begin
			stallreq_for_reg2_loadrelate <= `NoStop;

			if(rst == `RstEnable)
				reg2_o <= `ZeroWord;
			else if((pre_inst_is_load == 1'b1) && (ex_wd_i == reg2_addr_o) && (reg2_read_o == 1'b1))
				stallreq_for_reg2_loadrelate <=	`Stop;
			else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o))
				reg2_o <= ex_wdata_i;
			else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o))
				reg2_o <= mem_wdata_i;
			else if(reg2_read_o == 1'b1)
				reg2_o <= reg2_data_i;		/* Regfile讀取連接埠2讀取的暫存器的值作為來源運算元2 */
			else if(reg2_read_o == 1'b0)
				reg2_o <= imm;				/* 將立即數作為來源運算元2 */
			else
				reg2_o <= `ZeroWord;
		end
		
endmodule
