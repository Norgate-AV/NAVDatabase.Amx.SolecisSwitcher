MODULE_NAME='mSolecisSwitcher'      (
                                        dev vdvObject,
                                        dev dvPort
                                    )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE    = 1

constant integer MAX_LEVELS = 3
constant char LEVELS[][NAV_MAX_CHARS]    = { 'ALL',
                        'VID',
                        'AUD' }

constant char LEVEL_BYTES[][NAV_MAX_CHARS]    = { 'ALL',
                    'VIDEO',
                    'AUDIO' }

constant integer MAX_OUTPUTS = 16

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long ltDrive[] = { 200 }

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iModuleEnabled

volatile integer iCommandBusy

volatile integer iOutput[MAX_LEVELS][MAX_OUTPUTS]
volatile integer iPending[MAX_LEVELS][MAX_OUTPUTS]

volatile integer iID = 1

volatile integer iVideoMuteState
volatile integer iAudioMuteState

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendStringRaw(char cParam[]) {
     NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cParam))
    send_command dvPort,"cParam"
    wait 1 iCommandBusy = false
}

define_function BuildString(integer iIn, integer iOut, integer iLevel) {
    switch (LEVELS[iLevel]) {
    case 'ALL': {
        SendStringRaw("'CI',itoa(iIn),'O',itoa(iOut)")
    }
    case 'VID': {
        SendStringRaw("'VI',itoa(iIn),'O',itoa(iOut)")
    }
    case 'AUD': {
        SendStringRaw("'AI',itoa(iIn),'O',itoa(iOut)")
    }
    }
}

define_function Drive() {
    stack_var integer x
    stack_var integer i
    if (!iCommandBusy) {
    for (x = 1; x <= MAX_OUTPUTS; x++) {
        for (i = 1; i <= MAX_LEVELS; i++) {
        if (iPending[i][x] && !iCommandBusy) {
            iPending[i][x] = false
            iCommandBusy = true
            BuildString(iOutput[i][x],x,i)
        }
        }
    }
    }
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START
// create_buffer dvPort,cRxBuffer

iModuleEnabled = true

// Update event tables
rebuild_event()
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvPort] {
    online: {
    if (iModuleEnabled) {
        timeline_create(TL_DRIVE,ltDrive,length_array(ltDrive),TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
    }

    NAVCommand(data.device,'?VIDOUT_MUTE')
    NAVCommand(data.device,'?AUDOUT_MUTE')
    NAVCommand(data.device,'VIDIN_AUTO_SELECT-DISABLE')
    NAVCommand(data.device,'AUDOUT_MUTE-DISABLE')
    }
    string: {
    if (iModuleEnabled) {
        [vdvObject,DEVICE_COMMUNICATING] = true
        [vdvObject,DATA_INITIALIZED] = true
        //TimeOut()
         NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, dvPort, data.text))
        //if (!iSemaphore) { Process() }
    }
    }
    command: {
    stack_var char cCmdHeader[NAV_MAX_CHARS]
    stack_var char cCmdParam[3][NAV_MAX_CHARS]
    //[vdvObject,DEVICE_COMMUNICATING] = true
    //[vdvObject,DATA_INITIALIZED] = true
    cCmdHeader = DuetParseCmdHeader(data.text)
    cCmdParam[1] = DuetParseCmdParam(data.text)
    cCmdParam[2] = DuetParseCmdParam(data.text)
    cCmdParam[3] = DuetParseCmdParam(data.text)
    switch (cCmdHeader) {
        case 'VIDOUT_MUTE': {
        switch (cCmdParam[1]) {
            case 'ENABLE': {
            iVideoMuteState = true
            }
            case 'DISABLE': {
            iVideoMuteState = false
            }
        }
        }
        case 'AUDOUT_MUTE': {
        switch (cCmdParam[1]) {
            case 'ENABLE': {
            iAudioMuteState = true
            }
            case 'DISABLE': {
            iAudioMuteState = false
            }
        }
        }
    }
    }
}

data_event[vdvObject] {
    online: {
    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Solecis Switcher'")
    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.amx.com'")
    NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,AMX'")
    }
    command: {
    stack_var char cCmdHeader[NAV_MAX_CHARS]
    stack_var char cCmdParam[3][NAV_MAX_CHARS]
    if (iModuleEnabled) {
        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)
        cCmdParam[3] = DuetParseCmdParam(data.text)
        switch (cCmdHeader) {
        case 'PROPERTY': {
            switch (cCmdParam[1]) {
            case 'IP_ADDRESS': {
                //cIPAddress = cCmdParam[2]
                //timeline_create(TL_IP_CHECK,ltIPCheck,length_array(ltIPCheck),timeline_absolute,timeline_repeat)
            }
            case 'ID': {
                iID = atoi(cCmdParam[2])
            }
            }
        }
        case 'PASSTHRU': { SendStringRaw(cCmdParam[1]) }

        case 'SWITCH': {
            stack_var integer iLevel
            iLevel = NAVFindInArrayString(LEVELS,cCmdParam[3])
            if (!iLevel) { iLevel = 1 }
            iOutput[iLevel][atoi(cCmdParam[2])] = atoi(cCmdParam[1])
            iPending[iLevel][atoi(cCmdParam[2])] = true
        }
        }
    }
    }
}

timeline_event[TL_DRIVE] { Drive() }

channel_event[vdvObject,0] {
    on: {
    switch (channel.channel) {
        case PIC_MUTE: {
        if (iVideoMuteState) {
            NAVCommand(dvPort,'VIDOUT_MUTE-DISABLE')
            wait 5 NAVCommand(dvPort,'?VIDOUT_MUTE')
        }else {
            NAVCommand(dvPort,'VIDOUT_MUTE-ENABLE')
            wait 5 NAVCommand(dvPort,'?VIDOUT_MUTE')
        }
        }
        case VOL_MUTE_ON: {
        SendStringRaw('AUDOUT_MUTE-ENABLE')
        wait 5 NAVCommand(dvPort,'?AUDOUT_MUTE')
        }
    }
    //Place holder so get_last works...
    }
    off: {
    switch (channel.channel) {
        case VOL_MUTE_ON: {
        SendStringRaw('AUDOUT_MUTE-DISABLE')
        wait 5 NAVCommand(dvPort,'?AUDOUT_MUTE')
        }
    }
    }
}

(***********************************************************)
(*            THE ACTUAL PROGRAM GOES BELOW                *)
(***********************************************************)
DEFINE_PROGRAM {
    [vdvObject,PIC_MUTE_FB]    = (iVideoMuteState)
    [vdvObject,VOL_MUTE_FB]    = (iAudioMuteState)
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
