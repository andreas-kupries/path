## -*- tcl -*-
## (c) 2017 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc already {cmd} {
    return "can't create object \"$cmd\": command already exists with that name"
}

proc badmethod {m real} {
    set real [string map {{, or} { or}} [linsert [join $real {, }] end-1 or]]
    return "unknown method \"$m\": must be $real"
}

# # ## ### ##### ######## ############# #####################
## Assembly of serializations.

proc P {ppid name pid} {
    upvar 1 serial serial
    if {$ppid ne {}} { set ppid [nth $ppid] }
    lappend serial [list $ppid $name] [nth $pid]
    return
}

proc PS {script {predefined {}}} {
    set serial {}
    eval $script

    set tmp {}
    foreach id $predefined { lappend tmp [nth $id] }
    set predefined $tmp
    unset tmp

    return [v_p_s $serial $predefined]
}

# # ## ### ##### ######## ############# #####################
## Standard content

# S-A-B-C :: S A B C   -- 7 paths stored (counting parent/partial)
#   \-R-C :: S A R C
#     \-D :: S A R D

proc STD_FILL {{store test-store}} {
    $store id {S A R C}
    $store id {S A B C}
    $store id {S A R D}
}

proc STD_EXTEND {} {
    PS {
	P {} S 1
	P 1  A 2
	P 2  R 3
	P 3  C 4
	P 4  O 5
	P 5  P 6
	P 6  H 7
	P 7  A 8
	P 8  G 9
    }
}

proc PURE_EXTEND {} {
    PS {
	P 4  O 8
	P 8  P 9
	P 9  H 10
	P 10 A 11
	P 11 G 12
    } 4
}

proc STD_SERIAL {} {
    PS {
	P {} S 1
	P 1  A 2
	P 2  R 3
	P 3  C 4
	P 2  B 5
	P 5  C 6
	P 3  D 7
    }
}

proc EXT_SERIAL {} {
    PS {
	P {} S 1
	P 1  A 2
	P 2  R 3
	P 3  C 4
	P 2  B 5
	P 5  C 6
	P 3  D 7
	# Extension
	P 4  O 8
	P 8  P 9
	P 9  H 10
	P 10 A 11
	P 11 G 12
    }
}

# # ## ### ##### ######## ############# #####################

proc v_p_s {serial {predefined {}}} {
    # Validate Path Serialization
    if {([llength $serial] % 2) == 1} {
	return -code error "Bad serialization, odd length"
    }
    dict set known {} .
    foreach id $predefined { dict set known $id . }
    foreach {key id} $serial {
	lassign $key parent name
	if {![dict exists $known $parent]} {
	    return -code error "Bad serial, parent ($parent) after child (($key) $id) in ($serial)"
	}
	dict set known $id .
    }
    return $serial
}

# # ## ### ##### ######## ############# #####################
return
