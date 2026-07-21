.section .text
.globl _start

_start:
    li x5, 100    
    
    li x6, 5          
    sw x6, 0(x5)      
    
    li x6, 3          
    sw x6, 4(x5)      
    
    li x6, 8          
    sw x6, 8(x5)      
    
    li x6, 1          
    sw x6, 12(x5)     
    
    li x6, 4          
    sw x6, 16(x5)     

    li x7, 5          
    addi x8, x7, -1   

outer_loop:
    li x9, 0          
    li x10, 0         

inner_loop:
    slli x11, x9, 2   
    add x12, x5, x11  
    
    lw x13, 0(x12)    
    lw x14, 4(x12)    

    bge x14, x13, no_swap  

    sw x14, 0(x12)
    sw x13, 4(x12)
    li x10, 1          

no_swap:
    addi x9, x9, 1    
    blt x9, x8, inner_loop  

    beqz x10, verify
    j outer_loop      

verify:
    lw x15, 0(x5)     
    li x16, 1
    bne x15, x16, fail 

    lw x15, 4(x5)     
    li x16, 3
    bne x15, x16, fail 

    lw x15, 8(x5)     
    li x16, 4
    bne x15, x16, fail 

    lw x15, 12(x5)    
    li x16, 5
    bne x15, x16, fail 

    lw x15, 16(x5)    
    li x16, 8
    bne x15, x16, fail 

success:
    li x3, 0x01       
    j end

fail:
    li x3, 0xDEAD     

end:
    j end
