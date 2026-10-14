# Ручная приёмка интеграции

Автоматические проверки используют Dummy. По состоянию на 14.10.2026 пользователь
вручную проверил Windows-сборку со звуком (WASAPI) и без звука (Dummy), а также
тестовый Android APK; сообщил, что результат его устраивает. Это не подтверждает
каждый отдельный сценарий из чеклиста ниже. Реальный Яндекс SDK, ручные Web
аудио/autoplay/OS Share и release signing/store packages остаются непроверенными.
Скриншоты `web-*.png` — Chrome/WebGL на Windows с изменением viewport, **не Android**.

Подставить `<id>` из строки `EXPORT_CHECKS_DONE` экспортного runner. Артефакты проверки: `build/verification/<id>/exports`.
Они локальные, ignored, не входят в коммит. Windows/Web manual содержат обычную основную
сцену без тестовых autoloads. Android package ID — `com.electrocrem.bizarregems.verification`,
название — Bizarre Gems Verification; debug-подпись отдельная, production credentials не использованы.

1. **Windows, сначала без звука.** Из PowerShell 7 в проекте:
   `./tools/launch_manual.ps1 -Artifacts build/verification/<id>/exports`.
   Пройти Classic, Bright Run, Daily; проверить мышь/клавиатуру, pause/restart/results,
   resize и fullscreen. Сравнить Bright Run из меню и после обучения при том же окне,
   проверить узкий HUD, появление/исчезновение цветной плашки. Перезапустить лаунчер:
   настройки, рекорды и прогресс должны сохраняться в отдельном тестовом профиле.
2. **Экраны и обучение.** More, Settings, Rules, Challenge/Share; RU/EN/TR, длинные строки.
   Через Rules повторить обучение, Next/Retry/Skip, выход, возврат и повторный запуск.
   Коллекция, Levels/Zen/Puzzle и сезонный пропуск недоступны. Проверить отсутствие
   наград/рекордов за практику. Проверить иконку окна/приложения.
3. **Отдельное ручное прослушивание.** Тот же лаунчер с `-AudioDriver WASAPI` явно включает
   настоящий звук. Запустить Classic и Bright Run/Daily, слушать переход через конец OGG
   (Classic 85,33 с, Run 76,8 с), pause/resume/restart/меню, громкость и music off.
   Проверить отсутствие наложения тем и качество стыка; штатную громкость Windows не менять.
4. **Web, локально и вручную.** Запустить Python:
   `python tools/serve.py 8070 build/verification/<id>/exports/web-manual`.
   Открыть `http://127.0.0.1:8070/` в отдельном браузерном профиле. Эта ручная сборка имеет
   штатный аудиодрайвер и может звучать после первого действия пользователя. Проверить
   autoplay до/после первого клика, background/focus, звук/loop, мобильный canvas/touch,
   safe area/fullscreen, все режимы/обучение, сохранения после reload, Challenge-ссылку и Share.
   `/sdk.js` локально подменён mock; это не проверка настоящих SDK/рекламы/облака.
5. **Android — повторная проверка; новая установка только по согласованию.** APK:
   `exports/android/bizarre-gems-verification.apk`. Сначала сверить тестовый package ID и
   отсутствие уже установленного тестового приложения с данными; не устанавливать поверх
   production. Не использовать автоматические install/launch команды до согласования.
   Проверить Classic landscape; меню/Bright Run/Daily portrait; фактические rotation,
   поле/HUD, cutouts/system bars, прицеливание/отпускание/отмена вторым пальцем,
   focus loss, Android Back/pause/resume, уроки, результаты, сохранения, иконку и аудиофокус.
   AAPT2 выдаёт предупреждение о дополнительном `themed_icon.xml`; обычная manifest-иконка
   `icon.xml` присутствует. Проверить в launcher обычную и themed иконки на устройстве;
   без устройства предупреждение не считается снятым.
6. **Реальная среда Яндекс Игр — отдельное согласование.** Нужны SDK ready/loading/gameplay,
   реальные rewarded/fullscreen success/refusal/error/offline, облачные save/merge,
   leaderboard/auth и Share по настоящему payload. Локальные mocks не доказывают это.
   Публикация, реальные аккаунты/данные и отправка рекордов автоматически не выполнялись.

В отчёте указать платформу/ОС/браузер или устройство, размер/ориентацию, режим и маршрут
запуска. Для дефекта — шаги, ожидаемое/фактическое поведение, скриншот и runtime log.
Лог ручного Windows запуска: `build/verification/<id>/manual-windows-profile/engine.log`.
