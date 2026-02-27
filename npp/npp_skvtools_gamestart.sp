        <KeyWord name="OnGameplayStart" func="yes">
            <Overload retVal="forward void" descr="
Params:
    stage                   boot sequence number in seconds, max 18.
Notes:
    Triggered when gameplay starts.
    Currently, all Left 4 Dead and Left 4 Dead 2 game modes are supported.
">
                <Param name="int stage"/>
            </Overload>
        </KeyWord>
        <KeyWord name="IsGameplayActive" func="yes">
            <Overload retVal="native bool" descr="
Notes:
    Checks if the game is active.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnMissionLost" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Fires when the mission_lost event occurs.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnRoundEnd" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Fires when the round_end event occurs in non-cooperative modes.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnServerEmpty" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Fires when the last player leaves the server.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnMapTransit" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Fires when the map_transit event occurs.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnMapRestart" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Triggered when the mission restarts.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnMissionChange" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Triggered when the mission changes.
">
            </Overload>
        </KeyWord>
        <KeyWord name="OnEscapeVehicleLeaving" func="yes">
            <Overload retVal="forward void" descr="
Notes:
    Triggered when the rescue vehicle leaves the finale.
">
            </Overload>
        </KeyWord>
        