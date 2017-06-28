`include "defines.v"

/* 實現Wishbone匯流排介面模組 */
module wishbone_bus_if(clk, rst, stall_i, flush_i, cpu_ce_i, cpu_data_i, cpu_addr_i, cpu_we_i, cpu_sel_i, cpu_data_o, wishbone_data_i, wishbone_ack_i,
					   wishbone_addr_o, wishbone_data_o, wishbone_we_o, wishbone_sel_o, wishbone_stb_o, wishbone_cyc_o, stallreq);

	input wire					clk;					/* 時脈訊號 */
	input wire 					rst;					/* 重設訊號 */
	
	/* 來自CTRL模組的資訊 */
	input wire [5:0]			stall_i;				/* CTRL模組傳入的管線暫停訊號 */
	input wire					flush_i;				/* CTRL模組傳入的管線清除訊號 */
	
	/* CPU-side的介面 */
	input wire					cpu_ce_i;				/* 來自處理器的存取請求訊號 */
	input wire [`RegBus]		cpu_data_i;				/* 來自處理器的資料 */
	input wire [`RegBus]		cpu_addr_i;				/* 來自處理器的位址訊號 */
	input wire					cpu_we_i;				/* 來自處理器的寫入操作指示訊號 */
	input wire [3:0]			cpu_sel_i;				/* 來自處理器的位元組選擇訊號 */
	output reg [`RegBus]		cpu_data_o;				/* 輸出到處理器的資料 */
	
	/* Wishbone-side的介面 */
	input wire [`RegBus]		wishbone_data_i;		/* Wishbone匯流排輸入的資料 */
	input wire					wishbone_ack_i;			/* Wishbone匯流排輸入的回應 */
	output reg [`RegBus]		wishbone_addr_o;		/* Wishbone匯流排輸出的位址 */
	output reg [`RegBus]		wishbone_data_o;		/* Wishbone匯流排輸出的資料 */
	output reg					wishbone_we_o;			/* Wishbone匯流排寫入啟用訊號 */
	output reg [3:0]			wishbone_sel_o;			/* Wishbone匯流排位元組選擇訊號 */
	output reg					wishbone_stb_o;			/* Wishbone匯流排選通訊號 */
	output reg					wishbone_cyc_o;			/* Wishbone匯流排週期訊號 */
	
	output reg					stallreq;				/* 請求管線暫停的訊號 */
	
	reg [1:0]		wishbone_state;			/* 保存Wishbone匯流排介面模組的狀態 */
	reg [`RegBus]	rd_buf;					/* 暫存透過Wishbone匯流排存取到的資料 */
	
	
	/* 控制狀態轉換的時序電路 */
	always @(posedge clk)
		begin
			if(rst == `RstEnable)
				begin
					wishbone_state 	 <=	`WB_IDLE;
					wishbone_addr_o	 <=	`ZeroWord;
					wishbone_data_o	 <=	`ZeroWord;
					wishbone_we_o	 <=	`WriteDisable;
					wishbone_sel_o	 <=	4'b0000;
					wishbone_stb_o	 <=	1'b0;
					wishbone_cyc_o	 <=	1'b0;
					rd_buf			 <=	`ZeroWord;
				end
			else
				begin
					case(wishbone_state)
						/* WB_IDLE狀態 */
						`WB_IDLE:
							begin
								if((cpu_ce_i == 1'b1) && (flush_i == `False_v))
									begin
										wishbone_stb_o	<=	1'b1;
										wishbone_cyc_o	<=	1'b1;
										wishbone_addr_o	<=	cpu_addr_i;
										wishbone_data_o	<=	cpu_data_i;
										wishbone_we_o	<=	cpu_we_i;
										wishbone_sel_o	<=	cpu_sel_i;
										wishbone_state	<=	`WB_BUSY;		/* 進入WB_BUSY狀態 */
										rd_buf			<=	`ZeroWord;
									end
							end
						/* WB_BUSY狀態 */
						`WB_BUSY:
							begin
								if(wishbone_ack_i == 1'b1)
									begin
										wishbone_stb_o	<=	1'b0;
										wishbone_cyc_o	<=	1'b0;
										wishbone_addr_o	<=	`ZeroWord;
										wishbone_data_o	<=	`ZeroWord;
										wishbone_we_o	<=	`WriteDisable;
										wishbone_sel_o	<=	4'b0000;
										wishbone_state	<=	`WB_IDLE;		/* 進入WB_IDLE狀態 */
										
										if(cpu_we_i == `WriteDisable)
											begin
												rd_buf	<=	wishbone_data_i;
											end
											
										if(stall_i != 6'b000000)
											begin
												/* 進入WB_WAIT_FOR_STALL狀態 */
												wishbone_state	<=	`WB_WAIT_FOR_STALL;
											end
									end
								else if(flush_i == `True_v)
									begin
										wishbone_stb_o	<=	1'b0;
										wishbone_cyc_o	<=	1'b0;
										wishbone_addr_o	<=	`ZeroWord;
										wishbone_data_o	<=	`ZeroWord;
										wishbone_we_o	<=	`WriteDisable;
										wishbone_sel_o	<=	4'b0000;
										wishbone_state	<=	`WB_IDLE;		/* 進入WB_IDLE狀態 */
										rd_buf			<=	`ZeroWord;
									end
							end
						/* WB_WAIT_FOR_STALL狀態 */
						`WB_WAIT_FOR_STALL:
							begin
								if(stall_i == 6'b000000)
									begin
										wishbone_state	<=	`WB_IDLE;		/* 進入WB_IDLE狀態 */
									end
							end
						default:
							begin
							end
					endcase
				end /* if rst */
		end /* always */
		
	/* 給處理器介面訊號指派的組合電路 */
	always @( * )
		begin
			if(rst == `RstEnable)
				begin
					stallreq	<=	`NoStop;
					cpu_data_o	<=	`ZeroWord;
				end
			else
				begin
					stallreq	<=	`NoStop;
					
					case(wishbone_state)
						/* WB_IDLE狀態 */
						`WB_IDLE:
							begin
								if((cpu_ce_i == 1'b1) && (flush_i == `False_v))
									begin
										stallreq	<=	`Stop;
										cpu_data_o	<=	`ZeroWord;
									end
							end
						/* WB_BUSY狀態 */
						`WB_BUSY:
							begin
								if(wishbone_ack_i == 1'b1)
									begin
										stallreq	<=	`NoStop;
											
										if(wishbone_we_o == `WriteDisable)
											begin
												cpu_data_o	<=	wishbone_data_i;
											end
										else
											begin
												cpu_data_o	<=	`ZeroWord;
											end
									end
								else
									begin
										stallreq	<=	`Stop;
										cpu_data_o	<=	`ZeroWord;
									end
							end
						/* WB_WAIT_FOR_STALL狀態 */
						`WB_WAIT_FOR_STALL:
							begin
								stallreq	<=	`NoStop;
								cpu_data_o	<=	rd_buf;
							end
						default:
							begin
							end
					endcase
				end				
		end
		
endmodule
