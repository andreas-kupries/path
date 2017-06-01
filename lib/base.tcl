# -*- tcl -*-
## (c) 2017-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## Base class for path storage i.e. list(string) internment.
##
## This class declares the API all actual classes have to
## implement. It also provides standard APIs for the
## de(serialization) of path stores.

# @@ Meta Begin
# Package path 1
# Meta author      {Andreas Kupries}
# Meta category    Path internment, database
# Meta description Base class for path interning
# Meta location    http:/core.tcl.tk/akupries/path
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     debug
# Meta require     debug::caller
# Meta subject     {path internment} interning
# Meta summary     Path interning
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define path
debug level  path
debug prefix path {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create path {
    # # ## ### ##### ######## #############
    ## Lifecycle, generic

    constructor {atomstore} {
	debug.path {}

	# Import the store command into the local namespace, for
	# direct and easy access by all methods.
	set fqn  [uplevel 1 [list namespace which -command $atomstore]]
	set nc   [namespace current]
	interp alias {} ${nc}::Atom {} $fqn

	my clear
	return
    }

    method atom-store {} {
	debug.path {}
	return [interp alias {} [namespace current]::Atom]
    }

    # # ## ### ##### ######## #############
    ## API. Virtual methods. Implementation required.

    # Encode: parent-id, segment-atom-id --> path-id
    # intern segment under the parent, return its unique identifier
    method Encode {parentid segmentid} { my APIerror Encode }

    # Decode: path-id --> (parent-id, segment-atom-id)
    # map numeric identifier to (parent, segment) tuple
    method Decode {pathid} { my APIerror Decode }

    # names () -> list(path)
    # query set of interned paths.
    method names {} { my APIerror names }

    # Has: parent-id, segment-atom-id, nextvar -> boolean
    # A variant of 'Encode' which checks and returns existence
    # information.  The path-id is returned through 'nextvar' iff the
    # tuple is already encoded.
    method Has {parentid segmentid nextvar} { my APIerror Has }

    # exists-id: path-id -> boolean
    # query if path-id is for known/interned path
    method exists-id {pathid} { my APIerror exists-id }

    # size () -> integer
    method size {} { my APIerror size }

    # Map: path, parent-id, segment-atom-id, path-id -> ()
    # Force map a single segment for a known parent path to a specific
    # id. Throw an error on conflicts with existing data.
    method Map {path parentid segmentid pathid} { my APIerror Map }

    # clear () -> ()
    # Remove all known mappings.
    method clear {} { my APIerror clear }

    # # ## ### ##### ######## #############
    ## API. Standard methods. Reimplementation possible
    ##      for efficiency. Plus alternate names.

    # id: path -> path-id
    # intern the path, return its unique numeric identifier
    forward id   my id-from  {}
    forward id*  my id-from* {}

    # id-from: (pathid, path) -> pathid
    # intern the path, relative to pathid as the base, return its
    # unique numeric identifier. An empty string as base signals
    # interning relative to root. An error is thrown if the base path
    # is not known.
    method id-from {pathid path} {
	debug.path {}
	my ValidatePath $path
	if {$pathid ne {}} { my ValidatePathId $pathid }
	foreach segmentname $path {
	    set pathid [my Encode $pathid [Atom id $segmentname]]
	}
	return $pathid
    }

    # id-from*: (pathid, ...) -> pathid
    # intern the path, given as separate arguments, relative to pathid
    # as the base, return its unique numeric identifier. An empty
    # string as the base signals interning relative to root.
    method id-from* {pathid args} {
	debug.path {}
	return [my id-from $pathid $args]
    }

    # path: path-id -> path
    # map numeric identifier back to its path.
    method path {id} {
	debug.path {}
	set path {}
	while true {
	    lassign [my Decode $id] parent segment
	    lappend path [Atom str $segment]
	    if {$parent eq {}} break
	    set id $parent
	}
	return [lreverse $path]
    }

    # exists: path -> boolean
    # query if path is known/interned
    #
    # Note: For a path to be interned all its segments must be
    # interned as atoms as well. That makes for a nice pre-check, and
    # ensures that 'exists' will not intern any new atoms either.
    forward exists   my exists-from  {}
    forward exists*  my exists-from* {}

    # See exists, checking relative to pathid as the base path.
    # An error is thrown if the base path is not known.
    method exists-from {pathid path} {
	debug.path {}
	my ValidatePath $path
	if {$pathid ne {}} { my ValidatePathId $pathid }
	foreach segment $path {
	    if {![Atom exists $segment] ||
		![my Has $pathid [Atom id $segment] pathid]
	    } {
		return 0
	    }
	}
	return 1
    }

    # See exists-from, path to check given as separate arguments.
    method exists-from* {pathid args} {
	debug.path {}
	return [my exists-from $pathid $args]
    }

    # map: path, path-id -> ()
    # intern the path, force the associated identifier.
    # throws error on conflict with existing path/identifier.
    # returns id.
    method map {path id} {
	debug.path {}
	if {[llength $path] > 1} {
	    set parent [my id [lrange $path 0 end-1]]
	} else {
	    set parent {}
	}
	set segment [Atom id [lindex $path end]]

	my Map $path $parent $segment $id
	return $id
    }

    forward <-- my deserialize ; export <--
    forward --> my serialize   ; export -->
    forward :=  my load        ; export :=
    forward +=  my merge       ; export +=

    # serialize: () -> dict ((path, segment) -> identifier)
    method serialize {} { my APIerror serialize }

    # Various forms of reading a serialized path storage.

    # deserialize: dict ((pathid, segmentname) -> identifier) -> ()
    method deserialize {serial} {
	debug.path {}
	# This code assumes that the serialization lists parent paths
	# before their children. This ensures that they exist in the
	# store and for "my path ..." to work.
	foreach {key id} $serial {
	    lassign $key pathid segmentname
	    set path [expr {($pathid eq {})
			    ? ""
			    : "[my path $pathid]/"}]$segmentname
	    my Map $path $pathid [Atom id $segmentname] $id
	}
	debug.path {/done}
	return
    }

    # load: dict (path -> identifier) -> ()
    method load {serial} {
	debug.path {}
	my clear
	my deserialize $serial

	debug.path {/done}
	return
    }

    # merge: dict ((pathid, segmentname) -> identifier) -> ()
    method merge {serial} {
	debug.path {}
	# This code assumes that the serialization lists parent paths
	# before their children. This ensures that they exist in the
	# store and for "my Encode" to work, i.e. to be called with the id
	# of an already interned base path. Still, we check.

	# Map from old parent path ids (in the serial) to new ids from
	# Encode. Because whatever is in serial is not necessarily the
	# same after encoding, and without that is mapping child paths
	# may attach to the wrong base.
	set on {}

	foreach {key oldid} $serial {
	    lassign $key pathid segmentname
	    if {$pathid ne {}} {
		set pathid [dict get $on $pathid]
		my ValidatePathId $pathid
	    }
	    dict set on $oldid [my Encode $pathid [Atom id $segmentname]]
	}

	debug.path {/done}
	return
    }

    # # ## ### ##### ######## #############
    ## Internal helpers

    method ValidatePathId {pathid} {
	if {[my exists-id $pathid]} return
	my Error "Expected a path id, got \"$pathid\"" BAD ID
    }

    method ValidatePath {path} {
	if {[llength $path]} return
	my Error "Expected a non-empty path, got \"$path\"" BAD ID
    }

    method Error {text args} {
	debug.path {}
	return -code error -errorcode [list PATH {*}$args] $text
    }

    method APIerror {api} {
	debug.path {}
	my Error "Unimplemented API $api" API MISSING $api
    }

    method MAPerror {what val old new} {
	debug.path {}
	set wx [string toupper $what]
	set wh [string totitle $what]
	my Error "$wh conflict for \"$val\", maps to \"$old\" != \"$new\"" \
	    MAP CONFLICT $wx $val $new $old
    }
}

# # ## ### ##### ######## ############# #####################
package provide path 1
return
