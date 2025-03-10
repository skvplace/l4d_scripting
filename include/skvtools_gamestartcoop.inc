
#if defined _skvtools_gamestartcoop_included
 #endinput
#endif

#define _skvtools_gamestartcoop_included

/**
 * Changes the current map and records the reason for the change with maphistory
 *
 * map 		- Map to change to
 * reason 	- Reason for change
 * return 	- 1 sucess, 0 failure
*/
native int FireChangeLevel(char [] map, char [] reason);

/**
 * Срабатывает, когда начинается gameplay в режиме coop, отправляет плагин [skvtools] gamestartcoop 1.1 +
 * stage 		- номер учередности загрузки (секунды)
 */
forward void OnGameplayStart(int stage);

/**
 * Срабатывает, когда сервер покидает последний игрок, отправляет плагин [skvtools] gamestartcoop 1.3 +
 */
forward void OnServerEmpty();

/**
 * Срабатывает, когда меняется карта, отправляет плагин [skvtools] gamestartcoop 1.3 +
 */
forward void OnMapTransit();

/**
 * Срабатывает, когда меняется карта, отправляет плагин [skvtools] l4d_gamestartcoop 1.3 +
 */
forward void OnMapRestart();

/**
 * Срабатывает, когда меняется карта, отправляет плагин [skvtools] l4d_gamestartcoop 3.4 +
 */
forward void OnEscapeVehicleLeaving();

/**
 * Срабатывает, когда меняется миссия, отправляет плагин [L4D] Dop Map Vote 1.4 +
 */
forward void OnChangeLevel(char [] map);