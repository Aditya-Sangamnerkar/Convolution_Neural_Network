module MyDesign (
//---------------------------------------------------------------------------
//Control signals
  input   wire dut_run                    , 
  output  wire dut_busy                   ,
  input   wire reset_b                    ,  
  input   wire clk                        ,
 
//---------------------------------------------------------------------------
//Input SRAM interface
  output wire        input_sram_write_enable    ,
  output wire [11:0] input_sram_write_addresss  ,
  output wire [15:0] input_sram_write_data      ,
  output wire [11:0] input_sram_read_address    ,
  input wire [15:0] input_sram_read_data       ,

//---------------------------------------------------------------------------
//Output SRAM interface
  output wire        output_sram_write_enable    ,
  output wire [11:0] output_sram_write_addresss  ,
  output wire [15:0] output_sram_write_data      ,
  output wire [11:0] output_sram_read_address    ,
  input wire  [15:0] output_sram_read_data       ,

//---------------------------------------------------------------------------
//Scratchpad SRAM interface
  output reg        scratchpad_sram_write_enable    ,
  output reg [11:0] scratchpad_sram_write_addresss  ,
  output reg [15:0] scratchpad_sram_write_data      ,
  output reg [11:0] scratchpad_sram_read_address    ,
  input wire [15:0] scratchpad_sram_read_data       ,

//---------------------------------------------------------------------------
//Weights SRAM interface                                                       
  output wire        weights_sram_write_enable    ,
  output wire [11:0] weights_sram_write_addresss  ,
  output wire [15:0] weights_sram_write_data      ,
  output wire [11:0] weights_sram_read_address    ,
  input wire [15:0] weights_sram_read_data       

);
//---------------------------------------------------------------------------
// Internal Signals
//---------------------------------------------------------------------------
wire signed [19 : 0] mac_register;
wire [1: 0] valid_out_convolution;

wire signed [7 : 0] max_pooling_accumulator;
wire [1 : 0] valid_out_max_pooling;

//---------------------------------------------------------------------------
// DUT : Address Generation and Convolution 
//---------------------------------------------------------------------------
AddressGenerationConvolutionVariableN AddressGenerationConvolutionVariableNDut(

  // Control Signals
            .clk                           (clk             ),
            .reset_b                       (reset_b         ),
            .dut_run                       (dut_run         ),

  // Input SRAM interface
          .input_sram_write_enable        (input_sram_write_enable      ),
          .input_sram_write_addresss      (input_sram_write_addresss    ),
          .input_sram_write_data          (input_sram_write_data        ),
          .input_sram_read_address        (input_sram_read_address      ),
          .input_sram_read_data           (input_sram_read_data         ),

  //Weights SRAM interface                                                       
          .weights_sram_write_enable      (weights_sram_write_enable    ),
          .weights_sram_write_addresss    (weights_sram_write_addresss  ),
          .weights_sram_write_data        (weights_sram_write_data      ),
          .weights_sram_read_address      (weights_sram_read_address    ),
          .weights_sram_read_data         (weights_sram_read_data       ),

  // Convolution output 
          .mac_register                   (mac_register                 ),
          .valid                          (valid_out_convolution        ),
          .dut_busy                       (dut_busy)
         );


//---------------------------------------------------------------------------
// DUT : ReLu and Max Pooling 
//---------------------------------------------------------------------------
ReLuMaxPooling ReLuMaxPoolingDut(

  // control signals
        .clk                           (clk                             ),
        .reset_b                       (reset_b                         ),
        .dut_run                       (dut_run                         ),

  // convolution layer output signals   
       .valid_in                        (valid_out_convolution           ),
       .convolution_accumulator         (mac_register                    ),

  // output signals
       .max_pooling_accumulator         (max_pooling_accumulator         ),
       .valid_out                       (valid_out_max_pooling           )  
);

//---------------------------------------------------------------------------
// DUT : Output Write
//---------------------------------------------------------------------------
OutputWrite OutputWriteDut(
  // control signals
      .clk                            (clk                                  ),
      .reset_b                        (reset_b                              ),
      .dut_run                        (dut_run                              ),

  //Output SRAM interface
      .output_sram_write_enable       (output_sram_write_enable             ),
      .output_sram_write_addresss     (output_sram_write_addresss           ),
      .output_sram_write_data         (output_sram_write_data               ),
      .output_sram_read_address       (output_sram_read_data                ),
      .output_sram_read_data          (output_sram_read_data                ),

  // max pooling layer output
      .valid_in                       (valid_out_max_pooling                ),
      .data_in                        (max_pooling_accumulator              )              

  // output signals

);



endmodule

