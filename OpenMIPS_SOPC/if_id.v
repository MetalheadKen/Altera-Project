`include "defines.v"

/* 暫時保存取指令階段取得的指令，以及對應的指令位址，並在下一個時脈傳遞到解碼階段 */
module if_id(clk, rst, stall, flush, if_pc, if_inst, id_pc, id_inst);

	input wire 						clk;			/* 時脈訊號 */
	input wire 						rst;			/* 重設訊號 */
	input wire [5:0]				stall;			/* 管線暫停訊號 */
	input wire						flush;			/* 管線清除訊號 */
	input wire [`InstAddrBus] 		if_pc;			/* 取指令階段取得的指令對應的位址 */
	input wire [`InstBus]			if_inst;		/* 取指令階段取得的指令 */
	
	output reg [`InstAddrBus] 		id_pc;			/* 解碼階段的指令對應的位址 */
	output reg [`InstBus]			id_inst;		/* 解碼階段的指令 */
	
	/* (1)當stall[1]為Stop，stall[2]為NoStop時，表示取指令階段暫停，而解碼階段繼續，
	**    所以使用空指令作為下一個周期進入解碼階段的指令
	** (2)當stall[1]為NoStop時，表示取指令階段繼續，取得指令進入解碼階段
	** (3)其餘情況下，保持解碼階段的暫存器id_pc、id_inst不變 */
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				begin
					id_pc 		<=	`ZeroWord;		/* 重設的時候pc為0 */
					id_inst 	<=	`ZeroWord;		/* 重設的時候指令也為0，實際就是空指令 */
				end
			else if(flush == 1'b1)
				begin
					id_pc		<=	`ZeroWord;		/* flush為1表示異常發生，要清除管線，所以重設id_pc、id_inst暫存器的值 */
					id_inst		<=	`ZeroWord;
				end
			else if(stall[1] == `Stop && stall[2] == `NoStop)
				begin
					id_pc		<=	`ZeroWord;
					id_inst		<=	`ZeroWord;
				end
			else if(stall[1] == `NoStop)
				begin
					id_pc 		<=	if_pc;			/* 其餘時刻向下傳遞取指令階段的值 */
					id_inst 	<=	if_inst;
				end
		end

endmodule
