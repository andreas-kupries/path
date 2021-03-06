## -*- tcl -*-
## (c) 2017 Andreas Kupries
# # ## ### ##### ######## ############# #####################

proc store-class {} { lindex [split [test-class] /] 0 }

proc new-store {} {
    sqlite3              test-database [file normalize _path_[pid]_]
    atom::sqlite  create test-atom               test-database atom
    path::sqlite  create test-backend  test-atom test-database path
    [store-class] create test-store    test-backend
    return
}

proc release-store {} {
    catch { test-store    destroy }
    catch { test-backend  destroy }
    catch { test-atom     destroy }
    catch { test-database close   }
    file delete [file normalize _path_[pid]_]
    return
}

# # ## ### ##### ######## ############# #####################
return
