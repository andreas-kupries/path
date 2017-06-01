## -*- tcl -*-
## (c) 2017 Andreas Kupries
# # ## ### ##### ######## ############# #####################

## A number of shared test cases have different results, based on the
## internals of identifier generation.  The code here provides the
## setup for the internals of path::sqlite, and compatible.

# # ## ### ##### ######## ############# #####################

# Standard id for the n'th interned string.
# n counting from 1.
proc nth {x} { return $x }

# Memory id fill order, increment
proc map15 {} {
    kt dictsort [PS {
	P {} A 3
	P {} L 1
	P {} S 5
	P {} a 7
	P {} g 8
	P {} s 6
    }]
}

# # ## ### ##### ######## ############# #####################
return
