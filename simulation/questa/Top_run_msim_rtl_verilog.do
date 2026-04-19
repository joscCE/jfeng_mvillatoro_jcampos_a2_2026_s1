transcript on
if ![file isdirectory verilog_libs] {
	file mkdir verilog_libs
}

vlib verilog_libs/altera_ver
vmap altera_ver ./verilog_libs/altera_ver
vlog  -work altera_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/altera_primitives.v}

vlib verilog_libs/lpm_ver
vmap lpm_ver ./verilog_libs/lpm_ver
vlog  -work lpm_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/220model.v}

vlib verilog_libs/sgate_ver
vmap sgate_ver ./verilog_libs/sgate_ver
vlog  -work sgate_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/sgate.v}

vlib verilog_libs/altera_mf_ver
vmap altera_mf_ver ./verilog_libs/altera_mf_ver
vlog  -work altera_mf_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/altera_mf.v}

vlib verilog_libs/altera_lnsim_ver
vmap altera_lnsim_ver ./verilog_libs/altera_lnsim_ver
vlog -sv -work altera_lnsim_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/altera_lnsim.sv}

vlib verilog_libs/cyclonev_ver
vmap cyclonev_ver ./verilog_libs/cyclonev_ver
vlog  -work cyclonev_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/mentor/cyclonev_atoms_ncrypt.v}
vlog  -work cyclonev_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/mentor/cyclonev_hmi_atoms_ncrypt.v}
vlog  -work cyclonev_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/cyclonev_atoms.v}

vlib verilog_libs/cyclonev_hssi_ver
vmap cyclonev_hssi_ver ./verilog_libs/cyclonev_hssi_ver
vlog  -work cyclonev_hssi_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/mentor/cyclonev_hssi_atoms_ncrypt.v}
vlog  -work cyclonev_hssi_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/cyclonev_hssi_atoms.v}

vlib verilog_libs/cyclonev_pcie_hip_ver
vmap cyclonev_pcie_hip_ver ./verilog_libs/cyclonev_pcie_hip_ver
vlog  -work cyclonev_pcie_hip_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/mentor/cyclonev_pcie_hip_atoms_ncrypt.v}
vlog  -work cyclonev_pcie_hip_ver {/home/jecampos/altera_lite/25.1std/quartus/eda/sim_lib/cyclonev_pcie_hip_atoms.v}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Cache.sv}

vlog -sv -work work +incdir+/home/jecampos/Documents/materias/Arqui\ 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1 {/home/jecampos/Documents/materias/Arqui 2/Proyecto_2/jfeng_mvillatoro_jcampos_a2_2026_s1/Cache_tb.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  Cache_tb

add wave *
view structure
view signals
run -all
