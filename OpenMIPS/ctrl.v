`include "defines.v"

/* 接收來自ID、EX模組傳遞過來的管線暫停請求訊號，從而控制管線各階段的執行 */
module ctrl(rst, stallreq_from_if, stallreq_from_id, stallreq_from_ex, stallreq_from_mem, excepttype_i, cp0_epc_i, stall, new_pc, flush);

	input wire 					rst;					/* 重設訊號 */
	
	input wire					stallreq_from_if;		/* 取指令階段是否請求管線暫停 */
	input wire					stallreq_from_id;		/* 處於解碼階段的指令是否請求管線暫停 */
	input wire					stallreq_from_ex;		/* 處於執行階段的指令是否請求管線暫停 */
	input wire					stallreq_from_mem;		/* 存取記憶體階段是否請求管線暫停 */
	
	/* 來自MEM模組的資訊 */
	input wire [31:0]			excepttype_i;			/* 最終的異常類型 */
	input wire [`RegBus]		cp0_epc_i;				/* EPC暫存器的最新值 */
	
	output reg [5:0]			stall;					/* 管線暫停控制訊號 */
	output reg [`RegBus]		new_pc;					/* 異常處理入口位址 */
	output reg					flush;					/* 是否清除管線 */
	
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					stall 	<= 	6'b000000;
					flush	<=	1'b0;
					new_pc	<=	`ZeroWord;
				end
			else if(excepttype_i !=	`ZeroWord)			/* 不為0，表示發生異常 */
				begin
					flush	<=	1'b1;
					stall	<=	6'b000000;
					
					case(excepttype_i)
						/* 中斷	*/
						32'h00000001:
							new_pc	<=	32'h00000020;
						
						/* 系統調用syscall */
						32'h00000008:
							new_pc	<=	32'h00000040;
						
						/* 無效指令異常	*/
						32'h0000000a:
							new_pc	<=	32'h00000040;
						
						/* 自陷異常	*/
						32'h0000000d:
							new_pc	<=	32'h00000040;
						
						/* 溢出異常	*/
						32'h0000000c:
							new_pc	<=	32'h00000040;
						
						/* 異常返回指令eret	*/
						32'h0000000e:
							new_pc	<=	cp0_epc_i;
						default:
							begin
							end
					endcase
				end
			else if(stallreq_from_mem == `Stop)			/* 存取記憶體階段請求暫停 */
				begin
					stall	<=	6'b011111;
					flush	<=	1'b0;
				end
			else if(stallreq_from_ex == `Stop)			/* 若管線執行階段的指令請求暫停時 */
				begin
					stall	<=	6'b001111;				/* 要求取指令、解碼、執行階段暫停，而存取記憶體、回寫階段繼續 */
					flush	<=	1'b0;
				end
			else if(stallreq_from_id == `Stop)			/* 若管線解碼階段的指令請求暫停時 */
				begin
					stall	<= 	6'b000111;				/* 要求取指令、解碼階段暫停，而執行、存取記憶體、回寫階段繼續 */
					flush	<=	1'b0;
				end
			else if(stallreq_from_if == `Stop)			/* 取指令階段請求暫停 */
				begin
					stall	<=	6'b000111;
					flush	<=	1'b0;
				end
			else
				begin
					stall	<= 	6'b000000;				/* 不暫停管線 */
					flush	<=	1'b0;
					new_pc	<=	`ZeroWord;
				end /* if excepttype_i */
		end /* always */
		
endmodule
