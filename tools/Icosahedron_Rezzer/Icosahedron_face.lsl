
    //  Icosahedron face

    integer commandChannel = 666;
    integer commandH;

    key whoDat;

    integer vertex = 0;         // Vertex number

    //  processCommand  --  Process command from local chat or dialogue

    integer processCommand(key id, string message) {
        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments

//      integer argn = llGetListLength(args);       // Number of arguments
        string command = llList2String(args, 0);    // The command
//      string sparam = llList2String(args, 1);     // First parameter for convenience

        whoDat = id;                                // Direct chat output to sender of command

        if (vertex != 0) {

            if (command == "delete") {
                llRemoveInventory(llGetScriptName());
            } else if (command == "die") {
                llDie();
            } else if (command == "point") {
                vector target = llGetRootPosition();
                vector me = llList2Vector(llGetLinkPrimitiveParams(LINK_THIS, [ PRIM_POSITION ]), 0);
                vector nvec = llVecNorm(target - me);

                //  Compute angle to tilt around X to point at root's Z
                float xang = llSin(nvec.z);

                //  Compute angle to rotate about Z to point at root
                float zang = llAtan2(nvec.y, nvec.x);
                rotation zrot = llEuler2Rot(<0, 0, zang>);
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_ROTATION, llAxisAngle2Rot(<1, 0, 0>, xang) * zrot ]);
            } else if (command == "spin") {
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_OMEGA,
                      < llFrand(1), llFrand(1), llFrand(1) >, PI / 2, 1 ]);
             } else if (command == "stop") {
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_OMEGA, ZERO_VECTOR, 0, 0 ]);
                llSetLinkPrimitiveParamsFast(LINK_THIS,
                    [ PRIM_ROTATION, ZERO_ROTATION ]);
            }
        }

        return TRUE;
    }

    default {
        on_rez(integer start_param) {
            vertex = start_param;
        }

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message);
        }
        state_entry() {
            if (vertex > 0) {
                string pname = "Face";
                pname +=  " " + (string) (vertex % 100);
                llSetLinkPrimitiveParamsFast(LINK_THIS, [ PRIM_NAME, pname ]);
            }
            commandH = llListen(commandChannel, "", NULL_KEY, ""); // Listen on command chat channel
        }
    }
