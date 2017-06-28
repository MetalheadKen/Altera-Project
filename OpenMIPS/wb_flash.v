/* 因DE2沒有Flash控制器，故實現之 */
module wb_flash(wb_clk_i, wb_rst_i, wb_cyc_i, wb_adr_i, wb_dat_i, wb_we_i, wb_sel_i, wb_stb_i, wb_dat_o, wb_ack_o,
				flash_adr_o, flash_dat_i, flash_rst, flash_oe, flash_ce, flash_we);

	/* Wishbone匯流排介面 */
	input  wire							wb_clk_i;			/* Wishbone匯流排時脈訊號 */
	input  wire 						wb_rst_i;			/* Wishbone匯流排重設訊號 */
	input  wire [31:0]					wb_adr_i;			/* Wishbone匯流排輸入的位址 */
	output reg  [31:0]					wb_dat_o;			/* Wishbone匯流排輸出的資料 */
	input  wire [31:0]					wb_dat_i;			/* Wishbone匯流排輸入的資料 */
	input  wire [3:0]					wb_sel_i;			/* Wishbone匯流排位元組選擇訊號 */
	input  wire							wb_we_i;			/* Wishbone匯流排寫入啟用訊號 */
	input  wire							wb_stb_i;			/* Wishbone匯流排送出訊號 */
	input  wire							wb_cyc_i;			/* Wishbone匯流排週期訊號 */
	output reg							wb_ack_o;			/* Wishbone匯流排輸出的回應 */
	
	/* Flash晶片介面 */
	output reg	[31:0]					flash_adr_o;		/* Flash位址訊號 */
	input  wire [7:0]					flash_dat_i;		/* 從Flash讀出的資料 */
	output wire							flash_rst;			/* Flash重設訊號，低電壓有效 */
	output wire 						flash_oe;			/* Flash輸入啟用訊號，低電壓有效 */	
	output wire 						flash_ce;			/* Flash片選訊號，低電壓有效 */
	output wire 						flash_we;			/* Flash寫入啟用訊號，低電壓有效 */
	
	reg  [3:0]							waitstate;
	wire [1:0]							adr_low;
	
	/* 如果Wishbone匯流排開始操作週期，那麼設定變數wb_acc為1;
	** 而且，如果是讀取操作，那麼設定變數wb_rd為1 */
	wire wb_acc = wb_cyc_i & wb_stb_i;						/* WISHBONE access */
	wire wb_rd	= wb_acc & !wb_we_i;						/* WISHBONE read access */
	
	/* 當變數wb_acc為1、wb_rd為1時，表示開始對Flash晶片的讀取動作。
	** 所以設定輸出訊號flash_ce、flash_oe都為0，也就是設定有效 */
	assign flash_ce = !wb_acc;
	assign flash_oe = !wb_rd;
	
	/* 因為不涉及對Flash晶片的寫入操作，所以輸出訊號flash_we始終設定為1 */
	assign flash_we = 1'b1;
	
	assign flash_rst = !wb_rst_i;
	
	always @(posedge wb_clk_i)
		begin
			if(wb_rst_i == 1'b1)
				begin
					waitstate	<= 	4'h0;
					wb_ack_o  	<= 	1'b0;
				end
			/* wb_acc為0，表示沒有存取請求 */
			else if(wb_acc == 1'b0)
				begin
					waitstate	<= 	4'h0;
					wb_ack_o  	<= 	1'b0;
					wb_dat_o  	<= 	32'h00000000;
				end
			/* 否則，有存取請求，開始讀取操作 */
			else if(waitstate == 4'h0)
				begin
					wb_ack_o  	<= 	1'b0;
					
					if(wb_acc)
						waitstate	<=	waitstate + 4'h1;
					
					/* 給出要讀取的第一個位元組的位址 */
					flash_adr_o	<= {10'b0000000000, wb_adr_i[21:2], 2'b00};
				end
			else
				begin
					/* 每個時脈週期將waitstate的值加1 */
					waitstate	<=	waitstate + 4'h1;
					
					if(waitstate == 4'h3)
						begin
							/* 經過3個時脈週期後，第一個位元組讀取到，保存到wb_dat_o[31:24] */
							wb_dat_o[31:24]	<=	flash_dat_i;
							
							/* 給出要讀取的第二個位址 */
							flash_adr_o	<= {10'b0000000000, wb_adr_i[21:2], 2'b01};							
						end
					else if(waitstate == 4'h6)
						begin
							/* 再經過3個時脈週期後，第二個位元組讀取到，保存到wb_dat_o[23:16] */
							wb_dat_o[23:16]	<=	flash_dat_i;
							
							/* 給出要讀取的第三個位址 */
							flash_adr_o	<= {10'b0000000000, wb_adr_i[21:2], 2'b10};							
						end
					else if(waitstate == 4'h9)
						begin
							/* 再經過3個時脈週期後，第三個位元組讀取到，保存到wb_dat_o[15:8] */
							wb_dat_o[15:8]	<=	flash_dat_i;
							
							/* 給出要讀取的第二個位址 */
							flash_adr_o	<= {10'b0000000000, wb_adr_i[21:2], 2'b11};							
						end
					else if(waitstate == 4'hc)
						begin
							/* 再經過3個時脈週期後，第四個位元組讀取到，保存到wb_dat_o[7:0] */
							wb_dat_o[7:0]	<=	flash_dat_i;
							
							/* wb_ack_o指派為1，作為Wishbone匯流排操作的回應 */
							wb_ack_o		<=	1'b1;
						end
					else if(waitstate == 4'hc)
						begin
							/* 經過1個時脈週期後，wb_ack_o指派為0，Wishbone匯流排操作結束 */
							wb_ack_o		<=	1'b0;
							waitstate		<=	4'h0;
						end
				end		
		end
			
endmodule
