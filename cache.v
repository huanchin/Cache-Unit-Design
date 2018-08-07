module cache(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_rdata,
    proc_wdata,
    proc_stall,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready,
);
    
	parameter IDLE   = 4'b0000;
	parameter RCOM   = 4'b0001;
	parameter MRMEM  = 4'b0010;
	parameter RMEM   = 4'b0011;
	parameter ROK    = 4'b0100;
	parameter WCOM   = 4'b0101;
	parameter H_WMEM = 4'b0110;
	parameter M_WMEM = 4'b0111;
	parameter WMEM   = 4'b1000;
	parameter WOK    = 4'b1001;
	
//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output         proc_stall;
    output  [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;
    
//==== wire/reg definition ================================
    reg proc_stall;
	reg mem_read;
	reg mem_write;
	
	
	wire [24:0] tag;
	wire [2:0] index;
	wire [1:0] offset;
	reg  [153:0] c[7:0];
	reg  [3:0] curr_state;
	reg  [3:0] next_state;
	
	wire [153:0] c_chosen;
	wire c_v;
	wire [24:0] c_tag;
	wire [31:0] c_data0;
	wire [31:0] c_data1;
	wire [31:0] c_data2;
	wire [31:0] c_data3;
	wire [31:0] data;
	
	wire tag_equal;
	wire prehit;
	wire hit;
	
//==== combinational circuit ==============================
	assign tag = proc_addr[29:5];
	assign index = proc_addr[4:2];
	assign offset = proc_addr[1:0];
	
	assign c_chosen = c[index];
	assign c_v = c_chosen[153];
	assign c_tag = c_chosen[152:128];
	assign c_data0 = c_chosen[127:96];
	assign c_data1 = c_chosen[95:64];
	assign c_data2 = c_chosen[63:32];
	assign c_data3 = c_chosen[31:0];
	
	assign prehit = (tag==c_tag)? 1 : 0;
	assign hit = (c_v&prehit)? 1 : 0;
	assign data = (!offset)? c_data0:
				  (offset==2'b01)? c_data1:
				  (offset==2'b10)? c_data2:
				  c_data3;
	assign proc_rdata=data;
	
	//next stage logic
	always@(*)
		case(curr_state)
			IDLE:	if     (proc_read  && !proc_write) next_state = RCOM;
					else if(!proc_read && proc_write ) next_state = WCOM;
					else                               next_state = IDLE;
					
			RCOM:	if     (hit)                       next_state = ROK;
					else                               next_state = MRMEM;
					
			MRMEM:	if     (mem_ready)                 next_state = RMEM;
					else                               next_state = MRMEM;
			
			RMEM:	                                   next_state = ROK;
					
			ROK:	                                   next_state = IDLE;
			
			WCOM:	if     (hit)                       next_state = H_WMEM;
					else                               next_state = M_WMEM;
					
			H_WMEM:                                    next_state = WMEM;
					
			M_WMEM:                                    next_state = WMEM;
					
			WMEM:   if     (mem_ready)                 next_state = WOK;
					else                               next_state = WMEM;
			
			WOK:	                                   next_state = IDLE;    
			
			default:                                   next_state = IDLE;
		endcase
	always@(*)
		case (curr_state)
			IDLE:begin	
						proc_stall=1;
						mem_read =0;
						mem_write=0;
			end
			RCOM:begin		
						proc_stall=1;
						mem_read =0;
						mem_write=0;
			end
			MRMEM:begin		
						proc_stall=1;
						mem_read =1;
						mem_write=0;
			end
			RMEM:begin		
						proc_stall=1;
						mem_read =0;
						mem_write=0;
			end
			ROK:begin		
						proc_stall=0;
						mem_read =0;
						mem_write=0;
			end
			WCOM:begin		
						proc_stall=1;
						mem_read =0;
						mem_write=0;
			end
			H_WMEM:begin	
						proc_stall=1;
						mem_read =0;
						mem_write=0; 
			end
			M_WMEM:begin		
						proc_stall=1;
						mem_read =0;
						mem_write=0;
			end
			WMEM:begin		
						proc_stall=1;
						mem_read =0;
						mem_write=1;
			end
			WOK:begin
						proc_stall=0;
						mem_read =0;
						mem_write=0;
			end
			default: begin
						proc_stall=0;
						mem_read =0;
						mem_write=1;
			end
		endcase
	
	assign mem_wdata =  (!offset)?       {c_data3,c_data2,c_data1,proc_wdata}:
						(offset==2'b01)? {c_data3,c_data2,proc_wdata,c_data0}:
						(offset==2'b10)? {c_data3,proc_wdata,c_data1,c_data0}:
						{proc_wdata,c_data2,c_data1,c_data0};
	assign mem_addr = {tag,index};
//==== sequential circuit =================================
always@( posedge clk or posedge proc_reset ) begin
    if( proc_reset ) begin
		c[0]<=154'b0;
		c[1]<=154'b0;
		c[2]<=154'b0;
		c[3]<=154'b0;
		c[4]<=154'b0;
		c[5]<=154'b0;
		c[6]<=154'b0;
		c[7]<=154'b0;
		curr_state<=IDLE;
    end
    else begin
		
		curr_state <= next_state;
		
		if( (curr_state == H_WMEM) || (curr_state == M_WMEM)) begin
			
			case(offset)
				2'b00: c[index]<={1'b1,tag,proc_wdata,c_data1,c_data2,c_data3};
				2'b01: c[index]<={1'b1,tag,c_data0,proc_wdata,c_data2,c_data3};
				2'b10: c[index]<={1'b1,tag,c_data0,c_data1,proc_wdata,c_data3};   
				2'b11: c[index]<={1'b1,tag,c_data0,c_data1,c_data2,proc_wdata};
				default: c[index]<=154'b0;
			endcase
		end
			
		else if(curr_state == RMEM)
			c[index]<={1'b1,tag,mem_rdata[31:0],mem_rdata[63:32],mem_rdata[95:64],mem_rdata[127:96]};
			
    end
end

endmodule
