
    //  Vertex Spinner

    integer commandChannel = 907;
    integer commandH;

    //  processCommand  --  Process command from local chat or dialogue

    integer processCommand(key id, string message) {
        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments

        string command = llList2String(args, 0);    // The command

        llOwnerSay(">> " + message);

        if (command == "spin") {
            llSetLinkPrimitiveParamsFast(LINK_THIS,
                [ PRIM_OMEGA,
                  < llFrand(1), llFrand(1), llFrand(1) >, PI / 4, 1 ]);
         } else if (command == "stop") {
            llSetLinkPrimitiveParamsFast(LINK_THIS,
                [ PRIM_OMEGA, ZERO_VECTOR, 0, 0 ]);
            /*  For non-physical objects, omega rotation is
                performed on the client (viewer) side and does
                not affect the rotation of the prim as seen on
                the server.  Consequently, when it is halted,
                the prim remains in whatever orientation it had
                when stopped.  Resetting the PRIM_ROTATION
                doesn't do anything because as far as the server
                is concerned it wasn't rotated in the firsr
                place.  We have to force the server to tell the
                client to update its display of the prim, which
                we do in two separate ways just to be sure (and
                work around flaky clients): jiggling the server-side
                rotation back and forth and changing the floating
                text (invisibly) above the prim.  This seems to get
                'er done.  */
            llSetLinkPrimitiveParamsFast(LINK_THIS,
                [ PRIM_ROTATION, llEuler2Rot(<PI, 0, 0>) ]);
            llSetText(" ", ZERO_VECTOR, 1);
            llSetText("", ZERO_VECTOR, 0);
            llSetLinkPrimitiveParamsFast(LINK_THIS,
                [ PRIM_ROTATION, ZERO_ROTATION ]);
        } else {
            llOwnerSay("Huh?  Command unknown.  Commands: spin, stop.");
        }

        return TRUE;
    }

    default {
        on_rez(integer start_param) {
        }

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message);
        }
        state_entry() {
            // Listen on command chat channel
            commandH = llListen(commandChannel, "", NULL_KEY, "");
        }
    }
