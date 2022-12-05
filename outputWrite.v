module OutputWrite(

	// control signals
	input wire 		  		clk										,
	input wire 		  		reset_b									,
	input wire        		dut_run									,

	//Output SRAM interface
  	output reg        		output_sram_write_enable    			,
  	output reg [11:0] 		output_sram_write_addresss 				,
  	output reg [15:0] 		output_sram_write_data      			,
  	output reg [11:0] 		output_sram_read_address    			,
  	input wire [15:0] 		output_sram_read_data       			,

	// max pooling layer output
	input wire [1 : 0] valid_in												,
	input wire [7:0] data_in																			

	// output signals

);

//---------------------------------------------------------------------------
// Internal Signals and Parameters Declerations
//---------------------------------------------------------------------------

// write address
reg [11 : 0] write_address;
reg [11 : 0] ns_write_address;

// msb data registers
reg [7 : 0] msb_register;
reg [7 : 0] ns_msb_register;

// lsb data registers
reg [7 : 0] lsb_register;
reg [7 : 0] ns_lsb_register;

// write counter
reg [1 : 0] write_counter;
reg [1 : 0] ns_write_counter;

// max pooling valid_in = 2 sync
reg [1 : 0] valid_in_sync;
reg [1 : 0] ns_valid_in_sync;

//---------------------------------------------------------------------------
// Valid In Sync
//---------------------------------------------------------------------------

// valid_in_sync : sequential logic
always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	valid_in_sync <= 2'h0;
	 end
	else
	 begin
	 	valid_in_sync	<= ns_valid_in_sync;
	 end
end

// valid_in_sync : combinational logic
always@(*)
begin
	ns_valid_in_sync = valid_in;
end


//---------------------------------------------------------------------------
// Write Counter
//---------------------------------------------------------------------------

// write counter : sequential logic
always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	write_counter <= 2'h0;
	 end
	else
	 begin
	 	write_counter <= ns_write_counter;
	 end
end

// write counter : combinational logic
always@(*)
begin
	if(valid_in == 2'h1)
	 begin
	 	if(write_counter < 2'h2)
	 	 begin
	 	 	ns_write_counter = write_counter + 2'h1;
	 	 end
	 	else
	 	 begin
	 	 	ns_write_counter = 2'h0;
	 	 end
	 end
	else if(valid_in == 2'h2)
	 begin
	 	ns_write_counter = 2'h0;
	 end
	else
		if(write_counter == 2'h2)
		 begin
		 	ns_write_counter = 2'h0;
		 end
		else
	     begin
	 		ns_write_counter = write_counter;
	     end
end


//---------------------------------------------------------------------------
// Write Address
//---------------------------------------------------------------------------

// write address : sequential logic
always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	write_address <= 12'h0;
	 end
	else
	 write_address <= ns_write_address;
end

// write address : combinational logic 
always@(*)
begin
	if(write_counter == 2'h2)
	 begin
	 	ns_write_address = write_address + 1'b1;
	 end
	else if(valid_in_sync == 2'h2)
	 begin
	 	ns_write_address = write_address + 1'b1;
	 end
	else if(valid_in_sync == 2'h3)
	 begin
	 	ns_write_address = 12'h0;
	 end
	else
	 begin
	 	ns_write_address = write_address;
	 end
end

//---------------------------------------------------------------------------
// MSB and LSB Registers
//---------------------------------------------------------------------------

// MSB LSB Registers : Sequential Logic
always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	msb_register <= 8'h0;
	 end
	else
	 begin
	 	msb_register <= ns_msb_register;
	 end
end

always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	lsb_register <= 8'h0;
	 end
	else
	 begin
	 	lsb_register <= ns_lsb_register;
	 end
end

// MSB LSB Registers : Combinational Logic
always@(*)
begin
	if(write_counter == 2'h0 && (valid_in == 2'h1 || valid_in == 2'h2))
	 begin
	 	ns_msb_register = data_in;
	 end
	else
	 begin
	 	ns_msb_register = msb_register;
	 end
end

always@(*)
begin
	if(write_counter == 2'h1 && valid_in == 2'h1)
	 begin
	 	ns_lsb_register = data_in;
	 end
	else if(valid_in == 2'h2)
	 begin
	 	ns_lsb_register = 8'h0;
	 end
	else
	 begin
	 	ns_lsb_register = lsb_register;
	 end
end

//---------------------------------------------------------------------------
// Output sram interface : Signal Assignment
//---------------------------------------------------------------------------

always@(*)
begin
	output_sram_write_data = {msb_register, lsb_register};
	output_sram_write_addresss = write_address;
end

always@(*)
begin
	if(write_counter == 2'h2)
	 begin
	 	output_sram_write_enable = 1'b1;
	 end
	else if(valid_in_sync == 2'h2)
	 begin
	 	output_sram_write_enable = 1'b1;
	 end
	else
	 begin
	 	output_sram_write_enable = 1'b0;
	 end
end
endmodule

