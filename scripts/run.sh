#!/bin/bash
# run.sh

# المتغيرات
PROJECT_DIR=$(pwd)
RTL_DIR="$PROJECT_DIR/src/rtl"
TESTBENCH="tb_top.sv"   # اسم ملف الـ Testbench
TOP_MODULE="top"        # اسم الوحدة العليا (DUT)
WAVEFORM_FILE="$PROJECT_DIR/sim/waveforms/trace.vcd"

# أمر Verilator (بناء ملف C++ للمحاكاة)
verilator --cc --trace --top-module $TOP_MODULE \
          -I$RTL_DIR \
          --exe $TESTBENCH \
          -o simv \
          $RTL_DIR/*.sv

# الدخول لمجلد obj_dir لعملية الـ make
cd sim/obj_dir
make -f V$TOP_MODULE.mk

# تشغيل المحاكاة
./V$TOP_MODULE

# فتح الموجات باستخدام GTKWave
gtkwave $WAVEFORM_FILE &

cd ../..
