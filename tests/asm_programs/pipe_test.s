    addi t0, zero, 2        # t0 = 2
    addi t1, zero, 3        # t1 = 3
    addi t2, zero, 5        # t2 = 5 (القيمة المتوقعة للمقارنة)
    nop                     # تأخير لضمان كتابة t0, t1, t2
    nop
    nop
    add  t3, t0, t1         # t3 = 2 + 3 = 5  (بعد أن أصبحت t0,t1 جاهزة)
    nop                     # تأخير لكتابة t3
    nop
    nop
    addi t4, zero, 0x100    # t4 = عنوان التخزين 0x100
    nop                     # تأخير لكتابة t4
    nop
    nop
    sw   t3, 0(t4)          # خزّن 5 في الذاكرة عند 0x100
    nop                     # (اختياري، لا خطر لأن sw لا يكتب سجلاً)
    lw   t5, 0(t4)          # اقرأ القيمة من 0x100 إلى t5
    nop                     # تأخير بسبب مخاطرة القراءة-بعد-التحميل
    nop
    nop
    beq  t5, t2, success    # إذا t5 == 5 اذهب إلى success
    nop                     # فتحة تأخير للتفرع (تُنفَّذ دائماً)

# مسار الفشل (لو لم يتحقق التفرع)
    addi t6, zero, 0x104    # عنوان علم النجاح
    nop
    nop
    nop
    sw   zero, 0(t6)        # اكتب 0 (فشل) إلى 0x104
    j    end                # اذهب إلى النهاية
    nop                     # فتحة تأخير للقفز

success:
    addi t6, zero, 0x104    # عنوان علم النجاح
    nop
    nop
    nop
    addi t0, zero, 1        # t0 = 1 (إشارة النجاح)
    nop
    nop
    nop
    sw   t0, 0(t6)          # اكتب 1 إلى 0x104

end:
    j    end                # حلقة لا نهائية
    nop                     # فتحة تأخير
