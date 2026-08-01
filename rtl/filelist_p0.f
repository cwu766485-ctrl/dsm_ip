# filelist_p0.f
#
# P0 RTL compilation list.
# Includes timing-clean 1-bit sign-domain paths plus native-multibit MASH
# comparison paths.

../rtl/mem/rom_reader.sv
../rtl/axis/axis_skid_buffer.sv
../rtl/dsm/singlebit/dsm_core.sv
../rtl/dsm/singlebit/dsm_core_dsm2.sv
../rtl/dsm/singlebit/dsm_core_ef1.sv
../rtl/dsm/singlebit/dsm_core_ef2.sv
../rtl/dsm/singlebit/dsm_core_mash11.sv
../rtl/dsm/singlebit/dsm_core_mash111.sv
../rtl/dsm/singlebit/dsm_core_mash22.sv
../rtl/dsm/multibit/dsm_core_multibit.sv
../rtl/dsm/multibit/dsm_core_multibit_lp1.sv
../rtl/dsm/multibit/dsm_core_multibit_lp2.sv
../rtl/dsm/multibit/dsm_core_multibit_ef1.sv
../rtl/dsm/multibit/dsm_core_multibit_ef2.sv
../rtl/dsm/multibit/dsm_core_multibit_mash11.sv
../rtl/dsm/multibit/dsm_core_multibit_mash111.sv
../rtl/dsm/multibit/dsm_core_multibit_mash22.sv
../rtl/interp/dsm_interp_fir_fixed.sv
../rtl/interp/dsm_interp_cic_direct.sv
../rtl/interp/dsm_interp_fir_polyphase.sv
../rtl/interp/dsm_interp_fir_i2_polyphase.sv
../rtl/interp/dsm_interp2_halfband.sv
../rtl/interp/dsm_interp_frontend.sv
../rtl/dpd/dpd_poly.v
../rtl/dpd/dpd_lut.v
../rtl/dpd/dpd_frontend.v
../rtl/duc/duc_fs4_merge.sv
../rtl/duc/duc_fs4_merge_signed.sv

../rtl/duc/duc_nco_mix_signed.v
../rtl/ip/dsm_ip_core.sv
../rtl/ip/dsm_ip_top.v
../rtl/axi/dsm_ip_axi_top.v
../rtl/top/p0_top_lp1.v
../rtl/top/p0_top_lp2.v
../rtl/top/p0_top_ef1.v
../rtl/top/p0_top_ef2.v
../rtl/top/p0_top_mash11_mb.v
../rtl/top/p0_top_mash111_mb.v
../rtl/top/p0_top_mash22_mb.v

# Testbenches live in verif/tb and are compiled by the runner.
