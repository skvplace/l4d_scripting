
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
 * Срабатывает, когда начинается gameplay в режиме coop
 * stage 		- номер учередности загрузки (секунды)
 */
forward void OnGameplayStart(int stage);

/**
 * Срабатывает, когда сервер покидает последний игрок
 */
forward void OnServerEmpty();

/**
 * Срабатывает, когда меняется карта
 */
forward void OnMapTransit();

/**
 * Срабатывает, когда карта перезагружается
 */
forward void OnMapRestart();

/**
 * Срабатывает, когда спасательный транспорт покидает финал
 */
forward void OnEscapeVehicleLeaving();

/**
 * Срабатывает, когда меняется миссия
 */
forward void OnChangeLevel(char [] map);
