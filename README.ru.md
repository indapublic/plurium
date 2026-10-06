# Plurium — Chromium с вкладками всех профилей (macOS, Apple Silicon)

Личная сборка Chromium: окна всех профилей живут в одном окне, а в одной полосе
вкладок видны вкладки всех профилей вперемешку, в любом порядке. Под капотом это
группа нативных табов macOS (NSWindow tabbing): одно окно профиля — один таб
группы. Полоса AppKit спрятана. Полоса вкладок Chromium тоже: вместо неё общая
полоса со вкладками всех профилей. Все вкладки нарисованы одинаково, у левого края
каждой — полоска в цвет её профиля. Профили (куки, логины, расширения) изолированы как
обычно, у каждого свой цвет темы.

Сборка называется **Plurium** (plural + ‑ium, игра слов с Chromium). Для macOS
это отдельное приложение с фиолетовой иконкой Chromium и своим bundle id
(`com.indapublic.plurium`). Свои данные оно хранит в
`~/Library/Application Support/Plurium`, обычный Chromium рядом не трогает.

Базовая версия: **154.0.8037.98** (Stable для Mac на 2026-10-05), ветка `profile-tabs`.

```
● ● ●  [Gmail] [GitHub] [Jira] [Slack] [Bank] [Docs]  +
        ▌ — полоска цвета профиля у левого края вкладки
← → ↻ [ омнибокс профиля активной вкладки                    ] ⋮
```

Что умеет полоса:
- клик по вкладке активирует её, переключая окно профиля, если нужно;
- крестик или средний клик закрывают вкладку;
- перетаскивание меняет порядок как угодно, вкладки разных профилей вперемешку;
- «+» открывает вкладку в текущем профиле, правый клик по «+» — в любом профиле;
- правый клик по вкладке: Reload, Duplicate, Mute tab, «Move to profile ▸»
  (открыть этот адрес в другом профиле на том же месте полосы), Close tab,
  Close other tabs of <профиль>.

Клавиши Chrome для вкладок идут по общей полосе: ⌘1…⌘8 — N-я вкладка, ⌘9 —
последняя, ⌃Tab / ⌃⇧Tab, ⌘⌥→ / ⌘⌥←, ⌘⇧] / ⌘⇧[, ⌃PgDn / ⌃PgUp — следующая и
предыдущая, ⌃⇧PgDn / ⌃⇧PgUp двигают вкладку. ⌃1…⌃9 переключают на N-й профиль.
Цвета берутся из «Настроить Chromium → Цвет» каждого профиля. Общий порядок
вкладок сохраняется между запусками. В fullscreen та же полоса.

## Что в патчах

| Патч | Что делает |
|---|---|
| `0001-Mac-join-profile-windows-…` | Группа табов, подписи, раскладка «профили сверху» (сейчас запасная) |
| `0002-Mac-Ctrl-1.Ctrl-9-…` | ⌃1…⌃9 выбирают N-й профиль группы |
| `0003-Mac-Chrome-style-profile-switcher-…` | Прячет полосу AppKit, общий fullscreen группы, защита от fullscreen при запуске |
| `0004-Mac-one-tab-strip-with-the-tabs-of-all-profiles…` | Общая полоса вкладок всех профилей: свой порядок, перетаскивание, меню вкладки, клавиши по общему порядку, полоса в fullscreen |
| `0005-Mac-Plurium-branding-…` | Имя Plurium, свой bundle id и папка данных, фиолетовая иконка |
| `0006-Mac-Plurium-updates-through-Homebrew` | Обновление через Homebrew из самого приложения |

Вся логика в новых файлах `chrome/browser/ui/views/frame/profile_tabs_mac.{h,mm}`
(группа окон, общий порядок вкладок) и `unified_tab_strip_mac.{h,mm}` (сама полоса).
В существующие файлы добавлены только короткие хуки:

- `chrome/browser/ui/BUILD.gn` — 4 строки в mac-блоке `static_library("ui")`;
- `browser_native_widget_mac.mm`:
  - `ObserveBrowserWidget()` в конце `OnWidgetInitDone()`;
  - ранний выход в `GetWindowFrameTitlebarHeight()` для запасной раскладки;
- `browser_frame_view_mac.mm`:
  - `AdjustClientBounds()` в `GetBoundsForClientView()`;
  - `AdjustLayoutParams()` в `GetBrowserLayoutParams()` — запасная раскладка;
  - `NonClientHitTest()` в одноимённом методе — клик по вкладке не таскает окно,
    пустое место полосы таскает;
- `chrome/app/theme/chromium/BRANDING` — `MAC_BUNDLE_ID`, `MAC_TEAM_ID`;
- `build/util/branding.gni` — gn-аргумент `plurium_dev_build` (имя
  «Plurium Dev» и суффикс `.dev` у bundle id);
- `chrome/BUILD.gn` — подстановка `PLURIUM_APP_NAME` и выбор иконки (обычной
  или `_dev`);
- `chrome/app/app-Info.plist` — `CFBundleName`/`CFBundleDisplayName` (имя в
  строке меню, Dock и Finder) и `CrProductDirName` (папка данных) =
  `${PLURIUM_APP_NAME}`;
- `chrome/app/chromium_strings.grd` — `IDS_PRODUCT_NAME`, `IDS_SHORT_PRODUCT_NAME`,
  `IDS_APP_MENU_PRODUCT_NAME` (непереводимые: пункты «About/Hide/Quit Plurium»,
  заголовки окон, системные запросы разрешений);
- `chrome/app/theme/chromium/mac/Assets.car`, `app.icns` (фиолетовая) и
  `Assets_dev.car`, `app_dev.icns` (оранжевая, Plurium Dev) — перекрашенные
  иконки (бинарные, их делает `tools/make-icon.py` из неизменённых исходников
  Chromium).

Как это работает:

- **Какие окна в группе.** Только `TYPE_NORMAL`, включая инкогнито («Bravo (Incognito)»).
  Второе окно профиля подписывается «Bravo 2». DevTools, попапы, PWA/`--app`,
  окно выбора профиля и окна, оторванные перетаскиванием вкладки, не трогаются.
- **Склейка.** Явный `-[NSWindow addTabbedWindow:ordered:]`. Глобальный
  `NSWindow.allowsAutomaticWindowTabbing` остаётся `NO`, как его выставляет Chromium.
- **Полоса AppKit.** Прячется публичным `NSTitlebarAccessoryViewController.hidden`
  в каждом окне группы. Нужный accessory находится по вложенному `NSTabBar`.
  Если macOS однажды не даст её спрятать, включается запасная раскладка: весь
  интерфейс Chromium сдвигается под стандартный titlebar и полосу табов (+56pt).
- **Общая полоса.** Полоса вкладок Chromium остаётся на месте (её строка и
  минимальная ширина окна не меняются), но становится прозрачной и не принимает
  события. Поверх неё рисуется `UnifiedTabStrip`. Порядок — последовательность
  «окно профиля → вкладка». Внутри одного окна он всегда совпадает с порядком
  модели Chromium (`TabStripModel`): перетаскивание двигает вкладку и в модели,
  поэтому ⌘W, восстановление сессии и расширения работают как обычно. Клавиши
  выбора и перемещения вкладок перехватывает тот же локальный NSEvent-монитор,
  что и ⌃N, и применяет к общему порядку (пока в группе больше одного окна).
  Спрятанная полоса Chromium исключена из дерева доступности, VoiceOver видит
  только общую.
  Новые вкладки встают рядом с соседями по своему окну, вкладки в конце окна
  (⌘T) — в конец полосы. Порядок сохраняется в домене
  `com.indapublic.plurium.profile-tabs` (`<bundle id>.profile-tabs`, ключ `TabOrder <user-data-dir>`) и
  применяется к восстановленным окнам при запуске.
- **Fullscreen.** Общий на всю группу, как у нативных табов macOS. ⌃⌘F или
  зелёная кнопка уводят в fullscreen всю группу. ⌃N переключает профили
  внутри fullscreen, и каждое окно, когда его показывают, само переходит в
  fullscreen-режим Chromium. Выход из fullscreen выводит все показанные окна.
  В fullscreen Chromium переносит свою полосу вкладок в отдельный
  оверлей-виджет; общая полоса переезжает туда вместе с ней (и обратно), так что
  вкладки всех профилей видны и там.
- **Защита от fullscreen при запуске.** Если в прошлом запуске группа побывала в
  fullscreen, macOS при следующем запуске сама переводит в fullscreen новые окна
  приложения. Сессия Chromium тут ни при чём, в ней всё записано как обычное.
  Поэтому, пока окно не вступило в группу, у него снят
  `NSWindowCollectionBehaviorFullScreenPrimary`. Флаг возвращается при вступлении
  в группу или перед явным `-toggleFullScreen:` (перехват через
  `base::apple::ScopedObjCClassSwizzler`), например при `--start-fullscreen`.

## Требования

- Mac на Apple Silicon, macOS 15+, полный Xcode 26+.
- **Metal Toolchain**. В Xcode 26 он ставится отдельно, без него сборка падает
  на шейдерах ANGLE:
  ```bash
  xcodebuild -downloadComponent MetalToolchain
  ```
- ~200 ГБ свободного места: история git ≈ 65 ГБ, весь `src` ≈ 110 ГБ, `out/Default`
  ≈ 10 ГБ, `out/Release` ≈ 15–20 ГБ.
- Время на M1 (8 ядер, 16 ГБ): fetch ≈ 3,5 ч на ~6 МБ/с, `out/Default` ≈ 7 ч,
  `out/Release` ≈ 9,5 ч. На 16 ГБ под конец (тяжёлые файлы `chrome/browser`)
  8 параллельных компиляций загоняют Mac в swap; тогда `JOBS=4` перед
  `night2.sh` быстрее (сборка продолжается с того же места). На время финальной
  линковки лучше закрыть тяжёлые приложения и виртуалки.
- Папку `/Volumes/Workspace/chromium` стоит добавить в Spotlight → «Конфиденциальность».

## Сборка с нуля

```bash
mkdir -p /Volumes/Workspace/chromium && cd /Volumes/Workspace/chromium
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
fetch --nohooks chromium              # полная история, нужны теги
cd src
VER=154.0.8037.98
git fetch origin "+refs/tags/$VER:refs/tags/$VER"
git checkout -b profile-tabs "tags/$VER"
git am /Volumes/Workspace/chromium/plurium/patches/000*.patch
gclient sync -D --with_branch_heads --with_tags
```

То же самое без присмотра, с логом и `caffeinate`, делает `tools/night1.sh`.
Он идемпотентный: после сбоя его можно просто перезапустить. Патчи он не
накладывает, `git am` после него выполняется отдельно.

### args.gn для разработки — `out/Default`

```gn
is_debug = false
is_component_build = true
symbol_level = 0
target_cpu = "arm64"
proprietary_codecs = true
ffmpeg_branding = "Chrome"
plurium_dev_build = true   # отдельное приложение «Plurium Dev»
```

С `plurium_dev_build = true` сборка — отдельное приложение **Plurium Dev**:
bundle id `com.indapublic.plurium.dev`, данные в
`~/Library/Application Support/Plurium Dev`, оранжевая иконка, обновления
проверяются только по запросу. Так тесты не делят с рабочим Plurium ни
настройки и разрешения macOS, ни плитку в Dock. В `out/Release` аргумента нет:
это Plurium, который ставится пользователям.

Инкрементальная пересборка после правки `profile_tabs_mac.mm` занимает около 30 секунд.

### args.gn для ежедневной сборки — `out/Release`

```gn
is_debug = false
is_component_build = false
symbol_level = 0
dcheck_always_on = false   # в не-official сборках DCHECK по умолчанию включены и роняют браузер
target_cpu = "arm64"
proprietary_codecs = true
ffmpeg_branding = "Chrome"
```

```bash
gn gen out/Release            # args.gn положить в out/Release заранее
autoninja -C out/Release chrome
```

То же самое делает `tools/night2.sh`. Готовый `out/Release/Chromium.app`
самодостаточный. Ставится под своим именем:

```bash
ditto out/Release/Chromium.app /Applications/Plurium.app
```

Внутри бандла исполняемый файл, фреймворк и хелперы остаются `Chromium` —
на эти имена завязан код, поэтому в `out/` бандл называется `Chromium.app`. При первом запуске
macOS спросит доступ к ключу «Chromium Safe Storage» в связке ключей. Сборку
из `out/Default` (component build) переносить нельзя.

## Ребейз на новый релиз

```bash
cd /Volumes/Workspace/chromium/src
OLD=154.0.8037.98
NEW=<новая stable-версия с chromiumdash.appspot.com>
git fetch origin "+refs/tags/$NEW:refs/tags/$NEW"
git rebase --onto "tags/$NEW" "tags/$OLD" profile-tabs
gclient sync -D --with_branch_heads --with_tags
autoninja -C out/Release chrome
git format-patch "tags/$NEW" -o ../plurium/patches/   # обновить патчи
```

Где ожидать конфликтов:

- **`chrome/browser/ui/BUILD.gn`.** На `main` файл `browser_native_widget_mac.mm`
  уже вынесен в `source_set("browser_native_widget_mac_impl")` в
  `chrome/browser/ui/views/frame/BUILD.gn`. Когда это дойдёт до stable, нужно
  перенести две строки `profile_tabs_mac.*` в этот target и добавить ему в deps
  `//chrome/browser/ui/views/tabs/dragging` и `//chrome/browser/profiles:profile_util`
  (сверить точные имена по месту).
- **Сигнатуры** `GetWindowFrameTitlebarHeight`, `GetBoundsForClientView` и
  `GetBrowserLayoutParams`: хуки однострочные, переносятся руками.
- **Иконка** (`Assets.car`, `app.icns`). Если апстрим поменял иконку, взять его
  версию (в rebase это `--ours`) и пересобрать свою:
  ```bash
  git checkout --ours chrome/app/theme/chromium/mac/Assets*.car chrome/app/theme/chromium/mac/app*.icns
  python3 ../plurium/tools/make-icon.py
  git add chrome/app/theme/chromium/mac && git rebase --continue
  ```
- После ребейза прогнать `tools/checklist.sh` (см. ниже).

## Проверка

```bash
plurium/tools/checklist.sh                  # out/Default
OUT=out/Release plurium/tools/checklist.sh  # ежедневная сборка
```

Скрипт поднимает свежий каталог профилей `/tmp/chromium-test-check-*` и локальную
тестовую страницу на `127.0.0.1:8765`, открывает 4 профиля (Alpha, Bravo, Charlie,
Delta) и проверяет:

- одна группа, полоса AppKit спрятана, общая полоса во всех 4 окнах;
- куки изолированы;
- попап и `--app` остаются вне группы;
- инкогнито и второе окно попадают в группу с правильными подписями;
- три раза fullscreen туда и обратно;
- переключение профиля внутри fullscreen и выход из него;
- закрытие табов;
- перезапуск с восстановлением сессии;
- отсутствие падений.

Остальные инструменты в `tools/`:

| Файл | Зачем |
|---|---|
| `run-test.sh` | Запуск с изолированным `--user-data-dir` (по умолчанию `/tmp/chromium-test`), `--use-mock-keychain`, CDP на 9222 и логами `profile_tabs` |
| `open-profiles.sh` | Запустить и открыть окна 4 тестовых профилей |
| `seed-profiles.py` | Назвать тестовые профили и задать им цвета темы, выключить выбор профиля на старте (`--restore` — «продолжить с того же места») |
| `cdp.mjs` | Минимальный клиент DevTools Protocol (Node 22+) |
| `make-icon.py` | Перекрасить иконку Chromium: фиолетовая для релиза, оранжевая для Plurium Dev; собрать `Assets*.car`/`app*.icns` (Pillow, Xcode 26) |
| `night1.sh`, `night2.sh` | Ночные полные сборки |

Ручная часть (мышь и клавиатура):

- клик по вкладке другого профиля, перетаскивание вкладок вперемешку,
  правый клик по вкладке и по «+», порядок после перезапуска;
- логин в разные аккаунты одного сайта;
- DevTools в отдельном окне;
- ⌘1…⌘9, ⌃Tab / ⌃⇧Tab, ⌘⌥←/→, ⌃⇧PgUp/PgDn — по общей полосе;
- ⌃1…⌃4;
- fullscreen: общая полоса в оверлее, клик по вкладке другого профиля, выход;
- закрытие окна профиля (⌘⇧W);
- ⌘Q и повторный запуск.

## Подпись, релиз и Homebrew

Репозиторий [indapublic/plurium](https://github.com/indapublic/plurium) —
одновременно дом проекта (патчи, скрипты, релизы с DMG) и Homebrew-tap
(`Casks/plurium.rb`):

```bash
brew tap indapublic/plurium https://github.com/indapublic/plurium
brew trust --cask indapublic/plurium/plurium   # Homebrew 7+ требует доверия к стороннему tap
brew install --cask indapublic/plurium/plurium # обновление: brew upgrade --cask plurium
```

Один раз на машине, где делаются релизы:
- сертификат «Developer ID Application» в связке ключей (Xcode → Settings →
  Accounts → Manage Certificates);
- профиль notarytool (пароль вводится самостоятельно, это app-specific password
  с appleid.apple.com):
  ```bash
  xcrun notarytool store-credentials plurium --apple-id <Apple ID> --team-id 4WSCP7LMZQ
  ```

Релиз после сборки `out/Release`:

```bash
autoninja -C out/Release chrome chrome/installer/mac   # + скрипты подписи Chromium
../plurium/tools/release.sh            # подписать, нотаризовать, собрать DMG
../plurium/tools/release.sh --publish  # то же + GitHub release + bump cask + push
```

`release.sh` подписывает приложение штатным `sign_chrome.py` Chromium (все
вложенные хелперы, фреймворк и entitlements), нотаризует и стейплит его,
собирает `Plurium-<версия>-<N>-arm64.dmg` с `Plurium.app`, подписывает,
нотаризует и стейплит DMG. Версия релиза — версия Chromium плюс номер сборки
(`REVISION=2` для повторного релиза на той же версии Chromium).

## Обновления внутри приложения

Через минуту после запуска и потом каждые 6 часов Plurium скачивает
`Casks/plurium.rb` из `main` этого репозитория (ровно то, что поставит
`brew upgrade`) и сравнивает версию с установленной (папка версии в
`$(brew --prefix)/Caskroom/plurium`). Если вышла новая:

- в конце полосы вкладок появляется кнопка **Update**, а в меню
  «Plurium» пункт «Check for Updates…» превращается в «Update to <версия>…»;
- `chrome://settings/help` показывает ту же проверку вместо отсутствующего
  Chromium Updater («Plurium is up to date» или «An update is available» с
  кнопкой Relaunch);
- по нажатию — подтверждение и обычный `chrome::AttemptRelaunch()` (сессии
  всех профилей восстанавливаются, страница с несохранёнными данными может
  отменить). Пока есть обновление, команда перезапуска подменена
  (`upgrade_util::SetRelaunchChromeBrowserCallbackForTesting()`): отдельный
  скрипт ждёт выхода процесса, делает `brew update` и
  `brew upgrade --cask indapublic/plurium/plurium` и открывает Plurium с теми
  же ключами перезапуска. Так обновляет и Relaunch на странице «О программе»,
  и `chrome://restart`;
- лог: `~/Library/Logs/Plurium/update.log`.

Копия, поставленная не через brew (не из `/Applications` или без Caskroom),
только ведёт на страницу релиза. Выключить автоматические проверки:
`defaults write com.indapublic.plurium PluriumAutomaticUpdateChecks -bool NO`.
Для тестов `--plurium-update-feed=<url>` подменяет адрес cask (например,
локальный файл с более новой версией).

Значит, для выпуска обновления достаточно `tools/release.sh --publish`:
пользователи увидят кнопку в течение 6 часов.

## Известные ограничения

- **Нет Chrome Sync** и входа в Google-аккаунт браузера: у сборки нет Google API
  keys и OAuth-клиента. Плашку о недостающих ключах можно скрыть, запуская с
  `GOOGLE_API_KEY=no GOOGLE_DEFAULT_CLIENT_ID=no GOOGLE_DEFAULT_CLIENT_SECRET=no`.
- **Нет Widevine**: Netflix, Spotify Web и другой DRM-контент не воспроизводится.
- **Passkeys через iCloud Keychain**, скорее всего, не работают: нужны
  entitlement'ы и подпись разработчика Google.
- **Обновления только наши.** Каждый security-релиз Chromium означает ребейз,
  пересборку `out/Release` (≈ 9,5 ч на M1) и новый релиз. Отставать от stable
  надолго не стоит.
- Связку ключей Chromium использует свою («Chromium Safe Storage»), при первом
  запуске macOS спросит доступ. С данными Google Chrome она не пересекается, а
  с обычным Chromium ключ общий (у него то же имя); данные при этом разные.
- «Chromium» остаётся там, где он вписан прямо в текст строки (часть страниц
  настроек, «Chromium Safe Storage», хелперы в Мониторе активности), а также в
  `chrome://version`. Переименованы только сами названия продукта.
- macOS кэширует иконки по пути бандла. После пересборки с новой иконкой Dock
  может показывать старую для `out/…/Chromium.app`; у копии в `/Applications`
  под новым именем иконка всегда свежая.
- Полоса AppKit прячется по имени её класса (`NSTabBar`). Если macOS его
  поменяет, включится запасная раскладка «профили сверху» с нативной полосой.
- Взамен полосы Chromium пропадают: превью при наведении, закреплённые вкладки
  и группы Chrome (они остаются в модели, но не рисуются), вытаскивание вкладки в
  новое окно, перетаскивание ссылок на полосу, кнопка поиска по вкладкам,
  родное контекстное меню вкладки (есть своё, базовое).
- Перенести вкладку в другой профиль с сохранением состояния нельзя: «Move to
  profile» открывает тот же адрес заново, уже с логином другого профиля.
- Когда вкладок много, они сжимаются до иконки (24pt), лишние обрезаются справа.
- Новое окно на мгновение появляется отдельно, потом встаёт в группу.
- Порядок профилей после перезапуска зависит от порядка восстановления сессии и
  может отличаться от прежнего. Тогда ⌃N укажет на другой профиль.
- ⌃1…⌃9 перехватит macOS, если включено «Переключиться на рабочий стол N»
  (Системные настройки → Клавиатура → Сочетания клавиш → Mission Control).
  Веб-страницы ⌃+цифру больше не получают.
- При нескольких профилях Chromium на старте показывает окно выбора профиля
  (стандартное поведение). Отключается галочкой «Показывать при запуске» в этом окне.
