package require Tk
package require Thread

lappend auto_path "./ttk-themes/awthemes-10.4.0/"
package require awdark
package require awlight
lappend auto_path "./ttk-themes/aquablue/"
package require ttk::theme::aquablue
lappend auto_path "./ttk-themes/Aquativo/"
package require ttk::theme::aquativo
lappend auto_path "./ttk-themes/Arc/"
package require ttk::theme::Arc
lappend auto_path "./ttk-themes/clearlooks/"
package require ttk::theme::clearlooks
lappend auto_path "./ttk-themes/plastik/"
package require ttk::theme::plastik
lappend auto_path "./ttk-themes/radiance/"
package require ttk::theme::radiance
lappend auto_path "./ttk-themes/WinXP-Blue/"
package require ttk::theme::winxpblue

###################
set version "1.6"
set program_url "https://github.com/EDETNAOZERO/Solution-Finder-EN/releases"
wm title . "Solution finder EN $version"
wm resizable . 0 0
###################

#sfinder fig util defaults, might be changed in the future versions
set preview_full_width 342  
set preview_full_height 682
set preview_full_cube 32 
set preview_full_delta 2
set preview_full_border 2 

set java [auto_execok java]
set 7za [auto_execok 7za]
set java_website https://www.java.com/download/
tsv::set shared java $java

#global variables
set hold 1
set mirror 0
set lines 4
set mode path
set queue ""
set tetfu ""
set preset_name ""
set preset_old_name "" 
set tid 0
tsv::set log lines {}
set scrolling -1
set first_url ""

#read_options 
if {[file exists data/options.txt]} {
	set options [open data/options.txt r]
	gets $options fumen_url
	gets $options browser
	gets $options preview_theme
	gets $options widget_theme 
	gets $options auto_clear
	if { [catch {close $options} err ] } {
		tk_messageBox -icon error -message "Could not close options.txt: $err"
		exit
	}
}
#default options
if {(![info exists fumen_url]) || ($fumen_url eq "")} {
	set fumen_url https://harddrop.com/fumen/ 
}
if {(![info exists browser]) || ($browser eq "")} {
	set browser auto
}
if {(![info exists preview_theme]) || ($preview_theme eq "")} {
	set preview_theme default
}
if {(![info exists widget_theme]) || ($widget_theme eq "")} {
	set widget_theme vista
}
if {(![info exists auto_clear]) || ($auto_clear eq "")} {
	set auto_clear 0
}

set themes_list [ttk::style theme names]
set themes_list [lsearch -inline -all -not -exact $themes_list classic]
set themes_list [lsearch -inline -all -not -exact $themes_list default]
if {[lsearch -exact $themes_list $widget_theme]==-1} {
	set widget_theme [lindex $themes_list 0]
}
ttk::style theme use $widget_theme 

proc write_options {} {
	global fumen_url
	global browser
	global preview_theme
	global widget_theme
	global auto_clear
	set options [open data/options.txt w] 
	puts $options "$fumen_url"
	puts $options "$browser"
	puts $options "$preview_theme"
	puts $options "$widget_theme"
	puts $options "$auto_clear"
	if { [catch {close $options} err ] } {
		tk_messageBox -icon error -message "Could not close options.txt: $err"
		exit
	}
}


###################
option add *tearOff 0

#root
bind . <Escape> {exit}
font create BoldTimes -family times -weight bold

#menu
menu .menubar
. configure -menu .menubar
set m .menubar
menu $m.file
menu $m.edit
menu $m.help
$m add cascade -menu $m.file -label File
$m.file add command -label "Export current preset" -command export
$m.file add command -label "Import preset" -command import
$m.file add separator
$m.file add command -label "Exit" -command exit
$m add cascade -menu $m.edit -label Edit
$m.edit add command -label "Temporary preset" -command edit_temporary
$m.edit add command -label "Add new preset" -command add_new_preset
$m.edit add command -label "Copy current preset" -command copy_preset
$m.edit add command -label "Edit current preset" -command edit_preset
$m.edit add command -label "Delete current preset" -command delete_preset
$m.edit add separator
$m.edit add command -label "Options" -command show_options
$m add cascade -menu $m.help -label Help
$m.help add command -label "About" -command show_about

#####common controls
grid [ttk::frame .common -padding "3 3 12 12"] -column 0 -row 0 -sticky news
grid columnconfigure . 0 -weight 1 
grid rowconfigure . 0 -weight 1

bind . <Destroy> {stop}

grid [tk::canvas .common.preview -width [expr $preview_full_width / 2]  -height [expr $preview_full_height / 2]] -column 0 -row 0 -pady 5

#grid [ttk::scrollbar .common.xs -orient horizontal -command ".common.log xview"] -column 0 -row 2 -sticky we -columnspan 2 
grid [ttk::scrollbar .common.ys -orient vertical -command ".common.log yview"] -column 100 -row 3 -sticky ns -rowspan 2
grid [tk::text .common.log -width 80 -height 10 -wrap word ] -column 0 -row 3 -sticky news -columnspan 100 -rowspan 2
.common.log insert end "Backend command log will be listing here\n"
.common.log configure -state disabled
.common.log configure -yscrollcommand ".common.ys set"
#.common.log configure -xscrollcommand ".common.xs set"

#####main window
grid [ttk::frame .common.main -padding "3 3 12 12"] -column 1 -row 0 -sticky news

#row 0
grid [ttk::frame .common.main.row0] -column 0 -row 0 -sticky news -columnspan 10
grid [ttk::label .common.main.row0.label -text "Preset:"] -column 0 -row 0 -sticky w -padx 5
grid [ttk::combobox .common.main.row0.combo -width 40 -state readonly -textvariable preset_name] -column 1 -row 0 -sticky nsew -sticky w
bind .common.main.row0.combo <<ComboboxSelected>> {select_preset}

#row 1
grid [ttk::frame .common.main.row1] -column 0 -row 1 -sticky news -columnspan 10
grid [ttk::checkbutton .common.main.row1.mirror_check -text "Mirror the field" -variable mirror -onvalue 1 -offvalue 0 -command toggle_mirror] -column 0 -row 0 -sticky wn
grid [ttk::checkbutton .common.main.row1.hold_check -text "Use hold" -variable hold -onvalue 1 -offvalue 0 -command save_preset_state] -column 1 -row 0 -sticky wn
grid [ttk::labelframe .common.main.row1.label_frame -text "Mode"] -column 2 -row 0 -sticky n
grid [ttk::radiobutton .common.main.row1.label_frame.mode1 -text "Path" -variable mode -value path -command save_preset_state] -column 2 -row 0 -sticky wn -padx 5
grid [ttk::radiobutton .common.main.row1.label_frame.mode2 -text "Percent" -variable mode -value "percent -fc 0" -command save_preset_state] -column 2 -row 1 -sticky wn -padx 5
foreach w [winfo children .common.main.row1] {grid configure $w -padx 5 -pady 5}

#row 2
ttk::style configure courier.TButton -font "courier" -weight bold
grid [ttk::frame .common.main.row2] -column 0 -row 2 -sticky news -columnspan 10
grid [ttk::labelframe .common.main.row2.label_frame -text "Queue"] -column 0 -row 0 -sticky nwes
grid [ttk::frame .common.main.row2.label_frame.row0] -column 0 -row 0 -sticky news -padx 5 -pady 5
grid [ttk::button .common.main.row2.label_frame.row0.i -text "I" -width 3 -style courier.TButton -command {set queue "$queue I"}] -column 0 -row 0 
grid [ttk::button .common.main.row2.label_frame.row0.j -text "J" -width 3 -style courier.TButton -command {set queue "$queue J"}] -column 1 -row 0
grid [ttk::button .common.main.row2.label_frame.row0.l -text "L" -width 3 -style courier.TButton -command {set queue "$queue L"}] -column 2 -row 0
grid [ttk::button .common.main.row2.label_frame.row0.o -text "O" -width 3 -style courier.TButton -command {set queue "$queue O"}] -column 3 -row 0
grid [ttk::button .common.main.row2.label_frame.row0.s -text "S" -width 3 -style courier.TButton -command {set queue "$queue S"}] -column 4 -row 0
grid [ttk::button .common.main.row2.label_frame.row0.t -text "T" -width 3 -style courier.TButton -command {set queue "$queue T"}] -column 5 -row 0
grid [ttk::button .common.main.row2.label_frame.row0.z -text "Z" -width 3 -style courier.TButton -command {set queue "$queue Z"}] -column 6 -row 0
grid [ttk::button .common.main.row2.label_frame.row0.a -text "*!" -width 3 -style courier.TButton -command {set queue "$queue *!"}] -column 7 -row 0 -sticky w
grid [ttk::button .common.main.row2.label_frame.row0.none -width 3 -style courier.TButton] -column 8 -row 0 -sticky w
.common.main.row2.label_frame.row0.none configure -state disabled
grid [ttk::button .common.main.row2.label_frame.row0.help -text "?" -width 3 -style courier.TButton -command show_help] -column 9 -row 0 -sticky e
winfo class .common.main.row2.label_frame.row0.help

grid [ttk::frame .common.main.row2.label_frame.row1] -column 0 -row 1 -sticky e -padx 5 -pady 5
grid [ttk::button .common.main.row2.label_frame.row1.clear -text "Clear" -command {set queue ""}] -column 0 -row 1 -sticky w
grid [ttk::entry .common.main.row2.label_frame.row1.queue -textvariable queue -width 30] -column 1 -row 1 -sticky we -padx 5
grid [ttk::button .common.main.row2.label_frame.row1.go -text "Go" -command go] -column 2 -row 1 -sticky e
bind .common.main.row2.label_frame.row1.queue <Return> {if {$queue ne "" } { go}}

#row 3
grid [ttk::button .common.main.open_minimal -text "Open minimal solutions in a browser" -command {invokeBrowser path_minimal.html}] -column 0 -row 3 -sticky we
grid [ttk::progressbar .common.main.progress -orient horizontal -mode indeterminate] -column 1 -row 3 -sticky we -columnspan 9
.common.main.progress start

#row 4
grid [ttk::button .common.main.open_first -text "Open the first solution in a browser" -command open_first -state disabled] -column 0 -row 4 -sticky we

#configure
foreach w [winfo children .common.main] {grid configure $w -padx 5 -pady 5}
#focus .c.feet

#####preset window
grid [ttk::frame .common.preset -padding "3 3 12 12"] -column 1 -row 0 -sticky news

#row 0
grid [ttk::frame .common.preset.row0] -column 0 -row 0 -sticky news -columnspan 10
grid [ttk::label .common.preset.row0.label -text "Edit name:"] -column 0 -row 0 -sticky w -padx 5
grid [ttk::entry .common.preset.row0.entry -width 40 -textvariable preset_name] -column 1 -row 0 -sticky nsew -sticky w

#row 1
grid [ttk::label .common.preset.help -text "Open fumen in a browser, fill the field. This utility supports only basic fumen data so just use defaults, don't change anything. Press the \"Output data/★ データ出力\" button, copy and import it. The text should look similar to \"v115@vhAAgH\"." -wraplength 300] -column 0 -row 1 -sticky w

#row 2
grid [ttk::frame .common.preset.row2] -column 0 -row 2 -sticky news -columnspan 10
grid [ttk::button .common.preset.row2.fumen_button -text "Open fumen" -command fumen] -column 1 -row 3 -sticky e
grid [ttk::button .common.preset.row2.fumen_paste -text "Import data from clipboard" -command paste_fumen] -column 2 -row 3 -sticky w -padx 10
grid [ttk::label .common.preset.row2.label -text "no data"] -column 3 -row 3

#row 3
grid [ttk::frame .common.preset.row3] -column 0 -row 3 -sticky news -columnspan 10
grid [ttk::spinbox .common.preset.row3.lines_spin -from 1 -to 12 -textvariable lines -state readonly] -column 0 -row 0 -sticky e
grid [ttk::label .common.preset.row3.lines_label -text "lines should be filled to achieve a PC."] -column 1 -row 0 -sticky w -padx 10

#row 4
grid [ttk::frame .common.preset.row4] -column 0 -row 4 -sticky news -columnspan 10
grid [ttk::label .common.preset.row4.label -text "Preview theme:"] -column 0 -row 0 -sticky w -padx 5
foreach f [glob -directory theme *.properties] {
	set f  [string range $f 6 [expr [string length $f]-12]]
	lappend l $f
}
grid [ttk::combobox .common.preset.row4.combo -width 40 -textvariable preview_theme -state readonly -values [lsort -ascii $l]] -column 1 -row 0 -sticky nsew -sticky w
bind .common.preset.row4.combo <<ComboboxSelected>> {make_preview}

#row 5
grid [ttk::frame .common.preset.row5] -column 0 -row 5 -sticky news -columnspan 10
grid [ttk::button .common.preset.row5.cancel -text "Cancel" -command {show_main }] -column 0 -row 0 -sticky w
grid [ttk::button .common.preset.row5.save -text "Save preset" -command save_preset] -column 1 -row 0 -sticky e -padx 10

#configure
foreach w [winfo children .common.preset] {grid configure $w -padx 5 -pady 5}

###################

proc toggle_minimal {} {
	if {[file exists path_minimal.html]} {
		.common.main.open_minimal configure -state enabled
	} else {
		.common.main.open_minimal configure -state disabled
	}
}

proc show_main {} {
	global m
	grid remove .common.preset
	grid .common.main
	grid remove .common.main.progress
	$m.file entryconfigure "Export current preset" -state active
	$m.file entryconfigure "Import preset" -state active
	$m.edit entryconfigure "Temporary preset" -state active
	$m.edit entryconfigure "Add new preset" -state active
	$m.edit entryconfigure "Copy current preset" -state active
	$m.edit entryconfigure "Edit current preset" -state active
	$m.edit entryconfigure "Delete current preset" -state active
	find_presets
	toggle_minimal
	update_first
}

proc show_preset {} {
	global m
	grid remove .common.main
	grid .common.preset
	bind . <Return> {save_preset}
	$m.file entryconfigure "Export current preset" -state disabled
	$m.file entryconfigure "Import preset" -state disabled
	$m.edit entryconfigure "Temporary preset" -state disabled
	$m.edit entryconfigure "Add new preset" -state disabled
	$m.edit entryconfigure "Copy current preset" -state disabled
	$m.edit entryconfigure "Edit current preset" -state disabled
	$m.edit entryconfigure "Delete current preset" -state disabled
}

proc add_new_preset {} {
	global preset_name
	global lines
	global tetfu
	set tetfu ""
	set lines 4
	.common.preset.row0.entry configure -state enabled
	set preset_name ""
	show_preset
	.common.preset.row2.label config -text "no data"
	no_preview
	set preset_old_name ""
}

proc copy_preset {} {
	global preset_name
	global lines
	global tetfu
	.common.preset.row0.entry configure -state enabled
	set chan [open presets/$preset_name/tetfu.txt r]
	gets $chan tetfu
	close $chan
	set chan [open presets/$preset_name/field.txt r]
	gets $chan lines
	close $chan
	set preset_name "$preset_name copy"
	show_preset
	.common.preset.row2.label config -text "data impoted"
	make_preview 
	set preset_old_name ""
}

proc edit_temporary {} {
	global preset_name
	global tetfu
	global lines
	set tetfu ""
	set lines 4
	.common.preset.row0.entry configure -state disabled
	set preset_name "temp"
	show_preset
	no_preview
	.common.preset.row2.label config -text "no data"
	set preset_old_name ""
}

proc edit_preset {} {
	global preset_name
	global preset_old_name
	global lines
	global tetfu
	if {"temp" eq $preset_name} {
		.common.preset.row0.entry configure -state disabled
	} else {
		.common.preset.row0.entry configure -state enabled
	}
	set chan [open presets/$preset_name/tetfu.txt r]
	gets $chan tetfu
	close $chan
	set chan [open presets/$preset_name/field.txt r]
	gets $chan lines
	close $chan
	show_preset
	.common.preset.row2.label config -text "data impoted"
	make_preview 
	set preset_old_name $preset_name
}

proc show_about {} {
	global program_url
	if {[tk_messageBox -type okcancel -message "[wm title .]\n\nAn English translated GUI for knewjade's Solution Finder.\nPress OK to proceed to the website for updates."] eq "ok"} {
		invokeBrowser $program_url
	}
}

proc show_help {} {
	.common.main.row2.label_frame.row0.help configure -state disabled
	toplevel .help -takefocus 0
	bind .help <Destroy> {.common.main.row2.label_frame.row0.help configure -state enabled }
	bind .help <Escape> { destroy .help }
	wm resizable .help 0 0
	wm title .help "Help"
	raise .help
	focus .help

	grid [ttk::frame .help.c -padding "3 3 12 12"] -column 0 -row 0 -sticky news
	grid [tk::text .help.c.text -font times -bd 0 -width 53 -height 14] -column 0 -row 0
	#bindtags .help.c.text {.help all} ;#disable text selection

	.help.c.text tag configure title -font BoldTimes -foreground blue
	.help.c.text tag configure highlighted -font BoldTimes -foreground red

	.help.c.text insert end "PATTERNS EXAMPLES:\n\n"
	.help.c.text tag add title 1.0 2.0
	.help.c.text insert end "I: only I: 1 pattern\n"
	.help.c.text tag add highlighted 3.0 3.2
	.help.c.text tag add highlighted 3.8 3.10
	.help.c.text insert end "I, T, S, Z: ITSZ: 1 pattern\n"
	.help.c.text tag add highlighted 4.0 4.17
	.help.c.text insert end "\[SZ\] , O, \[JL\]: SOJ, SOL, ZOJ, ZOL: 4 patterns\n"
	.help.c.text tag add highlighted 5.0 5.35
	.help.c.text insert end "*: same as \[TIJLSZO\]: 7 patterns\n"
	.help.c.text tag add highlighted 6.0 6.2
	.help.c.text tag add highlighted 6.11 6.21
	.help.c.text insert end "L, *: LT, LI, LJ, LL, LS, LZ, LO: 7 patterns\n"
	.help.c.text tag add highlighted 7.0 7.33
	.help.c.text insert end "\[SZLJ\]: choose one mino from SZJL: 4 patterns\n"
	.help.c.text tag add highlighted 8.0 8.7
	.help.c.text tag add highlighted 8.28 8.34
	.help.c.text insert end "\[^TI\]: select one from other than TI: 5 patterns\n"
	.help.c.text tag add highlighted 9.0 9.6
	.help.c.text tag add highlighted 9.34 9.37
	.help.c.text insert end "\[SZLJ\]p2: permutation to select 2 from SZLJ: 12 patterns\n"
	.help.c.text tag add highlighted 10.0 10.9
	.help.c.text tag add highlighted 10.39 10.44
	.help.c.text insert end "*p3: equivalent to \[TIJLSZO\]p3: 7P3=210 patterns\n"
	.help.c.text tag add highlighted 11.0 11.4
	.help.c.text tag add highlighted 11.19 11.31
	.help.c.text insert end "! is a combination that uses all the minos (\[\] or *) specified on the left\n"
	.help.c.text tag add highlighted 12.0 12.1
	.help.c.text tag add highlighted 12.44 12.47
	.help.c.text tag add highlighted 12.50 12.51
	.help.c.text insert end "\[SZLJ\]!: same as \[SZLJ\]p4: 4P4=4!=24 patterns\n"
	.help.c.text tag add highlighted 13.0 13.8
	.help.c.text tag add highlighted 13.17 13.26
	.help.c.text insert end "*!: equivalent to \[TIJLSZO\]p7: 7P7=7!=5040 patterns"
	.help.c.text tag add highlighted 14.0 14.3
	.help.c.text tag add highlighted 14.18 14.30
	.help.c.text configure -state disabled
}


proc show_options {} {
	global fumen_url
	global browser
	global preview_theme
	global widget_theme
	global auto_clear
	global themes_list

	toplevel .options -takefocus 0
	bind .options <Return> {apply_options}
	bind .options <Escape> {apply_options}
	wm protocol .options WM_DELETE_WINDOW apply_options
	wm resizable .options 0 0
	wm title .options "Options"
	raise .options
	focus .options
	grab set .options

	grid [ttk::frame .options.c -padding "3 3 12 12"] -column 0 -row 0 -sticky news

	#row 0
	grid [ttk::label .options.c.preset_label -text "Fumen:"] -column 0 -row 0 -sticky e
	grid [ttk::frame .options.c.row0] -column 1 -row 0 -sticky news 
	grid [ttk::combobox .options.c.row0.preset -values [list https://harddrop.com/fumen/ https://fumen.zui.jp/ ] -width 50 -textvariable fumen_url ] -column 0 -row 0 -sticky nsew 
	grid [ttk::button .options.c.row0.button -text "Test fumen" -command {invokeBrowser $fumen_url}] -column 1 -row 0 -padx 10
	
	#row 1
	grid [ttk::label .options.c.browse_label -text "Web browser:"] -column 0 -row 1 -sticky e
	grid [ttk::frame .options.c.row1] -column 1 -row 1 -sticky news 
	grid [ttk::frame .options.c.row1.browser_frame -padding "10 0 10 0" -borderwidth 2 -relief sunken] -column 1 -row 2 -sticky news 
	grid [ttk::label .options.c.row1.browser_frame.browser_status -textvariable browser -width 40]
	grid [ttk::button .options.c.row1.browser_auto -text "auto" -command {set browser auto}] -column 2 -row 2 -sticky e -padx 10
	grid [ttk::button .options.c.row1.browser_manual -text "manual" -command set_browser_manual] -column 3 -row 2 -sticky e
	
	#row 2
	grid [ttk::label .options.c.label -text "Widget theme:"] -column 0 -row 2 -sticky e
	grid [ttk::frame .options.c.row2] -column 1 -row 2 -sticky news 
	grid [ttk::combobox .options.c.row2.combo -textvariable widget_theme -state readonly -values [lsort -ascii $themes_list] -width 20] -column 1 -row 0 -sticky we -padx 5
	bind .options.c.row2.combo <<ComboboxSelected>> {ttk::style theme use $widget_theme} 
	grid [ttk::checkbutton .options.c.row2.check -text "Auto clear queue" -variable auto_clear -onvalue 1 -offvalue 0] -column 2 -row 0 -sticky w -padx 20

	#row 10 
	#grid [ttk::button .options.c.main -text "Apply options" -command apply_options] -column 0 -row 10 -sticky es
	
	#configure
	foreach w [winfo children .options.c] {grid configure $w -padx 5 -pady 5}
}

##########################

proc set_browser_manual {} {
	global browser
	set types { {{Executables} {*.exe} } }
	set browser [tk_getOpenFile -filetypes  $types	]
	if {$browser eq "" } {
		set browser auto
	}
}

proc apply_options {} {
	write_options
	destroy .options
}

proc apply_preset {} {
	show_main
}

proc invokeBrowser {url} {
  # open is the OS X equivalent to xdg-open on Linux, start is used on Windows
  global browser 
  set commands {xdg-open open start}
  foreach auto_browser $commands {
    if {$auto_browser eq "start"} {
      set command [list {*}[auto_execok start] {}]
    } else {
      set command [auto_execok $auto_browser]
    }
    if {[string length $command]} {
      break
    }
  }

  if {[string length $command] == 0} {
    return -code error "couldn't find browser"
  }

  if {[string equal $browser auto]} {
	  if {[catch {exec {*}$command $url &} error]} {
	    return -code error "couldn't execute '$command': $error"
	  }
  } else {
	  if {[catch {exec "$browser" $url &} error]} {
	    return -code error "couldn't execute '$command': $error"
	  }
  }
}

proc fumen {} {  
	global fumen_url
	global tetfu
	if {"" eq $tetfu} {
		invokeBrowser $fumen_url
	} else {
		invokeBrowser "$fumen_url?$tetfu"
	}
}

proc no_preview {} {
	image create photo preview -file {data/preview.gif}
	preview copy preview -subsample 2
	.common.preview create image 2 2 -image preview -anchor nw
}

proc lock_preset {} {
	.common.preset.row0.entry configure -state disabled
	foreach w [winfo children .common.preset.row2] {$w configure -state disabled}
	.common.preset.row3.lines_spin configure -state disabled
	.common.preset.row4.combo configure -state disabled
	foreach w [winfo children .common.preset.row5] {$w configure -state disabled}
	after idle {set locked 1}
	vwait locked
}

proc unlock_preset {} {
	global preset_name
	if {$preset_name ne "temp"} {
		.common.preset.row0.entry configure -state enabled
	}
	foreach w [winfo children .common.preset.row2] {$w configure -state enabled}
	.common.preset.row3.lines_spin configure -state enabled
	.common.preset.row4.combo configure -state readonly
	foreach w [winfo children .common.preset.row5] {$w configure -state enabled}
}

proc make_preview {} {
	global java
	global preview_theme
	global tetfu
	if {$tetfu eq ""} {
		return
	}
	lock_preset
	file delete -force output
	set out [open "|$java -jar sfinder.jar util fig --color $preview_theme -l 20 -f no --tetfu $tetfu 2>@1" r]
	while {1} {
		fileevent $out readable 
		if {[eof $out]} {
			break
		}
		.common.log configure -state normal
		.common.log insert end "[gets $out]\n"
		.common.log configure -state disabled
		.common.log see end
	}
	if { ![file exists {output/fig.gif}] } {
		unlock_preset
		return
	}
	image create photo preview_full -file {output/fig.gif}
	image create photo preview
	preview copy preview_full -subsample 2
	.common.preview create image 2 2 -image preview -anchor nw
	unlock_preset
}

proc make_previews {} {
	global preview_full_width
	global preview_full_height
	global preview_full_border
	global preview_full_cube
	global preview_full_delta 
	image create photo full_preview -file {output/fig.gif}
	image create photo preview
	preview copy full_preview -subsample 2
	image create photo preview_mirrored
	
	preview_mirrored copy preview

	set w [expr $preview_full_width / 2]
	set h [expr $preview_full_height / 2]
	set b [expr $preview_full_border / 2]
	set c [expr $preview_full_cube / 2]
	set d [expr $preview_full_delta / 2]

	for {set x 0 } {$x <10 } {incr x} {
		for {set y 0} {$y <20} {incr y} {
			set from_x1 [expr $b + ($x*$c)+($x*$d)] 
			set from_y1 [expr $b + ($y*$c)+($y*$d)] 
			set from_x2 [expr $from_x1 + $c +1] 
			set from_y2 [expr $from_y1 + $c +1]
			set to_x1 [expr $w - $from_x2 + 1]
			set to_x2 [expr $w - $from_x1 + 1]
			set to_y1 $from_y1
			set to_y2 $from_y2
			
			preview_mirrored copy preview \
				-from $from_x1 $from_y1 $from_x2 $from_y2\
				-to $to_x1 $to_y1 $to_x2 $to_y2
		}
	}

	#set w [expr $preview_full_width/2]
	#set h [expr $preview_full_height/2]
	#for {set x 0} {$x < $w} {incr x} {
	#	for {set y 0} {$y < $h} {incr y} {
	#		set mirrored_x [expr $w - $x -1]
	#		preview_mirrored copy preview -from $x $y [expr $x+1] [expr $y+1] -to $mirrored_x $y [expr $mirrored_x+1] [expr $y+1]
	#	}
	#}
	preview write {output/preview.gif}
	preview_mirrored write {output/preview_mirrored.gif}
}

proc wrong_fumen {m} {
	global tetfu
	set tetfu ""
	tk_messageBox -icon error -message $m
	no_preview
	.common.preset.row2.label config -text "no data"
}

proc paste_fumen {} {
	global tetfu
	if {![catch {clipboard get} contents]} {
		set tetfu [clipboard get]
		set i [string last 115@ $tetfu]
		if { $i == -1} {
			wrong_fumen "Clipboard doesn't contain correct fumen data."
			return
		}
		set tetfu "v[string range $tetfu $i [string length $tetfu]]"
		.common.preset.row2.label config -text "data impoted"
		make_preview
		if {[file exists {output/error.txt}]} {
			wrong_fumen "Clipboard doesn't contain correct fumen data."
		}
	}
}

proc save_preset {} {
	global preset_name
	global preset_old_name
	global tetfu
	global java
	global preview_full_w
	global preview_full_h
	global lines
	global 7za
	set fumen_unrecognized "Imported fumen data can't be processed with this utility. Try to fill the field again and re-import the fumen data."
	if {$preset_name eq ""} {
		tk_messageBox -type ok -icon warning -message "Enter the name of the preset"
		return
	}
	set preset_name [string trim $preset_name]
	regsub -all {[^a-zA-Z 0-9-]} $preset_name "" preset_name
	set preset_name [string range $preset_name 0 40]
	if {$preset_name eq ""} {
		tk_messageBox -type ok -icon warning -message "You can't use this name for a preset. Enter another name"
		return
	}

	if {$tetfu eq ""} {
		tk_messageBox -type ok -icon warning -message "Import the fumen data"
		return
	}
	lock_preset
	make_previews
	
	set error 0
	set out [open "|$java -jar fumen2xlsx.jar -t $tetfu 2>@1" r]
	while {1} {
		fileevent $out readable 
		if {[eof $out]} {
			break
		}
		set log [gets $out]
		.common.log configure -state normal
		.common.log insert end "$log\n"
		.common.log configure -state disabled
		.common.log see end
		if {$log ne ""} {
			set error 1
		}
	}
	if {$error} {
		wrong_fumen $fumen_unrecognized
		unlock_preset
		return
	}

	if {$7za eq ""} {
		set out [open "|./bin/7za.exe x output/output.xlsx -ooutput 2>@1" r]
	} else {
		set out [open "|$7za x output/output.xlsx -ooutput 2>@1" r]
	}
	while {1} {
		fileevent $out readable 
		if {[eof $out]} {
			break
		}
		.common.log configure -state normal
		.common.log insert end "[gets $out]\n"
		.common.log configure -state disabled
		.common.log see end
	}

	if {![file exists {output/xl/worksheets/sheet1.xml}]} {
		wrong_fumen $fumen_unrecognized
		unlock_preset
		return
	}
	set xlsx [open output/xl/worksheets/sheet1.xml r]
	gets $xlsx xlsx_line 
	gets $xlsx xlsx_line 
	close $xlsx

	set m [open output/field_mirrored.txt w]
	set f [open output/field.txt w]
	puts $m $lines
	puts $f $lines
	set l [string length $xlsx_line]
	for {set r 2} {$r <=21} {incr r} {
		foreach c {L K J I H G F E D C} {
			set mino [string last "<c r=\"$c$r\" s=\"" $xlsx_line]
			if {$mino == -1} {
				break
			}
			set mino [string range $xlsx_line $mino $l]
			set end [string first / $mino ]
			incr end -1
			set mino [string range $mino [expr $end-1] $end]
			if { $mino eq {9"}} {
				puts -nonewline $m _
			} elseif {$mino eq {8"}} {
				puts -nonewline $m X
			} else {
				wrong_fumen $fumen_unrecognized
				close $m
				close $f
				unlock_preset
				return
			}
		}
		puts $m ""
	}
	close $m
	set m [open output/field_mirrored.txt r]
	gets $m
	while {1} {
		if {[eof $m]} {
			break
		}
		puts $f [string reverse [gets $m]]
	}
	close $f
	close $m
	file delete -force presets/$preset_name
	file mkdir presets/$preset_name
	file copy output/field.txt presets/$preset_name
	file copy output/field_mirrored.txt presets/$preset_name
	file copy output/preview.gif presets/$preset_name
	file copy output/preview_mirrored.gif presets/$preset_name
	set tetfu_file [open presets/$preset_name/tetfu.txt w]
	puts $tetfu_file $tetfu
	close $tetfu_file
	save_last_preset
	write_options
	if {("" ne $preset_old_name) && ($preset_old_name ne $preset_name)} {
		file delete -force "presets/$preset_old_name"
	}
	unlock_preset
	show_main
}

proc save_last_preset {} {
	global preset_name
	file mkdir presets
	set last [open presets/last.txt w]
	puts $last $preset_name
	close $last
}

proc select_preset {} {
	global preset_name
	global m
	global hold
	global mirror
	global mode
	if {$preset_name eq ""} {
		.common.main.row2.label_frame.row1.go configure -state disabled
		$m.edit entryconfigure "Delete current preset" -state disabled
		no_preview
	} else {

		.common.main.row2.label_frame.row1.go configure -state enabled
		if {[file exists presets/$preset_name/last.txt]} {
			set last [open presets/$preset_name/last.txt r]
			gets $last hold
			gets $last mirror
			gets $last mode
			close $last
		} else {
			set hold 1
			set mirror 0
			set mode path
		}
		if {![info exists hold]} {
			set hold 1
		}
		if {![info exists mirror]} {
			set miror 0
		}
		if {![info exists mode]} {
			set mode path
		}
		if {$hold eq "1"} {
		} elseif {$hold eq "0"} {
		} else {
			set hold 1
		}
		if {$mirror eq "0"} {
		} elseif {$mirror eq "1"} {
		} else {
			set mirror 1
		}
		if {$mode eq "path"} {
		} elseif {$mode eq "percent -fc 0"} {
		} else {
			set mode path
		}
		$m.edit entryconfigure "Delete current preset" -state active
		show_preview
	}
	save_last_preset
}

proc show_preview {} {
	global preset_name
	global mirror
	if {$preset_name ne ""} {
		if {$mirror} {
			image create photo preview -file "presets/$preset_name/preview_mirrored.gif"
		} else {
			image create photo preview -file "presets/$preset_name/preview.gif"
		}
		.common.preview create image 2 2 -image preview -anchor nw
	} else {
		no_preview
	}
}

proc find_presets {} {
	global preset_name
	global m
	set preset_name ""
	if {![catch { set presets [glob -directory presets -type d *]} err ] } {
		foreach f $presets {
			set f  [string range $f 8 [string length $f]]
			lappend l $f
		}
		$m.file entryconfigure "Export current preset" -state active
		$m.edit entryconfigure "Copy current preset" -state active
		$m.edit entryconfigure "Edit current preset" -state active
		$m.edit entryconfigure "Delete current preset" -state active
	} else {
		set l ""
		$m.file entryconfigure "Export current preset" -state disabled
		$m.edit entryconfigure "Copy current preset" -state disabled
		$m.edit entryconfigure "Edit current preset" -state disabled
		$m.edit entryconfigure "Delete current preset" -state disabled
	}
	.common.main.row0.combo configure -values [lsort -ascii $l]
	if {[file exists presets/last.txt]} {
		set last [open presets/last.txt r]
		gets $last preset_name
		close $last
	}
	if {![file exists "presets/$preset_name"] } {
		set preset_name [lindex [lsort -ascii $l] 0]
	}
	select_preset
}

proc delete_preset {} {
	global preset_name
	if { yes eq [tk_messageBox -icon question -type yesno -message "Are you sure you want to delete \"$preset_name\"?"]} {
		file delete -force "presets/$preset_name"
		find_presets
	}
}

proc lock_main {} {
	global preset_name
	global m
	grid .common.main.progress
	bind . <Return> {stop}
	.common.main.row0.combo configure -state disabled
	.common.main.row1.mirror_check configure -state disabled
	.common.main.row1.hold_check configure -state disabled
	foreach w [winfo children .common.main.row1.label_frame] {$w configure -state disabled}
	foreach w [winfo children .common.main.row2.label_frame.row0] {
		if {($w eq ".common.main.row2.label_frame.row0.help") || 
			($w eq ".common.main.row2.label_frame.row0.none")} {
			continue
		}
		$w configure -state disabled
	}
	.common.main.row2.label_frame.row1.clear configure -state disabled
	.common.main.row2.label_frame.row1.queue configure -state disabled
	.common.main.row2.label_frame.row1.go configure -text "Stop" -command stop
	$m.file entryconfigure "Export current preset" -state disabled
	$m.file entryconfigure "Import preset" -state disabled
	$m.edit entryconfigure "Temporary preset" -state disabled
	$m.edit entryconfigure "Add new preset" -state disabled
	$m.edit entryconfigure "Copy current preset" -state disabled
	$m.edit entryconfigure "Edit current preset" -state disabled
	$m.edit entryconfigure "Delete current preset" -state disabled
	$m.edit entryconfigure "Options" -state disabled
}

proc unlock_main {} {
	global m
	grid remove .common.main.progress
	#bind . <Return> {if {$queue ne "" } { go}}
	toggle_minimal
	.common.main.row0.combo configure -state readonly
	.common.main.row1.mirror_check configure -state enabled
	.common.main.row1.hold_check configure -state enabled
	foreach w [winfo children .common.main.row1.label_frame] {$w configure -state enabled}
	foreach w [winfo children .common.main.row2.label_frame.row0] {
		if {($w eq ".common.main.row2.label_frame.row0.help") || 
			($w eq ".common.main.row2.label_frame.row0.none")} {
			continue
		}
		$w configure -state enabled
	}
	.common.main.row2.label_frame.row1.clear configure -state enabled
	.common.main.row2.label_frame.row1.queue configure -state enabled
	.common.main.row2.label_frame.row1.go configure -text "Go" -command go
	$m.file entryconfigure "Export current preset" -state active
	$m.file entryconfigure "Import preset" -state active
	$m.edit entryconfigure "Temporary preset" -state active
	$m.edit entryconfigure "Add new preset" -state active
	$m.edit entryconfigure "Copy current preset" -state active
	$m.edit entryconfigure "Edit current preset" -state active
	$m.edit entryconfigure "Delete current preset" -state active
	$m.edit entryconfigure "Options" -state active
	find_presets;# reconfigures menuitems availability; might be unnecessary here
}

proc stop {} {
	global tid
	#puts stop
	if {$tid eq 0} {
		#puts "tid=$tid, exiting"
		return
	}
	set pid [tsv::get shared pid]
	if {$pid eq 0} {
		#puts "pid=$pid, exiting"
		return
	}
	#puts "killing thread tid=$tid backend with pid=$pid"
	set kill [list {*}[auto_execok taskkill]] ;# windows
	if {$kill eq ""} {
		set kill [list {*}[auto_execok kill]];# linux 
		catch {exec $kill -9 $pid} err
	} else {
		catch {exec $kill /F /PID $pid} err
	}
}

proc go {} {
	global preset_name
	global queue
	global hold
	global mode
	global java
	global java_exec
	global mirror
	global fumen_url
	global tid
	global scrolling
	global auto_clear
	if {$preset_name eq ""} {
		return
	}
	if {$queue eq ""} {
		tk_messageBox -icon error -message "An empty queue found. If you don't want to search an explicit pattern it might be enough to add some bags \"*!\" to the queue, but not more than needed because it will significally increase the working time."
		return
	}
	tsv::set shared hold $hold
	tsv::set shared mode $mode
	tsv::set shared mirror $mirror
	tsv::set shared preset_name $preset_name
	tsv::set shared queue $queue
	tsv::set shared pid 0
	lock_main
	set tid [thread::create { thread::wait }]
	thread::send -async $tid {
		if {[tsv::get shared mirror]} {
			set fp "presets/[tsv::get shared preset_name]/field_mirrored.txt"
		} else {
			set fp "presets/[tsv::get shared preset_name]/field.txt"
		}
		if {[tsv::get shared hold]} {
			set out [open "|[tsv::get shared java] -jar sfinder.jar [tsv::get shared mode] -fp \"$fp\" --patterns \"[tsv::get shared queue]\" 2>@1" r]
		} else {
			set out [open "|[tsv::get shared java] -jar sfinder.jar [tsv::get shared mode] -fp \"$fp\" --patterns \"[tsv::get shared queue]\" --hold avoid 2>@1" r]
		}
		fconfigure $out -blocking 1
		catch { tsv::set shared pid [pid $out] } err ;# pit $out can fail
		while {1} {
			fileevent $out readable 
			if {[eof $out]} {
				catch {close $out} err;# killed java closes this automatically
				break
			}
			tsv::lappend log lines [gets $out]
		}
		tsv::set shared pid 0
	} result
	set scrolling -1
	after 1 update_log
	vwait result
	thread::release -wait $tid
	set tid 0
	after 1 update_log;# there might be a remainder 
	if {[file exists output/path_minimal.html]} {
		set html [open output/path_minimal.html r]
		fconfigure $html -encoding utf-8
		set html_new [open path_minimal.html w]
		gets $html line
		regsub -all {http://fumen\.zui\.jp/} $line "$fumen_url" line
		regsub {ライン消去なし} $line "Without line erasing" line
		regsub {ライン消去あり} $line "With line erasing" line
		puts $html_new $line
		close $html
		close $html_new
		update_first
	}
	if {$auto_clear} {
		set queue ""
	}
	unlock_main
}

proc update_log {} {
	global tid
	global scrolling
	#puts [tsv::llength log lines]
	while {[tsv::llength log lines]} {
		set line "[tsv::lpop log lines]\n"
		if {![string first "# Output" $line]} {
			set scrolling 9
		}
		.common.log configure -state normal
		.common.log insert end $line 
		.common.log configure -state disabled
		if {$scrolling <0} {
			.common.log see end
		} elseif {$scrolling >0} {
			incr scrolling -1
			.common.log see end
		}
	}
	if {$tid ne 0} {
		after 1 update_log
	}
}

proc save_preset_state {} {
	global hold
	global mirror
	global mode
	global preset_name
	if {![file exists presets/$preset_name]} {
		return
	}
	set last [open presets/$preset_name/last.txt w]
	puts $last $hold
	puts $last $mirror
	puts $last $mode
	close $last
}

proc toggle_mirror {} {
	show_preview
	save_preset_state
}

proc import {} {
	global 7za
	set types {
	    {{7-zip archives} {.7z}}
	}
	set filename [ tk_getOpenFile -filetypes $types]
	if {$filename eq ""} {
		return
	}
	file delete -force output
	if {$7za eq ""} {
		set out [open "|./bin/7za.exe x \"$filename\" -ooutput 2>@1" r]
	} else {
		set out [open "|$7za x \"$filename\" -ooutput 2>@1" r]
	}
	while {1} {
		fileevent $out readable 
		if {[eof $out]} {
			break
		}
		.common.log configure -state normal
		.common.log insert end "[gets $out]\n"
		.common.log configure -state disabled
		.common.log see end
	}
	global preset_name
	global lines
	global tetfu
	.common.preset.row0.entry configure -state enabled
	set chan [open output/tetfu.txt r]
	gets $chan tetfu
	close $chan
	set chan [open output/field.txt r]
	gets $chan lines
	close $chan
	set preset_name [string range [file tail $filename] 0 end-3]
	show_preset
	.common.preset.row2.label config -text "data impoted"
	make_preview 
	set preset_old_name ""
}

proc export {} {
	global preset_name
	global 7za
	if {$preset_name eq "" } {
		return
	}
	set dir [tk_chooseDirectory -mustexist 1]
	if {$dir eq ""} {
		return
	}
	cd "./presets/$preset_name/"
	if {$7za eq ""} {
		set out [open "|../../bin/7za.exe a \"$dir/$preset_name.7z\" *" r]
	} else {
		set out [open "|$7za a \"$dir/$preset_name.7z\" *" r]
	}
	while {1} {
		fileevent $out readable 
		if {[eof $out]} {
			break
		}
		.common.log configure -state normal
		.common.log insert end "[gets $out]\n"
		.common.log configure -state disabled
		.common.log see end
	}
	cd "../../"
}

proc update_first {} {
	global fumen_url
	global first_url
	if {[file exists path_minimal.html]} {
		set html [open path_minimal.html r]
		gets $html line
		close $html
		if {[regsub {^.*<h2>} $line "" line] && 
			[regsub {^.*<a href='} $line "" line] && 
			[regsub {'>.*$} $line "" line]&&
			([string compare -length [string length $fumen_url] $fumen_url $line] == 0)} {
			set first_url $line
			.common.main.open_first configure -state enabled
		} else {
			set first_url ""
			.common.main.open_first configure -state disabled
		}
	}
}

proc open_first {} {
	global first_url
	if {$first_url ne "" } {
		invokeBrowser $first_url
	} else {
		invokeBrowser path_minimal.html
	}
}

######## starting GUI here
if {$java eq ""} {
	if { [tk_messageBox -type okcancel -icon error -message "Java is not installed on this PC. Press OK to proceed to the java website for installation."] eq "ok" } {
		invokeBrowser "$java_website"
	}
	exit
}

show_main
