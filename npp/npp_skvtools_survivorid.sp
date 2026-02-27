        <KeyWord name="GetSurvivorUserId" func="yes">
            <Overload retVal="native int" descr="
Params:
    survivorid              survivor id.
Notes:
    Returns client index.
Return:
    user id if successful otherwise 0. 
">
                <Param name="int survivorid"/>
            </Overload>
        </KeyWord>
		<KeyWord name="GetSurvivorOfUserId" func="yes">
            <Overload retVal="native int" descr="
Params:
    userid                  user id.
Notes:
    Returns client index.
Return:
    survivor id if successful otherwise 0.
">
                <Param name="int userid"/>
            </Overload>
        </KeyWord>
		<KeyWord name="GetClientSurvivorId" func="yes">
            <Overload retVal="native int" descr="
Params:
    client                  client index.
Notes:
    Returns survivor ID.
Return:
    survivor id if successful otherwise 0.
">
                <Param name="int client"/>
            </Overload>
        </KeyWord>
        <KeyWord name="GetClientOfSurvivorId" func="yes">
            <Overload retVal="native int" descr="
Params:
    survivorid              survivor id.
Notes:
    Returns client index.
Return:
    client index if successful otherwise 0.
">
                <Param name="int survivorid"/>
            </Overload>
        </KeyWord>

       
