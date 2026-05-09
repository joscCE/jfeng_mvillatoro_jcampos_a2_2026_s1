transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Counter.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Timer.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/PE.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Top.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Interconnect_MSI.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Ram.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Cache_MSI.sv}
vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/clk_div.sv}

vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Top_tb.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  Top_tb

add wave *
view structure
view signals
run -all
