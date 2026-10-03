.text
.globl _start

_start:
    # ---- عناوين القواعد المطابقة للـ Sets والـ Tags ----
    lui  s0, 0x1            # s0 = 0x1000  (Tests 1-3)
    lui  s1, 0x2            # s1 = 0x2000  (Test 4: Line A in Set 0)
    lui  s2, 0x4            # s2 = 0x4000  (Test 4/5: Line B in Set 0)
    lui  s3, 0x6            # s3 = 0x6000  (Test 4/5: Line C in Set 0 - Evictor)

    # ============================================================
    # Test 1: Store then Load (same address)
    #  0xAAAA = 0xB000 - 0x556
    # ============================================================
    lui  t1, 0xB
    addi t1, t1, -0x556     # t1 = 0xAAAA
    sw   t1, 0(s0)
    lw   t2, 0(s0)
    bne  t2, t1, FAIL

    # ============================================================
    # Test 2: Spatial locality (16-byte cache line: offsets 0..12)
    # ============================================================
    lui  t1, 0x1
    addi t1, t1, 0x111      # 0x1111
    sw   t1, 0x000(s0)

    lui  t1, 0x2
    addi t1, t1, 0x222      # 0x2222
    sw   t1, 0x004(s0)

    lui  t1, 0x3
    addi t1, t1, 0x333      # 0x3333
    sw   t1, 0x008(s0)

    lui  t1, 0x4
    addi t1, t1, 0x444      # 0x4444
    sw   t1, 0x00C(s0)

    # Read back all 4 words from the same 16-byte block
    lw   t2, 0x000(s0)
    lui  t3, 0x1
    addi t3, t3, 0x111
    bne  t2, t3, FAIL

    lw   t2, 0x004(s0)
    lui  t3, 0x2
    addi t3, t3, 0x222
    bne  t2, t3, FAIL

    lw   t2, 0x008(s0)
    lui  t3, 0x3
    addi t3, t3, 0x333
    bne  t2, t3, FAIL

    lw   t2, 0x00C(s0)
    lui  t3, 0x4
    addi t3, t3, 0x444
    bne  t2, t3, FAIL

    # ============================================================
    # Test 3: Temporal locality
    # ============================================================
    lui  t1, 0xA
    addi t1, t1, -0x667     # 0x9999
    sw   t1, 0x080(s0)      # address 0x1080
    lw   t2, 0x080(s0)      # Miss + Fill
    lw   t3, 0x080(s0)      # Hit
    lw   t4, 0x080(s0)      # Hit
    bne  t2, t4, FAIL
    bne  t3, t4, FAIL

    # ============================================================
    # Test 4: Dirty line write-back & 2-Way LRU Eviction
    #  0xBEEF = 0xC000 - 0x111
    # ============================================================
    lui  t1, 0xC
    addi t1, t1, -0x111     # t1 = 0xBEEF
    sw   t1, 0(s1)          # Write dirty data at 0x2000 (Set 0 -> Way 0)

    # Evict 0x2000 by filling both ways in Set 0:
    lui  t2, 0x11111
    sw   t2, 0(s2)          # Write to 0x4000 (Set 0 -> Way 1)
    
    lui  t2, 0x22222
    sw   t2, 0(s3)          # Write to 0x6000 (Set 0 -> Forces Eviction of 0x2000 via Write-Back)

    # Read back 0x2000 from Main Memory to verify Write-Back happened
    lw   t2, 0(s1)
    lui  t3, 0xC
    addi t3, t3, -0x111
    bne  t2, t3, FAIL

    # ============================================================
    # Test 5: 2-Way Set Conflict Capacity Test
    # ============================================================
    # Fill Line A (0x3000 -> Set 0)
    lui  t1, 0x1
    addi t1, t1, 0x234      # 0x1234
    lui  t5, 0x3
    sw   t1, 0(t5)

    # Fill Line B (0x5000 -> Set 0)
    lui  t1, 0x5
    addi t1, t1, 0x678      # 0x5678
    lui  t6, 0x5
    sw   t1, 0(t6)

    # Read back both to ensure both exist simultaneously in 2-Way Cache
    lw   t2, 0(t5)
    lui  t3, 0x1
    addi t3, t3, 0x234
    bne  t2, t3, FAIL

    lw   t2, 0(t6)
    lui  t3, 0x5
    addi t3, t3, 0x678
    bne  t2, t3, FAIL

    # ============================================================
    # PASS -> store 0x5555 at 0x40000000
    # ============================================================
PASS:
    lui  t0, 0x40000        # t0 = 0x40000000
    lui  t1, 0x5
    addi t1, t1, 0x555      # t1 = 0x5555
    sw   t1, 0(t0)
    jal  x0, END

    # ============================================================
    # FAIL -> store 0xDEAD at 0x40000000
    # ============================================================
FAIL:
    lui  t0, 0x40000
    lui  t1, 0xE
    addi t1, t1, -0x153     # t1 = 0xDEAD
    sw   t1, 0(t0)

END:
    jal  x0, END            # infinite loop
