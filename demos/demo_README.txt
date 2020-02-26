                        Fourmilab Polychrome

                        Demonstration Objects

Three sample objects are supplied with the Fourmilab Polychrome script
to illustrate its operation and a variety of configurations.  All of these
objects contain the standard Fourmilab Polychrome script and a
"Fourmilab Polychrome Configuration" notecard which configures the
script appropriately for each object.  All of these objects and their
contents are full permissions and may be used and modified as you
wish.  Each object is built from fundamental prims (no mesh) and thus
has a land impact which is given in the object's description.  Note that
the Polychrome script itself has no land impact: adding it to any object
does not increase the object's land impact.

Cube Demo

This is a simple cube prim (land impact 1) with its Polychrome script
configured to color the cube's 6 faces independently.  The cube's
Polychrome script responds to commands on chat channel 903, so you
can, for example, change the script to colour all faces uniformly with:
    /903 set poly face off
and restore independent colouring of faces with:
    /903 set poly face on
A separate "Spinner" script listens on chat channel 904 and can make
the cube rotate locally to better show its faces or remain stationary with
the commands:
    /904 spin
    /904 stop

Icosahedron Demo

This object is a stellated regular icosahedron (a 20-sided regular polyhedron
in which each triangular face is is replaced by a tetrahedron).  The object is
built from 20 tetrahedron prims and one spherical "hub" prim hidden in the
centre which contains the scripts and notecards.  All of these prims are
linked together with the hub as the root prim.  The link set thus has a land
impact of 21.  The Polychrome script listens to commands on local chat
channel 901 and you can, for example, colour the entire object uniformly
with:
    /901 set poly face off
    /901 set poly link off
colour each tetrahedron independently but with all of its faces coloured the
same with:
    /901 set poly face off
    /901 set poly link on
or colour all of the faces independently with:
    /901 set poly face on
    /901 set poly link on
A "Spinner" script in the hub listens on chat channel 902 and can either locally
spin the object or fix it in position with the commands:
    /902 spin
    /902 stop

Multi-Cube Demo

This object is a linked set consisting of 13 cube prims linked in a set 
with the root prim a central cube containing the Polychrome script and 
its configuration notecard.  Twelve child prims are linked to the hub, 
arranged at the vertices of a regular icosahedron.  The linked object 
has a land impact of 13.  As with the Icosahedron Demo you can control 
the colouring of the cubes and faces with commands to the Polychrome 
script, which listens on chat channel /905.  To colour the entire 
object uniformly, use:
    /905 set poly face off
    /905 set poly link off
To colour each tetrahedron independently but with all of its faces 
coloured the same select:
    /905 set poly face off
    /905 set poly link on
Or you can colour all of the faces independently with:
    /905 set poly face on
    /905 set poly link on
A "Spinner" script in the hub listens on chat channel 907 and can either locally
spin the object or fix it in position with the commands:
    /907 spin
    /907 stop
In addition, each of the 12 cubes at the vertices has its own Spinner script
which all listen on chat channel 906 and can make the individual cubes spin
or stop with:
    /906 spin
    /906 stop
