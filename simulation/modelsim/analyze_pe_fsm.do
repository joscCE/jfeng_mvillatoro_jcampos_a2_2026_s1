transcript on
if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/Users/mavic/OneDrive/Escritorio/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/mavic/OneDrive/Escritorio/jfeng_mvillatoro_jcampos_a2_2026_s1/PE.sv}
vlog -sv -work work +incdir+C:/Users/mavic/OneDrive/Escritorio/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/mavic/OneDrive/Escritorio/jfeng_mvillatoro_jcampos_a2_2026_s1/PE_FSM_Analyzer.sv}

vsim -t 1ps -L rtl_work -L work -voptargs="+acc" PE_FSM_Analyzer

run -all
