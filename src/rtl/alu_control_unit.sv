module alu_control_unit (
    input  logic [2:0] AluOp,
    input  logic [2:0] func3,
    input  logic [6:0] func7,
    output logic [3:0] alu_control
);
    
    always_comb begin
        alu_control = 4'b0010;

        case (AluOp)
            3'b000 : alu_control = 4'b0010;           // lw, sw, luipc, jalr
            
            3'b100 : alu_control = 4'b1010;           // lui

            3'b001 : alu_control = 4'b0110;           // SB Type

            3'b010 : begin
                case (func3)
                    3'b000: begin
                        if (func7[5] == 1'b1) 
                            alu_control = 4'b0110;     // sub 
                        else                  
                            alu_control = 4'b0010;     // add
                        end
                    3'b001 : alu_control = 4'b0100;    // sll
                    3'b010 : alu_control = 4'b0111;    // slt
                    3'b011 : alu_control = 4'b1000;    // sltu    
                    3'b100 : alu_control = 4'b0011;    // xor
                    3'b101 : begin
                        if (func7[5] == 1'b1) 
                            alu_control = 4'b1000;     // sra  
                        else                  
                            alu_control = 4'b0101;     // srl
                        end
                    3'b110 : alu_control = 4'b0001;    // or
                    3'b111 : alu_control = 4'b0000;    // and
                    default: alu_control = 4'b0010;
                endcase
            end

            3'b011 : begin
                case (func3)
                    3'b000 : alu_control = 4'b0010;    // addi 
                    3'b001 : alu_control = 4'b0100;    // slli
                    3'b010 : alu_control = 4'b0111;    // slti
                    3'b011 : alu_control = 4'b1001;    // sltui   
                    3'b100 : alu_control = 4'b0011;    // xori
                    3'b101 : begin
                        if (func7[5] == 1'b1) 
                            alu_control = 4'b1000;     // srai  
                        else                  
                            alu_control = 4'b0101;     // srli
                        end
                    3'b110 : alu_control = 4'b0001;    // ori
                    3'b111 : alu_control = 4'b0000;    // andi
                    default: alu_control = 4'b0010;
                endcase
            end

            default: alu_control = 4'b0010;
        endcase
    end
endmodule
