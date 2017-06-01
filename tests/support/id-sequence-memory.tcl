## -*- tcl -*-
## (c) 2017 Andreas Kupries
# # ## ### ##### ######## ############# #####################

## A number of shared test cases have different results, based on the
## internals of identifier generation.  The code here provides the
## setup for the internals of path::memory, and compatible.

# # ## ### ##### ######## ############# #####################

# Standard id for the n'th interned path.
# n counting from 1.
proc nth {x} { incr x -1 }

# Sqlite id fill order, increment
proc map15 {} {
    kt dictsort [PS {
	P {} A 4
	P {} L 2
	P {} S 6
	P {} a 7
	P {} g 8
	P {} s 5
    }]
}

# # ## ### ##### ######## ############# #####################
return
