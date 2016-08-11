set outdir build

open_checkpoint $outdir/post_route.dcp
write_bitstream -force $outdir/dnskv.bit
write_debug_probes -file $outdir/dnskv.ltx -force
