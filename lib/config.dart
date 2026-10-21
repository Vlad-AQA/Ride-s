// Адрес и публичный (anon) ключ проекта Supabase.
// Можно переопределить при сборке: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

// Пока ни один пользователь не подтвердил метку, она живёт столько.
const freshFor = Duration(hours: 1);

// Таиланд целиком — стартовый вид карты, если геолокация ещё не известна.
const thailandCenterLat = 13.0;
const thailandCenterLng = 100.9;
