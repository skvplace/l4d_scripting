
#if defined _skvtools_gamestart_included
 #endinput
#endif

#define _skvtools_gamestart_included

#define MAX_STAGE 18

/**
 * Срабатывает, когда начинается gameplay в режиме coop
 * stage - номер учередности загрузки в секундах, макс 18
 */
forward void OnGameplayStart(int stage);

/**
 * Срабатывает при событии mission_lost
 */
forward void OnMissionLost();

/**
 * Checks if the game is active
*/
native bool IsGameplayActive(); 

/**
 * Срабатывает, когда сервер покидает последний игрок
 */
forward void OnServerEmpty();

/**
 * Срабатывает, когда меняется карта
 */
forward void OnMapTransit();

/**
 * Срабатывает, когда миссия перезапускается
 */
forward void OnMapRestart();

/**
 * Срабатывает, когда меняется миссия
 */
forward void OnMissionChange();

/**
 * Срабатывает, когда спасательный транспорт покидает финал
 */
forward void OnEscapeVehicleLeaving();