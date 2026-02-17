cd [file dirname [file normalize [info script]]]

set FILES {src/design/wave_display.v \
	src/design/wave_capture.v \
	src/design/wave_display_top.v \
	src/sim/wave_display_tb.v \
	src/sim/wave_capture_tb.v \
	src/lab5.xdc \
	lab5.runs/impl_1/lab5_top.bit \
	lab5.runs/impl_1/lab5_top_timing_summary_routed.rpt \
	lab5.runs/synth_1/lab5_top.vds}


set archive_name "lab5_submission.tar.gz"

file delete -force $archive_name

set tar_command "tar -czf $archive_name"
set failed_files {}
append failed_files "\n                      "

foreach file $FILES {
        if {[file exists $file]} {
                append tar_command " $file"
        } else {
                puts "Warning: File not found - $file"
                append failed_files "$file\n                      "
        }
}


if {[catch {exec {*}$tar_command} result]} {
    puts "Error creating tar archive: $result"
} else {
    puts "\n \n \n \n \n~~~~~~Generated $archive_name. Please make sure that all of your files are in the .tar.gz zip folder. Congrats on finishing!~~~~~~ \n     List of failed files: $failed_files"
}
