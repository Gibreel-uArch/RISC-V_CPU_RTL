package rv32_types_pkg;
    
    typedef struct packed {
        logic       JumpImm;  
        logic       JumpReg;
        logic       Branch;
        logic       UseRs1;
        logic       UseRs2;
    } id_ctrl_t;

    typedef struct packed {
        logic [2:0] AluOp;
        logic       AluSrc1;  
        logic       AluSrc2;  
    } ex_ctrl_t;

    typedef struct packed {
        logic       MemRead;
        logic       MemWrite;
    } mem_ctrl_t;

    typedef struct packed {
        logic       RegWrite;
        logic       MemtoReg;
        logic       WriteData;
    } wb_ctrl_t;

    typedef struct packed {
        id_ctrl_t  id;
        ex_ctrl_t  ex;
        mem_ctrl_t mem;
        wb_ctrl_t  wb;
    } ctrl_signals_t;

endpackage
