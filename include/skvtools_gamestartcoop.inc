
#if defined _skvtools_gamestartcoop_included
 #endinput
#endif

#define _skvtools_gamestartcoop_included

/**
 * Срабатывает, когда начинается gameplay в режиме coop
 * stage - номер учередности загрузки в секундах, макс 18
 */
forward void OnGameplayStart(int stage);

/**
 * Срабатывает, когда сервер покидает последний игрок
 */
forward void OnServerEmpty();

/**
 * Срабатывает, когда принудительно меняется карта
 */
forward void OnMapTransit();

/**
 * Срабатывает, когда миссия перезагружается
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
