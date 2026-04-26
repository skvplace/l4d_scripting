
#if defined _skvtools_gamestart_included
 #endinput
#endif

#define _skvtools_gamestart_included

#define MAX_STAGE 18

/**
 * Triggered when gameplay starts.
 * Currently, all Left 4 Dead and Left 4 Dead 2 game modes are supported.
 *
 * @param stage         boot sequence number in seconds, max 18.
 */
forward void OnGameplayStart(int stage);

/**
 * Checks if the game is active.
*/
native bool IsGameplayActive(); 

/**
 * Checks if the server is empty.
*/
native bool IsServerEmpty();

/**
 * Fires when the mission_lost event occurs.
 */
forward void OnMissionLost();

/**
 * Fires when the round_end event occurs in non-cooperative modes.
 */
forward void OnRoundEnd();

/**
 * Fires when the last player leaves the server.
 */
forward void OnServerEmpty();

/**
 * Fires when the map_transit event occurs.
 */
forward void OnMapTransit();

/**
 * Triggered when the mission restarts.
 */
forward void OnMapRestart();

/**
 * Triggered when the mission changes.
 */
forward void OnMissionChange();

/**
 * Triggered when the rescue vehicle leaves the finale.
 */
forward void OnEscapeVehicleLeaving();