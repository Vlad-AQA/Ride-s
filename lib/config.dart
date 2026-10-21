// Адрес и публичный (publishable) ключ проекта Supabase. Ключ публичный —
// его можно хранить в приложении; доступ к данным ограничен правилами в supabase/schema.sql.
// Можно переопределить при сборке: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gkzegtyeohhchiplnajn.supabase.co');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_2VEy08Qmarjvzp3Bzr0AeQ_flS7KHJq');

// Пока ни один пользователь не подтвердил метку, она живёт столько.
const freshFor = Duration(hours: 1);

// Таиланд целиком — стартовый вид карты, если геолокация ещё не известна.
const thailandCenterLat = 13.0;
const thailandCenterLng = 100.9;
