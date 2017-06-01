## -*- tcl -*-
## (c) 2017 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc new-store {} {
    atom::memory create test-atom
    [test-class] create test-store test-atom
    return
}

proc release-store {} {
    test-store destroy
    test-atom destroy
    return
}

# # ## ### ##### ######## ############# #####################
return
