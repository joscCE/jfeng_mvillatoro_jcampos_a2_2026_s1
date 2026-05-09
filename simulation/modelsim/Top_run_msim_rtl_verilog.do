transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Counter.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Timer.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Top_ff.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/PE.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Interconnect_FF.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Cache_ff.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Ram.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Vga_Controller.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/clk_div.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/deco_BDS.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/SevenSeg_Display.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Square_Area.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/CounterV.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Register.sv}
vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Comparator.sv}

vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/Top_ff_tb.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  Top_ff_tb

add wave *
view structure
view signals
run -all
