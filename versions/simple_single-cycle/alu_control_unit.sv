module alu_control_unit (
    input  logic [1:0] AluOp,
    input  logic [2:0] func3,
    input  logic [6:0] func7,
    output logic [3:0] alu_control
);
    
    always_comb begin
        alu_control = 4'b0010;

        case (AluOp)
            2'b00 : alu_control = 4'b0010; 
            
            2'b01 : alu_control = 4'b0110; 
            
            2'b10 : begin
                case (func3)
                    3'b000: begin
                        if (func7[5] == 1'b1) 
                            alu_control = 4'b0110; 
                        else                  
                            alu_control = 4'b0010; 
                    end
                    3'b111 : alu_control = 4'b0000; 
                    3'b110 : alu_control = 4'b0001; 
                    default: alu_control = 4'b0010;
                endcase
            end

            2'b11 : begin
                case (func3)
                    3'b000 : alu_control = 4'b0010; 
                    3'b111 : alu_control = 4'b0000; 
                    3'b110 : alu_control = 4'b0001; 
                    default: alu_control = 4'b0010;
                endcase
            end

            default: alu_control = 4'b0010;
        endcase
    end
endmodule
