# ThaiRide

Карта полицейских постов и проверок в Таиланде. Пользователи ставят метки,
подтверждают («Актуально») или опровергают («Неактуально») их, всё обновляется онлайн.

## Правила меток
- новая метка живёт 1 час;
- каждое «Актуально» продлевает её до 3 часов от момента подтверждения;
- 2 разных «Неактуально» после последнего подтверждения снимают метку;
- метку можно поставить не дальше 70 км от себя, не больше 5 меток за 10 минут;
- красный пин — видели меньше часа назад, жёлтый — давно.

## Как устроено
- `lib/` — приложение на Flutter (Android и iOS), карта OpenStreetMap через flutter_map.
- `supabase/schema.sql` — база и вся серверная логика (Supabase).
- `.github/workflows/build-apk.yml` — GitHub сам собирает APK при каждом пуше в `main`
  (вкладка Actions → последний запуск → Artifacts → `thairide-apk`).

## Настройка сервера
1. Supabase → SQL Editor → вставить `supabase/schema.sql` → Run.
2. Authentication → Sign In / Providers → включить *Allow anonymous sign-ins*.
3. В `lib/config.dart` вписать Project URL и publishable (anon) key.
