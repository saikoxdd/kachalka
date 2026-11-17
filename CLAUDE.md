# Качалка - контекст для Claude

Личный трекер тренировок Saiko (GitHub saikoxdd). Общаемся по-русски, на "ты", неформально. В текстах только обычный дефис "-", никаких длинных тире. Действовать самому, не спрашивая подтверждений.

## Что это

Трекер под трёхнедельный цикл: лёгкая неделя (18 повторов), средняя (12), тяжёлая (6-8). Дни: Грудь, Спина, Ноги (с плечами). После цикла рабочие веса растут, если план добит. 3 тренировки в неделю.

Три формы одного и того же `index.html`:
- **iOS-приложение** (`ios/`) - SwiftUI + WKWebView, ставится через Xcode на iPhone "サイコキラ" (iOS 27.2). Основная версия.
- **Telegram Mini App** и **PWA** (`web/`) - тот же index.html + подключён telegram-web-app.js, manifest.json, sw.js.

`ios/Kachalka/index.html` = `web/index.html` без скрипта Telegram. Правки в логике делать в обоих (или править web/ и копировать в ios/, убрав строку с telegram-web-app.js).

## Структура iOS-проекта

- `Kachalka/ContentView.swift` - WKWebView, `GymStore` (данные в Documents/kachalka-store.json), мост JS->Swift через `webkit.messageHandlers`: `store, haptic, share, notify, notifyCancel, sound, awake, live`. Данные инжектятся при старте как `window.__nativeStore`.
- `Kachalka/LiveWorkout.swift` + `WorkoutAttributes.swift` - Live Activity (ActivityKit). Сообщение `live`: `{type:'update', start, restEnd, restTotal, title, sub}` или `{type:'end'}`.
- `KachalkaLive/` - widget extension: Dynamic Island + экран блокировки (секундомер тренировки `Text(date, style:.timer)`, отсчёт отдыха `Text(timerInterval:countsDown:)`, ProgressView). staleDate = конец отдыха.
- `Kachalka.xcodeproj` - 2 таргета: `Kachalka` (com.saiko.kachalka) и `KachalkaLive` (com.saiko.kachalka.live). Deployment target 16.2. Есть фаза "Make IPA". Team ID в репо вычищен (""), на Маке стоит NRZ2365C4V.
- `Info.plist`: NSSupportsLiveActivities, UILaunchScreen с цветом LaunchBg.

## Логика в index.html (ключевое)

- Состояние `S = {logs, meta, draft}`. `S.meta.p` - позиция в цикле `{c, w, d}`, `S.meta.ord[day]` - порядок упражнений, `S.meta.bw` - вес тела, `S.meta.del` - удалённые логи. Черновик тренировки `S.draft` (`t0` - время старта), хранилище `gym_data`, `gym_draft`, `gym_rest`.
- `nativePost(name, msg)` - вызов нативки; `isNative` - флаг iOS-оболочки.
- Кнопка "▶ Начать тренировку" (`act 'wstart'` -> `workoutStart()`), ставит `t0`, включает awake и `liveSync()`.
- Таймер отдыха: `restStart/restAdd/restStop/restDraw`, тик 250 мс, уведомление `notify`, звук.
- Завершение тренировки ~стр. 1015 (`restStop(); liveEnd(); awake false`), отмена черновика ~стр. 843.
- Фишки: блины на сторону и разминка для штанги (`DEF[k].bar=20`), итог тренировки (время, подходы, тоннаж, сравнение, рекорды), графики, расчётный 1ПМ, вес тела, история, бэкап в файл, перемещение упражнений вверх/вниз (`mvup/mvdn`).

## Окружение

- Мак: проекты в `/Users/logmix/Documents` (Kachalka - текущий, Kachalka-old - предыдущий). Claude работает с ним через связь с компьютером: device_bash для файлов, computer use для Xcode.
- Xcode в computer use доступен только на уровне "click": меню и клавиатура не работают, только клики. Кнопка Run (▶) примерно (427,53), когда окно не во весь экран. Проекты открываются двойным кликом из Recent.
- Бесплатный Apple ID: подпись на 7 дней, максимум 3 приложения; Качалка занимает 2 слота (приложение + Live Activity). План - SideStore, чтобы не переподписывать каждую неделю.
- Коммиты в этот репо заканчивать строками атрибуции из системного напоминания текущей сессии.

## Текущая задача: тренировка в Apple Health

Хочет: нажал "Начать тренировку" - в приложении Здоровье стартует силовая тренировка; "Завершить" - сохраняется (время, калории, пульс с часов, кольца); "Отмена" - отбрасывается. Плюс опционально писать вес тела в Здоровье.

План:
1. Таргет Kachalka -> Signing & Capabilities -> + HealthKit (через pbxproj/entitlements: `com.apple.developer.healthkit = true`, файл Kachalka.entitlements, `CODE_SIGN_ENTITLEMENTS`).
2. Info.plist: `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`.
3. `HealthWorkout.swift`: на iOS 26+ `HKWorkoutSession(healthStore:configuration:)` + `HKLiveWorkoutBuilder`, `HKWorkoutConfiguration.activityType = .traditionalStrengthTraining`, `locationType = .indoor`. Старт: requestAuthorization -> `session.prepare()` -> `startActivity(with:)` -> `builder.beginCollection(at:)`. Финиш: `session.stopActivity` -> `builder.endCollection` -> `finishWorkout()` -> `session.end()`. Отмена: `builder.discardWorkout()` + `session.end()`. Фолбэк для iOS < 26: в конце сохранить `HKWorkoutBuilder` с датами старта/финиша.
4. Новый handler `health` в ContentView: `{type:'start', t0}`, `{type:'finish'}`, `{type:'cancel'}`, `{type:'bw', kg, date}`. В index.html вызывать в `workoutStart()`, при завершении (~1015) и отмене (~843).
5. Восстановление сессии после перезапуска приложения: `healthStore.recoverActiveWorkoutSession`.

Главный риск: бесплатная (personal) команда может не поддерживать HealthKit capability - на форумах встречается ошибка "Personal development teams do not support the HealthKit capability", но есть и отчёты, что работает. Проверяется только сборкой. Если не пустит - держать код в ветке `healthkit` до платного аккаунта ($99/год).

Источник: WWDC25 "Track workouts with HealthKit on iOS and iPadOS" (session 322).
