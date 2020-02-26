    /*
                    Fourmilab Polychrome

        Drop this script into any prim or link set and it will randomly
        and smoothly change colour.  The colour changes on every tick
        between and old colour and the randomly chosen new colour.
        After changeTicks, a new random colour is selected and the
        previous target colour becomes the starting point for the next
        transition.

        The script listens to Nearby Chat on the channel defined by
        commandChannel below.

        This program is licensed under a Creative Commons
        Attribution-ShareAlike 4.0 International License.
            http://creativecommons.org/licenses/by-sa/4.0/
        Please see the License section in the "Fourmilab Polychrome"
        notecard included in the object for details.
    */

    /*  Configuration parameters.  You can configure the script
        directly by changing these parameters here, or set them
        via chat commands of an initialisation notecard.  */

    integer commandChannel = 432;           // Command channel in chat
    integer restrictAccess = 2;             // Access restriction: 0 none, 1 group, 2 owner

    integer polyFace = TRUE;                // Change each face independently ?
    integer polyLink = TRUE;                // Colour each link separately ?
    integer attached = FALSE;               // Require attachment to an avatar ?

    /*  List of faces to exclude as ("x", link, face) triples.  If
        the object is a simple prim (as opposed to a link set), the
        link number should be specified as 0.  */
    list exclude = [ ];

    integer run = FALSE;                    // Do we automatically start when loaded ?
    integer echo = TRUE;                    // Echo commands to sender ?
    float tickLength = 0.25;                // Time between ticks, seconds
    float changeTime = 25;                  // Time between new colour target selection, seconds

    vector colourMin = < 0, 0, 0 >;         // Colour minimum in selected space
    vector colourMax = < 1, 1, 1 >;         // Colour maximum in selected space
    integer HSV = FALSE;                    // Choose colour in the HSV colour space ?

    integer bcChannel = -982449718;         // Broadcast channel
    integer broadcast = FALSE;              // Broadcast colour changes ?
    integer bcreceive = FALSE;              // Receive broadcast changes ?

    /*  End configuration parameters.  You shouldn't have to
        change anything that follows.  */

    integer commandH;                       // Handle for command channel

    key owner;                              // Owner of parent object
    key whoDat = NULL_KEY;                  // User to whom we're talking

    integer configuring;                    // Processing configuration script ?
    integer ready = FALSE;                  // Are we ready to process timer ticks ?

    integer changeTicks;                    // Choose new colour after this many ticks
    integer ticks = 0;                      // Tick counter

    integer multiLink;                      // Multi-prim link set ?
    integer colours;                        // Number of distinct colours
    integer prims;                          // Number of prims in link set

    list lastCol = [ ];                     // List of start colours
    list newCol = [ ];                      // List of end colours

    /*  faceList is a list of link numbers and faces upon
        which we will operate.  The list consists of triples
        of integers representing:
            link        Link number if in a link set, or LINK_THIS
                        for a simple prim
            face        Face number, or ALL_SIDES if all are to be
                        coloured the same
            index       Index into the colour arrays used for this entry
    */
    list faceList = [ ];

    /*  We save the original alphas for all faces so we can
        preserve alpha when we change the colour.  This
        avoids having to make an API call for every colour
        change just to get the alpha.  */
    list faceAlphas = [ ];

    //  Configuration script name
    string configScript = "Fourmilab Polychrome Configuration";

    //  Help file name
    string helpFile = "Fourmilab Polychrome User Guide";

    //  Script processing

    string ncSource = "";           // Current notecard being read
    key ncQuery;                    // Handle for notecard query
    integer ncLine = 0;             // Current line in notecard
    integer ncBusy = FALSE;         // Are we reading a notecard ?
    list ncQueue = [ ];             // Queue of pending notecards to read

    //  Broadcasting

    integer broadcastH;             // Handle for listening to broadcasts

    //  tawk  --  Send a message to the interacting user in chat

    tawk(string msg) {
        if (whoDat == NULL_KEY) {
            //  No known sender.  Say in nearby chat.
            llSay(PUBLIC_CHANNEL, msg);
        } else {
            if (whoDat == owner) {
                llOwnerSay(msg);
            } else {
                llRegionSayTo(whoDat, PUBLIC_CHANNEL, msg);
            }
        }
    }

    /*  hsv_to_rgb  --  Convert HSV colour values stored in a vector
                        (H = x, S = y, V = z) to RGB (R = x, G = y, B = z).
                        The Hue is specified as a number from 0 to 1
                        representing the colour wheel angle from 0 to 360
                        degrees, while saturation and value are given as
                        numbers from 0 to 1.  */

    vector hsv_to_rgb(vector hsv) {
        float h = hsv.x;
        float s = hsv.y;
        float v = hsv.z;

        if (s == 0) {
            return < v, v, v >;             // Grey scale
        }

        if (h >= 1) {
            h = 0;
        }
        h *= 6;
        integer i = (integer) llFloor(h);
        float f = h - i;
        float p = v * (1 - s);
        float q = v * (1 - (s * f));
        float t = v * (1 - (s * (1 - f)));
        if (i == 0) {
            return < v, t, p >;
        } else if (i == 1) {
            return < q, v, p >;
        } else if (i == 2) {
            return <p, v, t >;
        } else if (i == 3) {
            return < p, q, v >;
        } else if (i == 4) {
            return < t, p, v >;
        } else if (i == 5) {
            return < v, p, q >;
        }
llOwnerSay("Blooie!  " + (string) hsv);
        return < 0, 0, 0 >;
    }

    //  chooseColour  --  Choose the next target colour

    vector chooseColour() {
        vector crange = colourMax - colourMin;
        vector colour = colourMin +
                            < crange.x * llFrand(1),
                              crange.y * llFrand(1),
                              crange.z * llFrand(1) >;
        return colour;
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

    //  checkAccess  --  Check if user has permission to send commands

    integer checkAccess(key id) {
        return (restrictAccess == 0) ||
               ((restrictAccess == 1) && llSameGroup(id)) ||
               (id == owner);
    }

    //  buildColours  --  Build colour tables

    buildColours() {
        lastCol = [ ];
        newCol = [ ];
        faceAlphas = [ ];
        ticks = 0;

        //  Initialise last and new colour arrays

        integer i;
        for (i = 0; i < colours * 3; i += 3) {
            list oCol = llGetLinkPrimitiveParams(
                    llList2Integer(faceList, i),
                    [ PRIM_COLOR,  llList2Integer(faceList, i + 1) ]);
            lastCol += llList2Vector(oCol, 0);
            newCol += llList2Vector(oCol, 0);
        }

        //  Save alphas of all faces we will be modifying.

        for (i = 0; i < llGetListLength(faceList); i += 3) {
            faceAlphas += llList2Float(llGetLinkPrimitiveParams(
                            llList2Integer(faceList, i),
                            [ PRIM_COLOR,  llList2Integer(faceList, i + 1) ]), 1);
        }
    }

    //  buildFaces  --  Build the faceList from the setting and object properties

    buildFaces() {
        colours = 0;
        multiLink = llGetLinkNumber() > 0;  // Are we a link set, or simple prim
        prims = primCount();        //  Number of prims, 1 for a simple prim
        faceList = [ ];             //  Clear the face list

        if (multiLink) {

            //  This is a multi-link set of multiple prims

            integer p;

            if (polyFace) {
                /*  Each face of each link is separately coloured.  If
                    polyFace is set, the setting of polyLink is ignored,
                    since it makes no sense to require every link to have
                    the same colour but allow the faces (of which each prim
                    in the link set may have a different number) to have
                    separate colours.  Consequently, if polyFace is set,
                    the setting of polyLink is silently ignored, even if
                    set to the inane value of TRUE.  */

                for (p = 1; p <= prims; p++) {
                    integer nface = llGetLinkNumberOfSides(p);
                    integer f;

                    for (f = 0; f < nface; f++) {
                        //  Check exclusion list.  If not on list, add to faceList
                        if (llListFindList(exclude, [ "x", p, f ]) < 0) {
                            faceList += [ p, f, colours++ ];
                        }
                    }
                }
            } else {
                /*  We are colouring all faces of each link the same.
                    If there is no exclusion list, we can simply use
                    ALL_SIDES in faceList, but if an exclusion list is
                    present, we must enumerate the faces and add only those
                    not excluded to faceList.  In this case all faces added
                    have the same index into the colour tables.

                    When all faces are coloured the same, the setting
                    of polyLink determines whether individual objects
                    in the link set will be coloured differently (TRUE)
                    or uniformly (FALSE).  */

                for (p = 1; p <= prims; p++) {

                    if (llGetListLength(exclude) == 0) {
                        //  No exclusion list
                        integer findex = colours++;
                        if (!polyLink) {
                            findex = 0;                 // All links have the same colour
                        }
                        faceList += [ p, ALL_SIDES, findex ];
                    } else {
                        integer nface = llGetLinkNumberOfSides(p);
                        integer f;

                        for (f = 0; f < nface; f++) {
                            //  Check exclusion list.  If not on list, add to faceList
                            if (llListFindList(exclude, [ "x", p, f ]) < 0) {
                                integer findex = colours++;
                                if (!polyLink) {
                                    findex = 0;                 // All links have the same colour
                                }
                                faceList += [ p, f, findex ];
                            }
                        }
                    }
                }
            }
        } else {

            //  This is a simple prim

            if (polyFace) {
                /*  Colouring each face separately.  When specifying
                    exclusions by face, use a prim number of 0 in the
                    exclusion list.  */
                integer nface = llGetNumberOfSides();
                integer f;

                for (f = 0; f < nface; f++) {
                    //  Check exclusion list.  If not on list, add to faceList
                    if (llListFindList(exclude, [ "x", 0, f ]) < 0) {
                        faceList += [ LINK_THIS, f, colours++ ];
                    }
                }
            } else {
                /*  We're colouring all faces identically.  If there's
                    no exclusion list, we can simply whack them with
                    a single call with ALL_SIDES.  Otherwise, we
                    generate a list of non-excluded faces, all with
                    the same colour table index.  */
                if (llGetListLength(exclude) == 0) {
                    faceList += [ LINK_THIS, ALL_SIDES, colours++ ];
                } else {
                    integer nface = llGetNumberOfSides();
                    integer f;

                    for (f = 0; f < nface; f++) {
                        //  Check exclusion list.  If not on list, add to faceList
                        if (llListFindList(exclude, [ "x", 0, f ]) < 0) {
                            faceList += [ LINK_THIS, f, colours ];
                        }
                    }
                    colours++;
                }
            }
        }

        buildColours();                 // Rebuild colour tables
    }

    //  flashFace  --  Flash a face to visually identify it

    flashFace(integer link, integer face) {
        list ocol = llGetLinkPrimitiveParams(link, [ PRIM_COLOR, face ]);
        vector ocorgb = llList2Vector(ocol, 0);
        llSetLinkPrimitiveParamsFast(link, [ PRIM_COLOR, face, < 1, 1, 1 >, 1 ]);
        llSleep(0.25);
        llSetLinkPrimitiveParamsFast(link, [ PRIM_COLOR, face, < 0, 0, 0 >, 1 ]);
        llSleep(0.25);
        llSetLinkPrimitiveParamsFast(link, [ PRIM_COLOR, face, < 1, 1, 1 >, 1 ]);
        llSleep(0.25);
        llSetLinkPrimitiveParamsFast(link, [ PRIM_COLOR, face, ocorgb, llList2Integer(ocol, 1) ]);
    }

    //  abbrP  --  Test if string matches abbreviation

    integer abbrP(string str, string abbr) {
        return abbr == llGetSubString(str, 0, llStringLength(abbr) - 1);
    }

    //  onOff  --  Parse an on/off parameter

    integer onOff(string param) {
        if (abbrP(param, "on")) {
            return TRUE;
        } else if (abbrP(param, "of")) {
            return FALSE;
        } else {
            tawk("Error: please specify on or off.");
            return -1;
        }
    }

    //  eOn  --  Edit a Boolean value to "on" or "off"

    string eOn(integer b) {
        if (b) {
            return "on";
        }
        return "off";
    }

    /*  fixArgs  --  Transform command arguments into canonical form.
                     All white space within vector and rotation brackets
                     is elided so they will be parsed as single arguments.  */

    string fixArgs(string cmd) {
        cmd = llToLower(llStringTrim(cmd, STRING_TRIM));
        integer l = llStringLength(cmd);
        integer inbrack = FALSE;
        integer i;
        string fcmd = "";

        for (i = 0; i < l; i++) {
            string c = llGetSubString(cmd, i, i);
            if (inbrack && (c == ">")) {
                inbrack = FALSE;
            }
            if (c == "<") {
                inbrack = TRUE;
            }
            if (!((c == " ") && inbrack)) {
                fcmd += c;
            }
        }
        return fcmd;
    }

    //  scriptName  --  Extract original name from command

    string scriptName(string cmd, string lmessage, string message) {
        integer dindex = llSubStringIndex(lmessage, cmd);
        dindex += llSubStringIndex(llGetSubString(lmessage, dindex, -1), " ");
        return llStringTrim(llGetSubString(message, dindex, -1), STRING_TRIM);
    }

    //  processCommand  --  Process command from local chat or dialogue

    integer processCommand(key id, string message) {

        if (!checkAccess(id)) {
            llRegionSayTo(id, PUBLIC_CHANNEL,
                "You do not have permission to control this object.");
            return FALSE;
        }

        whoDat = id;                                // Direct chat output to sender of command

        integer echoCmd = TRUE;
        if (llGetSubString(llStringTrim(message, STRING_TRIM_HEAD), 0, 0) == "@") {
            echoCmd = FALSE;
            message = llGetSubString(llStringTrim(message, STRING_TRIM_HEAD), 1, -1);
        }
        string lmessage = fixArgs(message);
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments

        if (echo && echoCmd) {
            string prefix = ">> ";
            if (ncBusy) {
                prefix = "++ ";
            }
            tawk(prefix + message);                 // Echo command to sender
        }

        integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command
        string sparam = llList2String(args, 1);     // First parameter for convenience

        //  Echo text                   Send text to sender

        if (abbrP(command, "ec")) {
            tawk(scriptName("ec", lmessage, message));

        //  Flash face [link]           Flash a face to identify it

        } else if (abbrP(command, "fl")) {
            integer face = (integer) sparam;
            integer link = LINK_THIS;
            if (argn >= 3) {
                link = (integer) llList2String(args, 2);
            }
            flashFace(link, face);

        //  Help                            Give requester the User Guide notecard

        } else if (abbrP(command, "he")) {
            if (llGetInventoryKey(helpFile) == NULL_KEY) {
                tawk("Help notecard \"" + helpFile + "\" not installed in this object.");
                return FALSE;
            }
            llGiveInventory(whoDat, helpFile);

        //  List [flash]                    List links and faces, optionally flash

        } else if (abbrP(command, "li")) {
            integer flash = FALSE;
            if (abbrP(sparam, "fl")) {
                flash = TRUE;
            }
            if (multiLink) {
                tawk("Prims: " + (string) prims + "  Colours: " + (string) colours +
                     "  Attached: " + (string) llGetAttached());
                integer p;

                for (p = 1; p <= prims; p++) {
                    integer fc = llGetLinkNumberOfSides(p);
                    integer f;
                    tawk("Link " + (string) p);
                    for (f = 0; f < fc; f++) {
                        list fcol = llGetLinkPrimitiveParams(p, [ PRIM_COLOR, f ]);
                        tawk("  " + (string) f + ".  " + (string) llList2Vector(fcol, 0) +
                            "  " + (string) llList2Float(fcol, 1));
                        if (flash) {
                            integer i;

                            for (i = 0; i < 3; i++) {
                                flashFace(p, f);
                            }
                            llSleep(1);
                        }
                    }
                }
            } else {
                integer fc = llGetNumberOfSides();
                integer f;

                for (f = 0; f < fc; f++) {
                    list fcol = llGetLinkPrimitiveParams(LINK_THIS, [ PRIM_COLOR, f ]);
                    tawk((string) f + ".  " + (string) llList2Vector(fcol, 0) +
                        "  " + (string) llList2Integer(fcol, 1));
                    if (flash) {
                        integer i;

                        for (i = 0; i < 3; i++) {
                            flashFace(LINK_THIS, f);
                        }
                        llSleep(1);
                    }
                }
            }

        //  Reset                       Reset to initial state

        } else if (abbrP(command, "re")) {
            llResetScript();

        //  Run scrname                 Run script from notecard

        } else if (abbrP(command, "ru")) {
            processNotecardCommands(scriptName("ru", lmessage, message), whoDat);

        //  Set                         Set parameter

        } else if (abbrP(command, "se")) {
            string param = llList2String(args, 1);
            string svalue = llList2String(args, 2);

            //  Set Access owner/group/public   Restrict chat command access to public/group/owner

            if (abbrP(param, "ac")) {
                if (abbrP(svalue, "p")) {           // Public
                    restrictAccess = 0;
                } else if (abbrP(svalue, "g")) {    // Group
                    restrictAccess = 1;
                } else if (abbrP(svalue, "o")) {    // Owner
                    restrictAccess = 2;
                } else {
                    tawk("Invalid access.  Valid: owner, group, public.");
                    return FALSE;
                }

            //  Set Broadcast send/receive/channel n

            } else if (abbrP(param, "br")) {
                if (abbrP(svalue, "ch")) {          // Channel n
                    bcChannel = (integer) llList2String(args, 3);
                } else if (abbrP(svalue, "re")) {   // Receive
                    integer oldbcr = bcreceive;
                    bcreceive = onOff(llList2String(args, 3));
                    if (oldbcr && (!bcreceive)) {
                        llListenRemove(broadcastH);
                    }
                    if (bcreceive && (!oldbcr)) {
                        broadcastH = llListen(bcChannel, "", "", "");
//tawk("Listening for broadcasts on " + (string) bcChannel);
                    }
                } else if (abbrP(svalue, "se")) {   // Send
                    broadcast = onOff(llList2String(args, 3));
                } else {
                    tawk("Error: set broadcast send/receive/channel n");
                    return FALSE;
                }
                if (broadcast && bcreceive) {
                    tawk("Error: cannot broadcast send and receive at the same time.  Both disabled.");
                    if (bcreceive) {
                        llListenRemove(broadcastH);
                    }
                    broadcast = bcreceive = FALSE;
                    return FALSE;
                }
                if ((broadcast || bcreceive) && (polyLink || polyFace)) {
                    tawk("Warning: broadcast only works with poly link and face both off.");
                }

            /*  Set Channel n                   Change command channel.  Note that
                                                the channel change is lost on a
                                                script reset.  */

            } else if (abbrP(param, "ch")) {
                integer newch = (integer) svalue;
                if ((newch < 2)) {
                    tawk("Invalid channel number.  Must be 2 or greater.");
                    return FALSE;
                } else {
                    llListenRemove(commandH);
                    commandChannel = newch;
                    commandH = llListen(commandChannel, "", NULL_KEY, "");
                    tawk("Listening on /" + (string) commandChannel + ".");
                }

            /*  Set Colour min/max <c1, c2, c3> Set colour min or max value
                           rgb/hsv              Set colour system  */

            } else if (abbrP(param, "co")) {
                if (abbrP(svalue, "mi")) {
                    colourMin = (vector) llList2String(args, 3);
                } else if (abbrP(svalue, "ma")) {
                    colourMax = (vector) llList2String(args, 3);
                } else if (abbrP(svalue, "hs")) {
                    HSV = TRUE;
                } else if (abbrP(svalue, "rg")) {
                    HSV = FALSE;
                } else {
                    tawk("Error: use Set colour min/max <v1, v2, v3> or HSV/RGB");
                    return FALSE;
                }

            //  Set Echo on/off                 Control echoing of commands

            } else if (abbrP(param, "ec")) {
                integer b = onOff(svalue);
                if (b >= 0) {
                    echo = b;
                }

            //  Set Exclude link face ...       Specify links and faces to exclude

            } else if (abbrP(param, "ex")) {
                integer i;

                if ((argn & 1) || (argn < 4)) {
                    tawk("Error: must specify one or more link, face pairs.");
                    return FALSE;
                }

                list exl = [ ];
                for (i = 2; i < argn; i += 2) {
                    integer elink = (integer) llList2String(args, i);
                    integer eface = (integer) llList2String(args, i + 1);
                    if (multiLink) {
                        if ((elink < 1) || (elink > prims)) {
                            tawk("Link number " + (string) elink +
                                " out of range.  Must be 1 to " + (string) prims);
                            return FALSE;
                        }
                        integer fc = llGetLinkNumberOfSides(elink);
                        if ((eface < 0) || (eface >= fc)) {
                            tawk("Face number " + (string) eface +
                                " for link " + (string) elink +
                                " out of range.  Must be 0 to " + (string) (fc - 1));
                            return FALSE;
                        }
                    } else {
                        if (elink = 0) {
                            tawk("Link number must be 0 for simple prim.");
                            return FALSE;
                        }
                        integer fc = llGetNumberOfSides();
                        if ((eface < 0) || (eface >= fc)) {
                            tawk("Face number " + (string) eface +
                                " out of range.  Must be 0 to " + (string) (fc - 1));
                            return FALSE;
                        }
                    }
                    exl += [ "x", elink, eface ];
                }
                exclude = exl;
                buildFaces();

            //  Set Faces link face index ...       Explicitly set face list

            } else if (abbrP(param, "fa")) {
                integer i;

                if ((((argn - 2) % 3) != 0) || (argn < 5)) {
                    tawk("Error: must specify one or more link, face, index triples.");
                    return FALSE;
                }

                list fl = [ ];
                integer mindex = -1;

                for (i = 2; i < argn; i += 3) {
                    integer elink = LINK_THIS;
                    if (!abbrP(llList2String(args, i), "l")) {
                        elink = (integer) llList2String(args, i);
                    }
                    integer eface = ALL_SIDES;
                    if (!abbrP(llList2String(args, i + 1), "a")) {
                        eface = (integer) llList2String(args, i + 1);
                    }
                    integer eindex = (integer) llList2String(args, i + 2);
                    if (eindex < 0) {
                        tawk("Invalid colour index " + (string) eindex + ".  Must be >= 0.");
                        return FALSE;
                    }
                    if (eindex > mindex) {
                        mindex = eindex;
                    }
                    if (multiLink) {
                        if ((elink < 1) || (elink > prims)) {
                            tawk("Link number " + (string) elink +
                                " out of range.  Must be 1 to " + (string) prims);
                            return FALSE;
                        }
                        integer fc = llGetLinkNumberOfSides(elink);
                        if ((eface != ALL_SIDES) && ((eface < 0) || (eface >= fc))) {
                            tawk("Face number " + (string) eface +
                                " for link " + (string) elink +
                                " out of range.  Must be ALL_SIDES (-1) or 0 to " + (string) (fc - 1));
                            return FALSE;
                        }
                    } else {
                        if (elink == 0) {
                            elink = LINK_THIS;          // For compatibility with exclude list
                        }
                        if (elink != LINK_THIS) {
                            tawk("Link number must be LINK_THIS (-4) for simple prim.");
                            return FALSE;
                        }
                        integer fc = llGetNumberOfSides();
                        if ((eface != ALL_SIDES) && ((eface < 0) || (eface >= fc))) {
                            tawk("Face number " + (string) eface +
                                " out of range.  Must be ALL_SIDES (-1) or 0 to " + (string) (fc - 1));
                            return FALSE;
                        }
                    }
                    fl += [ elink, eface, eindex ];
                }
//tawk(llList2CSV(fl));
                faceList = fl;
                colours = mindex + 1;
                buildColours();

            //  Set Poly face/link on/off       Set multiple colours by face and/or link

            } else if (abbrP(param, "po")) {
                if (abbrP(svalue, "fa")) {
                    integer b = onOff(llList2String(args, 3));
                    if (b >= 0) {
                        polyFace = b;
                    }
                    buildFaces();
                } else if (abbrP(svalue, "li")) {
                    integer b = onOff(llList2String(args, 3));
                    if (b >= 0) {
                        polyLink = b;
                    }
                    buildFaces();
                } else {
                    tawk("Error: use Set poly face/link on/off");
                    return FALSE;
                }

            //  Set Run on/off                  Start or stop colour changing

            } else if (abbrP(param, "ru")) {
                integer b = onOff(svalue);
                if (b >= 0) {
                    if (b != run) {
                        run = b;
                        float t = 0;
                        if (run) {
                            t = tickLength;
                            buildFaces();
                        }
                        if (ready) {
                            llSetTimerEvent(t);
                        }
                    }
                }

            //  Set Time tick/change t          Set tick and colour change interval, seconds

            } else if (abbrP(param, "ti")) {
                float t = (float) llList2String(args, 3);
                if (t > 0) {
                    if (abbrP(svalue, "ch")) {
                        changeTime = t;
                    } else if (abbrP(svalue, "ti")) {
                        tickLength = t;
                    }
                    changeTicks = (integer) llRound(changeTime / tickLength);
                    if (ready && run) {
                        ticks = 0;
                        llSetTimerEvent(tickLength);
                    }
                } else {
                    tawk("Invalid time specification.");
                    return FALSE;
                }
            } else {
                tawk("Unknown variable.  Valid: access, channel, TBD.");
                return FALSE;
            }

        //  Stat                        Print current status

        } else if (abbrP(command, "st")) {
            tawk("multiLink: " + eOn(multiLink) +
                 "  prims: " + (string) prims + "  colours: " + (string) colours);
            tawk("polyLink: " + eOn(polyLink) + "  polyFace: " + eOn(polyFace));
            tawk("exclude: " + llList2CSV(exclude));
            tawk("faceList: " + llList2CSV(faceList));
            tawk("faceAlphas: " + llList2CSV(faceAlphas));
            tawk("run: " + eOn(run) +
                 "  tickLength: " + (string) tickLength +
                 "  changeTime: " + (string) changeTime +
                 "  changeTicks: " + (string) changeTicks);
            tawk("Broadcast:  Send: "+ eOn(broadcast) +
                 "  Receive: " + eOn(bcreceive) +
                 "  Channel: " + (string) bcChannel);

            tawk("HSV: " + eOn(HSV) + "  colourMin: " + (string) colourMin +
                 "  colourMax: " + (string) colourMax);

            integer mFree = llGetFreeMemory();
            integer mUsed = llGetUsedMemory();
            tawk("Script memory.  Free: " + (string) mFree +
                  "  Used: " + (string) mUsed + " (" +
                  (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)");


//  ZZFIX  Unmangle wrecked excluded faces

        } else if (command == "zzfix") {
            integer i;

            for (i = 0; i < llGetListLength(faceList); i += 3) {
                integer prim = llList2Integer(faceList, i);
                integer face = llList2Integer(faceList, i + 1);
                llSetLinkPrimitiveParamsFast(prim,
                    [ PRIM_COLOR, face, <1, 1, 1>, 1 ]);
            }

        } else {
            tawk("Huh?  \"" + message + "\" undefined.");
            return FALSE;
        }
        return TRUE;
    }

    //  Initialise / reset notecard processing

    processNotecardInit() {
        ncSource = "";                  // No current notecard
        ncBusy = FALSE;                 // Mark no notecard being read
        ncQueue = [ ];                  // Queue of pending notecards
    }

    //  processNotecardCommands  --  Read and execute commands from a notecard

    processNotecardCommands(string ncname, key id) {
        ncSource = ncname;
        whoDat = id;
        if (llGetInventoryKey(ncSource) == NULL_KEY) {
            tawk("No notecard named " + ncSource);
            return;
        }
        if (ncBusy) {
            ncQueue += ncname;
        } else {
            ncLine = 0;
            ncBusy = TRUE;          // Mark busy reading notecard
            ncQuery = llGetNotecardLine(ncSource, ncLine);
        }
    }

   default {
        on_rez(integer start_param) {
//llOwnerSay("on_rez()");
        }

        state_entry() {
            ready = FALSE;
            llSetTimerEvent(0);
//llOwnerSay("state_entry()");
            owner =  llGetOwner();

            processNotecardInit();

            buildFaces();

            //  If a configuration script is present, run it
            if (configuring = (llGetInventoryKey(configScript) != NULL_KEY)) {
                processNotecardCommands(configScript, owner);
            }

            llOwnerSay("Listening on /" + (string) commandChannel);
            commandH = llListen(commandChannel, "", NULL_KEY, ""); // Listen on command chat channel

            if (!configuring) {
                ready = TRUE;
                changeTicks = (integer) llRound(changeTime / tickLength);
                if ((run = ((!attached) || (llGetAttached() != 0)))) {
                    //  Only change colour if attached to an avatar
                    llSetTimerEvent(tickLength);
                }
            }
        }

        /*  The listen event receives commands from local chat and,
            if we're listening to broadcast colour tables, colour
            table updates on the broadcast channel.  Upon receiving
            a colour table update, we plug the values into lastCol
            and newCol and reset the tick counter so the timer()
            update will be synchronised to the broadcasting prim.  */

        listen(integer channel, string name, key id, string message) {
            if (channel == bcChannel) {
                list m = llCSV2List(message);
                integer rf = llList2Integer(m, 0);          // Faces in colour table
//llOwnerSay("Rcv: " + message + "  rf " + (string) rf);
                integer i;

                /*  Walk through our colour table and plug in the received
                    values.  If we have more entries than we received, fill
                    in the extra entries with the first colour received.  If
                    we have few colours than received, ignore the additional
                    ones.  */
                for (i = 0; i < colours; i++) {
                    integer mi = i;
                    if (mi >= rf) {
                        mi = 0;
                    }
                    lastCol = llListReplaceList(lastCol,
                        [ (vector) llList2String(m, mi + 1) ], i, i);
                    newCol = llListReplaceList(newCol,
                        [ (vector) llList2String(m, mi + rf + 1) ], i, i);
                }
                tickLength = llList2Float(m, (rf * 2) + 1);
                changeTicks = llList2Integer(m, (rf * 2) + 2);
                HSV = llList2Integer(m, (rf * 2) + 3);
//llOwnerSay("Set  lastCol " + (string) lastCol + "  newCol " + (string) newCol + "  tickLength " + (string) tickLength + "  changeTicks " + (string) changeTicks + "  HSV " + (string) HSV);
                ticks = 0;
            } else {
                processCommand(id, message);
            }
        }

        timer() {
            integer i;

            if (--ticks < 0) {
                ticks = changeTicks;

                /*  Unless we're obtaining our colour tables from a
                    broadcast by another attached prim, generate the
                    new colour tables.  */

                if (!bcreceive) {
                    //  Set last colour to current colour, generate new colour for each face
                    for (i = 0; i < colours; i++) {
                        lastCol = llListReplaceList(lastCol, [ llList2Vector(newCol, i) ], i, i);
                        newCol = llListReplaceList(newCol, [ chooseColour() ], i, i);
                    }

                    /*  If broadcast is enabled, send the last and next colour
                        tables to listeners.  */

                    if (broadcast && (!polyLink) && (!polyFace)) {
                        llRegionSayTo(owner, bcChannel,
                            llList2CSV( [ colours ] + lastCol + newCol + [ tickLength, changeTicks, HSV ]));
                    }
                }
            }
            float oldfrac = ((float) ticks) / changeTicks;
            float newfrac = 1 - oldfrac;

            /*  Prepare the current colour list by interpolating
                between lastCol and newCol based on the fraction
                of time elapsed between selection of the next
                target colour for each index.  */

            list curCol;

            for (i = 0; i < colours; i++) {
                vector ncol = (llList2Vector(lastCol, i) * oldfrac) +
                              (llList2Vector(newCol, i) * newfrac);
                if (HSV) {
                    ncol = hsv_to_rgb(ncol);
                }
                curCol += ncol;
            }

            /*  Walk through faceList and apply the specified colour
                index to each prim and face.  */

            integer f;
            integer nf = llGetListLength(faceList);

            for (f = 0; f < nf; f += 3) {
                integer prim = llList2Integer(faceList, f);
                integer face = llList2Integer(faceList, f + 1);
                integer colidx = llList2Integer(faceList, f + 2);
                llSetLinkPrimitiveParamsFast(prim,
                    [ PRIM_COLOR, face, llList2Vector(curCol, colidx),
                      llList2Float(faceAlphas, f / 3) ]);
            }
        }

        //  The dataserver event receives lines from the notecard we're reading

        dataserver(key query_id, string data) {
            if (query_id == ncQuery) {
                if (data == EOF) {
                    if (llGetListLength(ncQueue) > 0) {
                        //  This script is done.  Pop to outer script.
                        ncSource = llList2String(ncQueue, 0);
                        ncQueue = llDeleteSubList(ncQueue, 0, 0);
                        ncLine = 0;
                        ncQuery = llGetNotecardLine(ncSource, ncLine);
                    } else {
                        //  Finished top level script.  We're done/
                        ncBusy = FALSE;         // Mark notecard input idle
                        ncSource = "";
                        ncLine = 0;
                        if (configuring) {
                            configuring = FALSE;
                            ready = TRUE;
                            changeTicks = (integer) llRound(changeTime / tickLength);
                            if ((run = ((!attached) || (llGetAttached() != 0)))) {
                                //  Only change colour if attached to an avatar
                                llSetTimerEvent(tickLength);
                            }
                        }
                    }
                } else {
                    string s = llStringTrim(data, STRING_TRIM);
                    //  Ignore comments and send valid commands to client
                    integer valid = TRUE;
                    if ((llStringLength(s) > 0) && (llGetSubString(s, 0, 0) != "#")) {
                        valid = processCommand(whoDat, s);
                    }
                    if (valid) {
                        //  Fetch next line from notecard
                        ncQuery = llGetNotecardLine(ncSource, ncLine);
                        ncLine++;
                    } else {
                        //  Error in script: abort notecard input
                        processNotecardInit();
                    }
                }
            }
        }
    }
