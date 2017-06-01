# -*- tcl -*-
## (c) 2017-2016 Andreas Kupries
# # ## ### ##### ######## ############# #####################
## sqlite based path storage i.e. path internement.
## Note, this does not use in-memory caching.
## If that is wanted see the cacher class.

# @@ Meta Begin
# Package path::sqlite 1
# Meta author      {Andreas Kupries}
# Meta category    Path internment, database
# Meta description Path interning via Sqlite database
# Meta location    http:/core.tcl.tk/akupries/path
# Meta platform    tcl
# Meta require     {Tcl 8.5-}
# Meta require     TclOO
# Meta require     path
# Meta require     debug
# Meta require     debug::caller
# Meta require     dbutil
# Meta require     sqlite3
# Meta subject     {Path internment} interning
# Meta summary     Path interning via Sqlite database
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require TclOO
package require path
package require dbutil
package require sqlite3
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################

debug define path/sqlite
debug level  path/sqlite
debug prefix path/sqlite {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Implementation

oo::class create path::sqlite {
    superclass path

    # # ## ### ##### ######## #############
    ## State

    variable mytable sql_toid sql_torid sql_topath sql_known sql_extend \
	sql_eroot sql_map sql_rmap sql_clear sql_size sql_serialin sql_serialnn
    # Name of the database table used for interning,
    # plus the sql commands to access it.

    # # ## ### ##### ######## #############
    ## Lifecycle.

    constructor {atomstore database table} {
	debug.path/sqlite {}
	# Make the database available as a local command, under a
	# fixed name. No need for an instance variable and resolution.

	set fqn  [uplevel 1 [list namespace which -command $database]]
	set nc   [namespace current]
	interp alias {} ${nc}::DB {} $fqn

	my InitializeSchema $table

	next $atomstore
	return
    }

    # # ## ### ##### ######## #############
    ## API. Implementation of inherited virtual methods.

    # Encode: parent-path-id, segment-atom-id --> integer
    # intern segment under the parent, return its unique identifier
    method Encode {parent segment} {
	debug.path/sqlite {}
	if {$parent eq {}} {
	    DB transaction {
		if {[DB exists $sql_torid]} {
		    return [DB onecolumn $sql_torid]
		}
		variable size
		if {[info exists size]} { incr size }
		DB eval $sql_eroot
		return [DB last_insert_rowid]
	    }
	} else {
	    DB transaction {
		if {[DB exists $sql_toid]} {
		    return [DB onecolumn $sql_toid]
		}
		variable size
		if {[info exists size]} { incr size }
		DB eval $sql_extend
		return [DB last_insert_rowid]
	    }
	}
    }

    # Decode: path-id --> (parent-path-id, segment-atom-id)
    # map numeric identifier to (parent, segment) tuple
    method Decode {id} {
	debug.path/sqlite {}
	DB transaction {
	    if {![DB exists $sql_topath]} {
		my Error "Expected path id, got \"$id\"" BAD ID $id
	    }
	    return [DB eval $sql_topath]
	}
    }

    # names () -> list(string)
    # query set of interned strings.
    method names {} {
	debug.path/sqlite {}

	# Optimize this. As is it is this algorithm runs in O(n**2),
	# having to decode all partial parent paths multiple times.

	set names {}
	DB eval $sql_known {
	    lappend names [my path $id]
	}
	return $names
    }

    # Has: parent-path-id, segmnt-atom-id, nextvar -> boolean
    # Test if path by parent, segment tuple exists or not. If found id
    # is returned through nextvar.
    method Has {parent segment nextvar} {
	debug.path/sqlite {}
	upvar 1 $nextvar next
	if {$parent eq {}} {
	    DB transaction {
		if {![DB exists $sql_torid]} {
		    return 0
		}
		set next [DB onecolumn $sql_torid]
		return 1
	    }
	} else {
	    DB transaction {
		if {![DB exists $sql_toid]} {
		    return 0
		}
		set next [DB onecolumn $sql_toid]
		return 1
	    }
	}
    }

    # exists-id: id -> boolean
    # query if id is known/interned
    method exists-id {id} {
	debug.path/sqlite {}
	DB transaction {
	    DB exists $sql_topath
	}
    }

    # serialize: () -> dict ((path-id segment-name) -> identifier)
    method serialize {} {
	debug.path/sqlite {}
	set serial {}
	DB eval $sql_serialin {
	    lappend serial [list $parent [Atom str $name]] $id
	}
	DB eval $sql_serialnn {
	    lappend serial [list $parent [Atom str $name]] $id
	}

	return $serial
    }

    # size () -> integer
    method size {} {
	debug.path/sqlite {}
	variable size
	if {[info exists size]} { return $size }
	DB transaction {
	    set size [DB eval $sql_size]
	}
	# implied return
    }

    # Map: path, parent-path-id, segment-atom-id, path-id -> ()
    # Force map a single segment for a known parent path
    method Map {path parent segment id} {
	debug.path/sqlite {}
	DB transaction {
	    if {($parent eq {}) && [DB exists $sql_torid]} {
		set knownid [DB onecolumn $sql_torid]
		if {$knownid != $id} {
		    # mapped, id mismatch
		    my MAPerror path $path $knownid $id
		} else {
		    # already mapped, ignore
		    return
		}
	    } elseif {($parent ne {}) && [DB exists $sql_toid]} {
		set knownid [DB onecolumn $sql_toid]
		if {$knownid != $id} {
		    # mapped, id mismatch
		    my MAPerror path $path $knownid $id
		} else {
		    # already mapped, ignore
		    return
		}
	    } elseif {[DB exists $sql_topath]} {
		set knownstr [DB eval $sql_topath]
		if {$knownstr ne [list $parent $segment]} {
		    # mapped, string mismatch
		    my MAPerror id $id [my path $id] $path
		} else {
		    # already mapped, ignore
		    return
		}
	    }
	    # unknown mapping, no conflicts, enter.
	    variable size
	    if {[info exists size]} { incr size }
	    if {$parent eq {}} {
		DB eval $sql_rmap
	    } else {
		DB eval $sql_map
	    }
	}
	return
    }

    # clear () -> ()
    # Remove all known mappings.
    method clear {} {
	debug.path/sqlite {}
	variable size ; unset -nocomplain size
	DB transaction {
	    DB eval $sql_clear
	}
	return
    }

    # # ## ### ##### ######## #############
    ## API. Standard methods. Reimplemented to place all low-level
    ## operations into transactions, reducing amount of disk access.

    # # ## ### ##### ######## #############
    ## Internals

    method InitializeSchema {table} {
	debug.path/sqlite {}
	lappend map <<table>> $table

	set fqndb [self namespace]::DB

	set schema [string map $map {
	      id     INTEGER PRIMARY KEY AUTOINCREMENT
	    , parent INTEGER REFERENCES <<table>> (id)
	    , name   INTEGER NOT NULL -- atom reference
	    , UNIQUE (parent, name)
	}]
	if {![dbutil initialize-schema $fqndb reason $table [list $schema {
	    {id     INTEGER 0 {} 1}
	    {parent INTEGER 1 {} 0}
	    {name   INTEGER 1 {} 0}
	}]]} {
	    my Error $reason BAD SCHEMA
	}

	# Generate the custom sql commands.
	my Def sql_extend   { INSERT              INTO "<<table>>" VALUES (NULL, :parent, :segment) }
	my Def sql_eroot    { INSERT              INTO "<<table>>" VALUES (NULL, NULL,    :segment) }
	my Def sql_map      { INSERT              INTO "<<table>>" VALUES (:id,  :parent, :segment) }
	my Def sql_rmap     { INSERT              INTO "<<table>>" VALUES (:id,  NULL,    :segment) }
	my Def sql_clear    { DELETE              FROM "<<table>>" }
	my Def sql_toid     { SELECT id           FROM "<<table>>" WHERE parent = :parent AND name = :segment }
	my Def sql_torid    { SELECT id           FROM "<<table>>" WHERE parent ISNULL AND name = :segment }
	my Def sql_topath   { SELECT parent, name FROM "<<table>>" WHERE id     = :id }
	my Def sql_size     { SELECT count(*)     FROM "<<table>>" }
	my Def sql_known    { SELECT id           FROM "<<table>>" }
	my Def sql_serialin {
	    SELECT parent, name, id
	    FROM   "<<table>>"
	    WHERE  parent ISNULL
	    ORDER BY name ASC
	}
	my Def sql_serialnn {
	    SELECT parent, name, id
	    FROM   "<<table>>"
	    WHERE  parent NOTNULL
	    ORDER BY parent, name ASC
	}
	return
    }

    method Def {var sql} {
	debug.path/sqlite {}
	upvar 1 map map
	set $var [string map $map $sql]
	return
    }

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
package provide path::sqlite 1
return
