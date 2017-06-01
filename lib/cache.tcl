# -*- tcl -*-
## (c) 2017-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Cache storage. Internally uses in-memory store.
## Backend store is configurable at construction time).

# @@ Meta Begin
# Package path::cache 1
# Meta author      {Andreas Kupries}
# Meta category    Path internment, database
# Meta description Cache in front of arbitrary path interning backend
# Meta location    http:/core.tcl.tk/akupries/path
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     path
# Meta require     path::memory
# Meta require     debug
# Meta require     debug::caller
# Meta subject     {path internment} interning
# Meta summary     Cache in front of arbitrary path interning backend
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require path
package require path::memory
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define path/cache
debug level  path/cache
debug prefix path/cache {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create path::cache {
    superclass path

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {backend} {
	debug.path/cache {}
	# Make the backend available as a local command, under a fixed
	# name. No need for an instance variable and resolution.
	set fqn  [uplevel 1 [list namespace which -command $backend]]
	interp alias {} [namespace current]::BACKEND {} $fqn

	# The cache itself is also handled as a local command.
	# The required atom store is the same as for the backend
	path::memory create CACHE [BACKEND atom-store]
	CACHE clear
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # id-from: path -> integer
    # intern the path, return its unique numeric identifier
    method id-from {pathid path} {
	debug.path/cache {}
	if {![CACHE exists-from $pathid $path]} {
	    # Using "map" here forces the mapping in the cache to
	    # mirror the mapping by the backend.
	    set id [BACKEND id-from $pathid $path]
	    return [CACHE map [BACKEND path $id] $id]
	} else {
	    return [CACHE id-from $pathid $path ]
	}
    }

    # path: integer -> path
    # map numeric identifier back to its path.
    # check cache first, then backend, lift mapping.
    method path {id} {
	debug.path/cache {}
	if {![CACHE exists-id $id]} {
	    # Using "map" here forces the mapping in the cache to
	    # mirror the mapping by the backend.
	    set path [BACKEND path $id]
	    CACHE map $path $id
	    return $path
	} else {
	    return [CACHE path $id]
	}
    }

    # names () -> list(path)
    # query set of interned paths.
    # backend is authoritative source.
    # cache may not know everything, yet.
    #method names {} { BACKEND names }
    forward names BACKEND names

    # exists: path -> boolean
    # query if path is known/interned
    # check cache first, then the authoritative source.
    method exists-from {pathid path} {
	debug.path/cache {}
	set has [CACHE exists-from $pathid $path]
	if {$has} { return $has }
	return [BACKEND exists-from $pathid $path]
    }

    # exists-id: id -> boolean
    # query if id is known/interned
    # check cache first, then the authoritative source.
    method exists-id {id} {
	debug.path/cache {}
	set has [CACHE exists-id $id]
	if {$has} { return $has }
	return [BACKEND exists-id $id]
    }

    # size () -> integer
    # backend is authoritative source.
    # cache may not know everything, yet.
    #method size {} { BACKEND size }
    forward size BACKEND size

    # map: path, integer -> ()
    # intern the path, force the associated identifier.
    # throws error on conflict with existing path/identifier.
    method map {path id} {
	debug.path/cache {}
	# Works because the cached mapping mirrors the backend (see
	# method [id] above).
	BACKEND map $path $id
	CACHE   map $path $id
	return $id
    }

    # clear () -> ()
    # Remove all known mappings.
    method clear {} {
	debug.path/cache {}
	BACKEND clear
	CACHE   clear
	return
    }

    # # ## ### ##### ######## #############
    ## Cache bypass.

    forward serialize   BACKEND serialize
    forward deserialize BACKEND deserialize
    forward merge       BACKEND merge

    method load {serial} {
	debug.path/cache {}
	CACHE clear
	next $serial
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide path::cache 1
return
