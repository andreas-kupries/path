## -*- tcl -*-
## (c) 2017 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc store-class {} { lindex [split [test-class] /] 0 }

proc new-store {} {
    atom::memory create test-atom
    path::memory create test-backend test-atom
    [store-class] create test-store test-backend
    return
}

proc release-store {} {
    catch { test-store   destroy }
    catch { test-backend destroy }
    catch { test-atom    destroy }
    return
}

# # ## ### ##### ######## ############# #####################
return
