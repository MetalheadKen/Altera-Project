`include "defines.v"

/* 將解碼階段的結果在時脈週期的上升緣傳遞到執行階段 */
module id_ex(clk, rst, stall, flush, id_alusel, id_aluop, id_reg1, id_reg2, id_wd, id_wreg, id_is_in_delayslot, id_link_address, next_inst_in_delayslot_i, id_inst, id_current_inst_address, id_excepttype,
			 ex_alusel, ex_aluop, ex_reg1, ex_reg2, ex_wd, ex_wreg, ex_is_in_delayslot, ex_link_address, is_in_delayslot_o, ex_inst, ex_current_inst_address, ex_excepttype);

	input wire							clk;						/* 時脈訊號 */
	input wire 							rst;						/* 重設訊號 */
	
	/* 來自控制模組的資訊 */
	input wire [5:0]					stall;						/* 管線暫停訊號 */
	input wire							flush;						/* 管線清除訊號 */
	
	/* 從解碼階段傳遞過來的資訊 */
	input wire [`AluOpBus]				id_aluop;					/* 解碼階段的指令要進行的運算的子類型 */
	input wire [`AluSelBus]	 			id_alusel;					/* 解碼階段的指令要進行的運算的類型 */
	input wire [`RegBus]				id_reg1;					/* 解碼階段的指令要進行的運算的來源運算元1 */
	input wire [`RegBus]				id_reg2;					/* 解碼階段的指令要進行的運算的來源運算元2 */
	input wire [`RegAddrBus] 			id_wd;						/* 解碼階段的指令要寫入的目的暫存器位址 */
	input wire							id_wreg;					/* 解碼階段的指令是否有要寫入的目的暫存器 */
	input wire							id_is_in_delayslot;			/* 目前處於解碼階段的指令是否位於延遲槽 */
	input wire [`RegBus]				id_link_address;			/* 處於解碼階段的轉移指令要保存的返回位址 */
	input wire							next_inst_in_delayslot_i;	/* 下一條進入解碼階段的指令是否位於延遲槽 */
	input wire [`RegBus]				id_inst;					/* 目前處於解碼階段的指令 */
	input wire [`RegBus]				id_current_inst_address;	/* 解碼階段指令的位址 */
	input wire [31:0]					id_excepttype;				/* 解碼階段收到的異常訊息 */
	
	/* 傳送到執行階段的資訊 */
	output reg [`AluOpBus]				ex_aluop;					/* 執行階段的指令要進行的運算的子類型 */
	output reg [`AluSelBus]				ex_alusel;					/* 執行階段的指令要進行的運算的類型 */	
	output reg [`RegBus]				ex_reg1;					/* 執行階段的指令要進行的運算的來源運算元1 */
	output reg [`RegBus]				ex_reg2;					/* 執行階段的指令要進行的運算的來源運算元2 */
	output reg [`RegAddrBus] 			ex_wd;						/* 執行階段的指令要寫入的目的暫存器位址 */
	output reg 							ex_wreg;					/* 執行階段的指令是否有要寫入的目的暫存器 */
	output reg							ex_is_in_delayslot;			/* 目前處於執行階段的指令是否位於延遲槽 */
	output reg [`RegBus]				ex_link_address;			/* 處於執行階段的轉移指令要保存的返回位址 */
	output reg							is_in_delayslot_o;			/* 目前處於解碼階段的指令是否位於延遲槽 */
	output reg [`RegBus]				ex_inst;					/* 目前處於執行階段的指令 */
	output reg [`RegBus]				ex_current_inst_address;	/* 執行階段指令的位址 */
	output reg [31:0]					ex_excepttype;				/* 執行階段收到的異常訊息 */
	
	/* (1)當stall[2]為Stop，stall[3]為NoStop時，表示解碼階段暫停，而執行階段繼續，
	**    所以使用空指令作為下一個周期進入執行階段的指令
	** (2)當stall[2]為NoStop時，表示解碼階段繼續，解碼後的指令進入執行階段
	** (3)其餘情況下，保持執行階段的暫存器ex_aluop、ex_alusel、ex_reg1、ex_reg2、ex_wd、ex_wreg不變 */
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				begin
					ex_aluop				<=	`EXE_NOP_OP;
					ex_alusel 				<=	`EXE_RES_NOP;
					ex_reg1					<=	`ZeroWord;
					ex_reg2					<=	`ZeroWord;
					ex_wd					<=	`NOPRegAddr;
					ex_wreg					<=	`WriteDisable;
					ex_link_address			<=	`ZeroWord;
					ex_is_in_delayslot		<=	`NotInDelaySlot;
					is_in_delayslot_o		<=	`NotInDelaySlot;
					ex_inst					<=	`ZeroWord;
					ex_excepttype			<=	`ZeroWord;
					ex_current_inst_address	<=	`ZeroWord;
				end
			/* 清除管線 */
			else if(flush == 1'b1)
				begin
					ex_aluop				<=	`EXE_NOP_OP;
					ex_alusel 				<=	`EXE_RES_NOP;
					ex_reg1					<=	`ZeroWord;
					ex_reg2					<=	`ZeroWord;
					ex_wd					<=	`NOPRegAddr;
					ex_wreg					<=	`WriteDisable;
					ex_link_address			<=	`ZeroWord;
					ex_is_in_delayslot		<=	`NotInDelaySlot;
					is_in_delayslot_o		<=	`NotInDelaySlot;
					ex_inst					<=	`ZeroWord;
					ex_excepttype			<=	`ZeroWord;
					ex_current_inst_address	<=	`ZeroWord;
				end
			else if(stall[2] == `Stop && stall[3] == `NoStop)
				begin
					ex_aluop				<= 	`EXE_NOP_OP;
					ex_alusel				<=	`EXE_RES_NOP;
					ex_reg1					<=	`ZeroWord;
					ex_reg2					<=	`ZeroWord;
					ex_wd					<=	`NOPRegAddr;
					ex_wreg					<=	`WriteDisable;
					ex_link_address			<=	`ZeroWord;
					ex_is_in_delayslot		<=	`NotInDelaySlot;
					ex_inst					<=	`ZeroWord;
					ex_excepttype			<=	`ZeroWord;
					ex_current_inst_address	<=	`ZeroWord;
				end
			else if(stall[2] == `NoStop)
				begin
					ex_aluop				<=	id_aluop;
					ex_alusel 				<=	id_alusel;
					ex_reg1					<=	id_reg1;
					ex_reg2					<=	id_reg2;
					ex_wd					<=	id_wd;
					ex_wreg					<=	id_wreg;
					ex_link_address			<=	id_link_address;
					ex_is_in_delayslot		<=	id_is_in_delayslot;
					is_in_delayslot_o		<=	next_inst_in_delayslot_i;
					ex_inst					<=	id_inst;	/* 在解碼階段沒有暫停的情況下，直接將ID模組的輸入透過介面ex_inst輸出 */
					ex_excepttype			<=	id_excepttype;
					ex_current_inst_address	<=	id_current_inst_address;
				end
		end
		
endmodule
