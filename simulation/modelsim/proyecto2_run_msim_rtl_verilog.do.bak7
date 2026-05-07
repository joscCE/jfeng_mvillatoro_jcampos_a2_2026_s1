transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/PE.sv}

vlog -sv -work work +incdir+C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1 {C:/Users/jimmy/GitHub/jfeng_mvillatoro_jcampos_a2_2026_s1/tb_pe.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  tb_pe

add wave *
view structure
view signals
run -all
