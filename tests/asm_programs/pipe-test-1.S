    addi t0, zero, 2        
    addi t1, zero, 3        
    addi t2, zero, 5        
    nop                     
    nop
    nop
    add  t3, t0, t1         
    nop                     
    nop
    nop
    addi t4, zero, 0x100    
    nop                     
    nop
    nop
    sw   t3, 0(t4)          
    nop                     
    lw   t5, 0(t4)          
    nop                     
    nop
    nop
    beq  t5, t2, success    
    nop                     

    addi t6, zero, 0x104    
    nop
    nop
    nop
    sw   zero, 0(t6)        
    j    end                
    nop                     

success:
    addi t6, zero, 0x104    
    nop
    nop
    nop
    addi t0, zero, 1        
    nop
    nop
    nop
    sw   t0, 0(t6)          

end:
    j    end                
    nop                     
