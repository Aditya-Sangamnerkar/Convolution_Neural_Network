module ReLuMaxPooling(

	// control signals
	input wire 		  		clk										,
	input wire 		  		reset_b									,
	input wire        		dut_run									,

	// convolution layer output signals		
	input wire [1 : 0] 				valid_in						,
	input wire signed [19 : 0]		convolution_accumulator			,

	// output signals
	output reg signed [7 : 0]  	max_pooling_accumulator   			,
	output reg [1 : 0] valid_out          
);


//---------------------------------------------------------------------------
// Internal Signals and Parameters Declerations
//---------------------------------------------------------------------------
reg signed [7 : 0] relu_convolution;
reg signed [7 : 0] ns_max_pooling_accumulator;


// counter
reg [1 : 0] max_pooling_counter;
reg [1 : 0] ns_max_pooling_counter;

// valid 
reg [1 : 0] ns_valid_out;

//---------------------------------------------------------------------------
// ReLu
//---------------------------------------------------------------------------

//ReLu : Combinational Logic

always@(*)
begin
	// if(convolution_accumulator >= 20'h0 && convolution_accumulator	<= 20'h7F)
	//  begin
	//  	relu_convolution = convolution_accumulator[7 : 0];
	//  end
	// else if(convolution_accumulator > 20'h7F)
	//  begin
	//  	relu_convolution = 8'h7F;
	//  end
	// else
	//  begin
	//  	relu_convolution = 8'h0;
	//  end
	if(convolution_accumulator[19] == 1'b1) // negative number
	 begin
	 	relu_convolution = 8'h0;
	 end
	else // positive number
	 begin
	 	if(convolution_accumulator >= 20'h0 && convolution_accumulator	<= 20'h7F)
	 	 begin
	 		relu_convolution = convolution_accumulator[7 : 0];
	 	 end
	    else if(convolution_accumulator > $signed(20'h7F) )
	     begin
	 	    relu_convolution = 8'h7F;
	     end
	    else
	     begin
	 	   relu_convolution = 8'h0;
	     end
	 end

end

//---------------------------------------------------------------------------
// Max Pooling
//---------------------------------------------------------------------------

// Max Pooling Counter : Sequential logic
always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	max_pooling_counter <= 2'h0;
	 end
	else
	 begin
	 	max_pooling_counter	<= ns_max_pooling_counter;
	 end 
end

// Max Pooling Counter : Combinational Logic
always@(*)
begin
	if(valid_in == 2'h1 || valid_in	== 2'h2)
	 begin
	   if(max_pooling_counter < 2'h3)
	   begin
	   	ns_max_pooling_counter	= max_pooling_counter	+ 2'h1;
	   end
	   else
	   	begin
	   		ns_max_pooling_counter	= 2'h0;
	   	end
	 end
	else
	 begin
	 	ns_max_pooling_counter	= max_pooling_counter;
	 end
end

// Max Pooling Accumulator : Sequential Logic 
always@(posedge clk)
begin
	if(!reset_b)
	 begin
	 	max_pooling_accumulator	<= 8'h0;
	 end
	else
	 begin
	 	max_pooling_accumulator	<= ns_max_pooling_accumulator;
	 end
end

// Max Pooling Accumulator : Combinational Logic 
always@(*)
begin
 	if(valid_in	== 2'h1 || valid_in	== 2'h2)
 	 begin
 	 	if(max_pooling_counter	== 2'h0)
 	     begin
 	     	ns_max_pooling_accumulator = relu_convolution;
 	     end
 	    else
 	     begin
 	     	if(relu_convolution	> max_pooling_accumulator)
 	     	 begin
 	     	 	ns_max_pooling_accumulator	= relu_convolution;
 	     	 end
 	     	else
 	     	 begin
 	     	 	ns_max_pooling_accumulator	= max_pooling_accumulator;
 	     	 end
 	     end
 	 end
 	else
 	 begin
 	 	ns_max_pooling_accumulator	= max_pooling_accumulator;
 	 end
end

//---------------------------------------------------------------------------
// valid
//---------------------------------------------------------------------------

// valid_out : sequential logic
always@(posedge clk)
begin
	if(!reset_b	)
	  begin
	 	valid_out <= 2'h0;
	  end
	else
     begin
     	valid_out <= ns_valid_out;
     end
end

// valid_out : combinational logic
always@(*)
begin
	if(max_pooling_counter == 2'h3 && valid_in == 2'h1)
	 begin
	 	ns_valid_out = 2'h1;
	 end
	else if(max_pooling_counter == 2'h3 && valid_in == 2'h2)
	 begin
	 	ns_valid_out = 2'h2;
	 end
	else if(valid_in == 2'h3)
	 begin
	 	ns_valid_out = 2'h3;
	 end
	else
	 begin
	 	ns_valid_out = 2'h0;
	 end
end
endmodule