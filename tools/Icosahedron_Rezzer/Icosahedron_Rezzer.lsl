
    //  Icosahedron Rezzer

    float size = 1;                     // Size (radius of circumscribed sphere)
    float faceHeight = 0.5;             // Height of stellated faces

    list vertices = [ ];                // Vertex co-ordinates relative to origin
    list faces = [ ];                   // List of unique faces, defined by vertex triples

    float edge;                         // Length of edges of faces = 1.051146222423
                                        // SL tetrahedron size with edge of 1 unit 1.1648495
                                        // SL tetrahedron for unit face: 1.22442716313

    float EPSILON = 0.0001;             // Tolerance for floating-point round-off

    integer commandChannel = 88;
    integer commandH;

    integer linking = FALSE;            // Are we linking prims ?

    key whoDat;

    //  tawk  --  Talk to owner

    tawk(string s) {
        llOwnerSay(s);
    }

    //  processCommand  --  Process command from local chat or dialogue

    integer processCommand(key id, string message) {
        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments

//      integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command
        string sparam = llList2String(args, 1);     // First parameter for convenience

        whoDat = id;                                // Direct chat output to sender of command

        tawk(">> " + message);

        //  build               Build icosahedron faces

        if (command == "faces") {
            build();

        //  link                Link subsequently-built faces, vertices

        } else if (command == "link") {
            linking = TRUE;
            llRequestPermissions(llGetOwner(), PERMISSION_CHANGE_LINKS);

        //  rot link <x,y,z> angle  Rotate a linked face around an axis

        } else if (command == "rot") {
            integer link = (integer) sparam;
            vector axis = (vector) llList2String(args, 2);
            float angle = ((float) llList2String(args, 3)) * DEG_TO_RAD;
            llSetLinkPrimitiveParamsFast(link,
                [ PRIM_ROT_LOCAL, llAxisAngle2Rot(axis, angle) ]);

        //  stat                Print status

        } else if (command == "stat") {
            integer prims = primCount();
            tawk("Prims: " + (string) prims);

        //  unlink              Unlink the rezzer from the linked faces

        } else if (command == "unlink") {
            llBreakLink(1);                     // Unlink root prim

        //  verts               Place markers at vertices

        } else if (command == "verts") {
            buildV();
        } else {
            tawk("Huh?");
        }

        return TRUE;
    }

    /*  primCount  --  Return the number of prims in the object
                       in which we reside, regardless of whether
                       we're attached or not, and ignoring any
                       seated avatars.  */

    integer primCount() {
        if (llGetAttached()) {
            /*  If we're attached, return number of prims, as
                attachments can't be sat upon.  */
            return llGetNumberOfPrims();
        }
        //  Otherwise, return prim count, ignoring seated avatars
        return llGetObjectPrimCount(llGetKey());
    }

    //  buildV  --  Build the vertex markers

    buildV() {
        integer nv = llGetListLength(vertices);
        integer i;

        for (i = 0; i < nv; i++) {
            llRezObject("Vertex",
                llGetPos() + llList2Vector(vertices, i), ZERO_VECTOR,
                    ZERO_ROTATION, i + 1000);
        }
    }

    //  aeq  --  Test for approximate equality of two floats

    integer aeq(float a, float b) {
        return llFabs(a - b) < EPSILON;
    }

    //  build  --  Build the faces

    build() {
        integer nf = llGetListLength(faces);
        integer f;

        for (f = 0; f < nf; f += 4) {
            integer v1i = llList2Integer(faces, f + 1);
            integer v2i = llList2Integer(faces, f + 2);
            integer v3i = llList2Integer(faces, f + 3);
            vector v1p = llList2Vector(vertices, v1i);
            vector v2p = llList2Vector(vertices, v2i);
            vector v3p = llList2Vector(vertices, v3i);

            //  Face centre
            float fudge = 1.030;
            vector fctr = (v1p + v2p + v3p) / 3;
            fctr = (fctr / size) * (size + (faceHeight / 2)) * fudge;

            float ez;
            float pz;
            if (aeq(v1p.z, v2p.z)) {
                ez = v1p.z;
                pz = v3p.z;
            } else if (aeq(v2p.z, v3p.z)) {
                ez = v2p.z;
                pz = v1p.z;
            } else if (aeq(v3p.z, v1p.z)) {
                ez = v3p.z;
                pz = v2p.z;
            } else {
                tawk("Blooie!!  Face " + (string) (f / 4) + "  " +
                    llList2CSV([ v1p, v2p, v3p ]));
            }
            float pointy = 90;
            if (pz < ez) {
                pointy = -90;
            }

            rotation frot =
                llAxisAngle2Rot(<0, 0, 1>, pointy * DEG_TO_RAD)
                *
                llAxisAngle2Rot(<1, 0, 0>, -llAsin(fctr.z))
                *
                llAxisAngle2Rot(<1, 0, 0>, PI_BY_TWO)
                *
                llAxisAngle2Rot(<0, 0, 1>, PI_BY_TWO)
                *
                llAxisAngle2Rot(<0, 0, 1>, llAtan2(fctr.y, fctr.x))
            ;
//tawk("Face " + (string) (f / 4) + "  " + (string) fctr + "  Frot " + (string) (llRot2Euler(frot) * RAD_TO_DEG));
            llRezObject("Icosahedron face", llGetPos() + fctr, ZERO_VECTOR,
                frot, f + 1000);
        }
    }

    default {
        state_entry() {

            //  Compute length of face edges
            edge = size / llSin(TWO_PI / 5);
//tawk("Edge: " + (string) edge);

            vertices = [ ];
            faces = [ ];

            //  Calculate co-ordinates of vertices

            vertices = [ < 0, 0, size > ];          // North pole
            float lat = llAtan2(1, 2);              // Northern parallel
            integer i;
            integer parity = 0;
            list north = [ ];
            list south = [ ];
            for (i = 0; i < 10; i++) {
                float long = (i * 36) * DEG_TO_RAD;

                vector v = <size, 0, 0>;                    // Point on X axis
                v = v * llAxisAngle2Rot(<0, 1, 0>, -lat);   // Rotate around X axis to latitude
                v = v * llAxisAngle2Rot(<0, 0, 1>, long);   // Rotate around Z axis to longitude
/*
                //  Here's the trig function equivalent if you're
                //  uncomfortable with vectors.
                vector v = < llCos(lat) * llSin(long),
                             llCos(lat) * llCos(long),
                             llSin(lat) >;
*/
                lat = -lat;
                if (parity == 0) {
                    north += v;
                } else {
                    south += v;
                }
                parity = parity ^ 1;
            }
            vertices += north + south + < 0, 0, -size >;

            /*  Now, we descend deep into hackery.  Rather than
                elegantly traverse a graph of faces, we find them
                empirically by enumerating the vertices and
                locating which other vertices are within EPISLON
                of the known length of edges (UNIVAC FORTRAN IV,
                1967: COMPARISON OF EQUALITY BETWEEN NON-INTEGERS
                MAY NOT BE MEANINGFUL).  We then sort the indices
                of vertices composing an edge in ascending order,
                which avoids duplications due to permutations of
                vertex order, and store them in the faces list,
                where we use another dirty trick to allow detection
                of duplicate faces via llListFindList().  */

            integer nv = llGetListLength(vertices);     // We know it's 12, but what the hack
            for (i = 0; i < nv; i++) {
                vector v0 = llList2Vector(vertices, i);
                integer j;
                list v02 = [ i ];
                for (j = 0; j < nv; j++) {
                    if (i != j) {
                        vector vj = llList2Vector(vertices, j);
                        float d = llVecDist(v0, vj);
                        if (aeq(d, edge)) {
                            /*  This vertex is a candidate for a face.  Now
                                we iterate once again over the vertices looking
                                for a third vertex which has the edge distance
                                from both the first and second vertices so
                                far.  If so, enter the face as a candidate.  */
                            integer k;
                            for (k = 0; k < nv; k++) {
                                if ((k != i) && (k != j)) {
                                    vector vk = llList2Vector(vertices, k);

                                    if ((llFabs(llVecDist(v0, vk) - edge) <= EPSILON) &&
                                        ((llFabs(llVecDist(vj, vk) - edge) <= EPSILON))) {
                                        v02 = [ i, j, k ];
                                        v02 = llListSort(v02, 1, TRUE);
                                        v02 = [ "f" ] + v02;
                                        if (llListFindList(faces, v02) < 0) {
                                            faces += v02;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            commandH = llListen(commandChannel, "", NULL_KEY, ""); // Listen on command chat channel
            tawk("Listening on chat /" + (string) commandChannel);
        }

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message);
        }

        run_time_permissions(integer perm) {
            if (perm & PERMISSION_CHANGE_LINKS) {
                tawk("Linking enabled: now build faces and/or verts.");
            } else {
                tawk("Unable to obtain permission to link objects.");
            }
        }

        object_rez(key id) {
//tawk("Rezzed as " + (string) id);
            if (linking) {
                llCreateLink(id, TRUE);
            }
        }
    }
