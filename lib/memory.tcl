# -*- tcl -*-
## (c) 2017-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## In-memory path storage i.e. path internment.

# @@ Meta Begin
# Package path::memory 1
# Meta author      {Andreas Kupries}
# Meta category    Path internment, database
# Meta description Path interning in memory
# Meta location    http:/core.tcl.tk/akupries/path
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     path
# Meta require     debug
# Meta require     debug::caller
# Meta subject     {path internment} interning
# Meta summary     Path interning in memory
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require path
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define path/memory
debug level  path/memory
debug prefix path/memory {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create path::memory {
    superclass path

    # # ## ### ##### ######## #############
    ## State

    ## To ensure proper interning, i.e. path compression we internally
    ## represent a path as a pair of parent id and the name of its
    ## last segment. The latter further encoded as an atom.

    variable mypath myid
    # let
    #   mypath: dict (id -> path_pair)
    #   myid:   dict (path_pair -> id)
    # where
    #   path_pair = (parent-id, name-id)

    # # ## ### ##### ######## #############
    ## Lifecycle. Generic is enough

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Encode: parent-path-id, segment-atom-id --> integer
    # intern segment under the parent, return its unique identifier
    method Encode {parent segment} {
	debug.path/memory {}
	set key [list $parent $segment]
	if {![dict exists $myid $key]} {
	    set id [dict size $myid]
	    # Avoid conflicts with existing mappings. Such can occur
	    # for deserialized mappings which have holes.
	    while {[dict exists $mypath $id]} {incr id}
	    # Inlined 'map' without checks.
	    dict set myid   $key $id
	    dict set mypath $id $key
	    debug.path/memory {New   ($parent [Atom str $segment] => $id}
	    return $id
	}
	debug.path/memory {Cache ($parent [Atom str $segment] => [dict get $myid $key]}
	return [dict get $myid $key]
    }

    # Decode: path-id --> (parent-path-id, segment-atom-id)
    # map numeric identifier to (parent, segment) tuple
    method Decode {id} {
	debug.path/memory {}
	if {![dict exists $mypath $id]} {
	    my Error "Expected path id, got \"$id\"" BAD ID $id
	}
	return [dict get $mypath $id]
    }

    # names () -> list(path)
    # query set of interned paths.
    method names {} {
	debug.path/memory {}

	# Optimize this. As is it is this algorithm runs in O(n**2),
	# having to decode all partial parent paths multiple times.

	set names {}
	dict for {id _} $mypath {
	    lappend names [my path $id]
	}
	return $names
    }

    # Has: parent-path-id, segmnt-atom-id, nextvar -> boolean
    # Test if path by parent, segment tuple exists or not. If found id
    # is returned through nextvar.
    method Has {parent segment nextvar} {
	debug.path/memory {}
	upvar 1 $nextvar next
	set key [list $parent $segment]
	if {![dict exists $myid $key]} {
	    return 0
	}
	set next [dict get $myid $key]
	return 1
    }

    # exists-id: path-id -> boolean
    # query if the path-id is known/interned
    method exists-id {id} {
	debug.path/memory {}
	return [dict exists $mypath $id]
    }

    # serialize: () -> dict ((path-id segment-name) -> identifier)
    method serialize {} {
	debug.path/memory {}
	# Convert the segment atom ids back to strings.

	# Using two loops and sorting ensures that parent paths are
	# listed before their children. This is based on the fact that
	# parent paths are encoded before their children and thus
	# having numerically smaller ids then them. See method
	# "id-from" and how it iterates over the segments of a path.
	#
	# Two loops because root parent references are the empty
	# string and are normally sorted after numbers. Easier to
	# handle them first and exclude i nthe main loop over creating
	# a special sort command.
	set serial {}
	foreach key [lsort -dict [dict keys $myid [list {} *]]] {
	    lassign $key parent segment
	    lappend serial [list $parent [Atom str $segment]] [dict get $myid $key]
	}
	foreach key [lsort -dict [dict keys $myid]] {
	    lassign $key parent segment
	    if {$parent eq {}} continue ;# Already handled
	    lappend serial [list $parent [Atom str $segment]] [dict get $myid $key]
	}

	debug.path/memory {==> ($serial)}
	return $serial
    }

    # size () -> integer
    method size {} {
	debug.path/memory {}
	dict size $myid
    }

    # Map: path, parent-path-id, segment-atom-id, path-id -> ()
    # Force map a single segment for a known parent path
    method Map {path parent segment id} {
	debug.path/memory {}
	set key [list $parent $segment]

	# Check for conflicts with existing id or path.
	if {[dict exists $myid $key] &&
	    ([set knownid [dict get $myid $key]] != $id)} {
	    my MAPerror path $path $knownid $id
	}
	if {[dict exists $mypath $id] &&
	    ([set knownstr [dict get $mypath $id]] ne $key)} {
	    my MAPerror id $id [my path $id] $path
	}

	# No conflicts, save (like 'Encode')
	dict set myid   $key $id
	dict set mypath $id $key
	return
    }

    # clear () -> ()
    # Remove all known mappings.
    method clear {} {
	debug.path/memory {}
	set mypath {}
	set myid   {}
	return
    }

    # # ## ### ##### ######## #############
    ## API. Standard methods. Reimplementation possible
    ##      for efficiency. Plus alternate names.

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide path::memory 1
return
