[subsection {Changes for version 1}]

This is the first release of [vset PROJECT].
The changes therefore describe the initial features of the system.

[para] In detail:

[list_begin enumerated]
[comment {- - -- --- ----- -------- ------------- ---------------------}]

[enum] [vset PROJECT] requires Tcl 8.5 or higher.
       Tcl 8.4 or less is not supported.

[enum] The project provides a base class declaring the API of path
       interning classes, and three implementations of that API.

[enum] The provided implementations store paths in an sqlite database,
       or in memory. One of the in-memory classes is written to be a
       front-end cache for any other path interning class following
       the API declared here.

[comment {- - -- --- ----- -------- ------------- ---------------------}]
[list_end]
