`include "defines.v"

/* 為了實現ll、sc指令，新增了一個LLbit暫存器，其中儲存的就是連結狀態位元 */
module LLbit_reg(clk, rst, flush, LLbit_i, we, LLbit_o);

	input wire					clk;					/* 時脈訊號 */
	input wire 					rst;					/* 重設訊號 */
	
	/* 異常是否發生，為1表示異常發生，為0表示沒有異常 */
	input wire					flush;					/* 是否有異常發生 */
	
	/* 寫入操作 */
	input wire					LLbit_i;				/* 要寫入到LLbit暫存器的值 */
	input wire					we;						/* 是否要寫入LLbit暫存器 */
	
	output reg					LLbit_o;				/* LLbit暫存器的值 */
	
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				LLbit_o <= 1'b0;
			else if(flush == 1'b1)						/* 如果異常發生，那麼設定LLbit_o為0 */
				LLbit_o <= 1'b0;						
			else if(we == `WriteEnable)				
				LLbit_o <= LLbit_i;	
		end
		
endmodule
