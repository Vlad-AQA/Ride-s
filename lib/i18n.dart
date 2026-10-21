import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const languages = {'ru': 'Русский', 'en': 'English', 'th': 'ไทย'};

final lang = ValueNotifier<String>('ru');

Future<void> loadLanguage(String systemCode) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('lang');
  lang.value = saved ?? (languages.containsKey(systemCode) ? systemCode : 'en');
}

Future<void> setLanguage(String code) async {
  lang.value = code;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lang', code);
}

String tr(String key, [Map<String, Object> args = const {}]) {
  var s = _strings[lang.value]?[key] ?? _strings['en']![key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

String typeName(MarkerType t) => tr('type_${t.key}');

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr('just_now');
  if (d.inMinutes < 60) return tr('min_ago', {'n': d.inMinutes});
  return tr('h_ago', {'n': d.inHours});
}

String duration(Duration d) {
  if (d.inMinutes < 60) return tr('min', {'n': d.inMinutes.clamp(1, 59)});
  return tr('h_min', {'h': d.inHours, 'm': d.inMinutes % 60});
}

String errorText(String serverMessage) {
  final far = RegExp(r'too_far:(\d+)').firstMatch(serverMessage);
  if (far != null) return tr('err_too_far', {'km': far[1]!});
  for (final code in ['rate_limited', 'own_marker', 'already_voted', 'marker_not_found']) {
    if (serverMessage.contains(code)) return tr('err_$code');
  }
  return tr('err_generic');
}

const _strings = <String, Map<String, String>>{
  'ru': {
    'place_marker': 'Поставить метку',
    'add_marker': 'Добавить метку',
    'comment_hint': 'Добавить комментарий',
    'type_checkpoint': 'Пост',
    'type_moto_patrol': 'Мотопатруль',
    'type_tourist_check': 'Проверка туристов',
    'type_alcohol': 'Алкотест',
    'type_drug_test': 'Тест на наркотики',
    'type_highway': 'Дорожная полиция',
    'type_camera': 'Камера',
    'type_hazard': 'ДТП / опасность',
    'actual': 'Актуально',
    'not_actual': 'Неактуально',
    'confirmed': 'Подтверждено: {n} · {ago}',
    'not_confirmed': 'Не подтверждено · {ago}',
    'expires_in': 'Исчезнет через {t}',
    'address': 'Адрес',
    'no_comments': 'Пока тихо. Расскажи, что там происходит',
    'send': 'Отправить',
    'settings': 'Настройки',
    'language': 'Язык',
    'show_types': 'Показывать на карте',
    'pick_point': 'Двигай карту, чтобы навести метку',
    'added': 'Метка добавлена',
    'voted': 'Спасибо!',
    'share': 'Поделиться',
    'share_text': '{type} — {address}',
    'just_now': 'только что',
    'min_ago': '{n} мин назад',
    'h_ago': '{n} ч назад',
    'min': '{n} мин',
    'h_min': '{h} ч {m} мин',
    'err_too_far': 'Метка слишком далеко ({km} км). Максимум — 70 км от тебя',
    'err_rate_limited': 'Слишком часто. Попробуй чуть позже',
    'err_own_marker': 'Нельзя голосовать за свою метку',
    'err_already_voted': 'Ты уже голосовал за эту метку',
    'err_marker_not_found': 'Метка уже исчезла',
    'err_generic': 'Что-то пошло не так. Попробуй ещё раз',
    'err_location': 'Не удалось определить местоположение. Включи GPS',
    'no_server': 'Сервер не настроен: укажи SUPABASE_URL и SUPABASE_ANON_KEY в lib/config.dart',
  },
  'en': {
    'place_marker': 'Report',
    'add_marker': 'Add report',
    'comment_hint': 'Add a comment',
    'type_checkpoint': 'Checkpoint',
    'type_moto_patrol': 'Moto patrol',
    'type_tourist_check': 'Tourist check',
    'type_alcohol': 'Alcohol test',
    'type_drug_test': 'Drug test',
    'type_highway': 'Highway police',
    'type_camera': 'Camera',
    'type_hazard': 'Accident / hazard',
    'actual': 'Still there',
    'not_actual': 'Gone',
    'confirmed': 'Confirmed: {n} · {ago}',
    'not_confirmed': 'Not confirmed · {ago}',
    'expires_in': 'Disappears in {t}',
    'address': 'Address',
    'no_comments': 'Quiet so far. Tell others what is going on',
    'send': 'Send',
    'settings': 'Settings',
    'language': 'Language',
    'show_types': 'Show on map',
    'pick_point': 'Move the map to place the pin',
    'added': 'Report added',
    'voted': 'Thanks!',
    'share': 'Share',
    'share_text': '{type} — {address}',
    'just_now': 'just now',
    'min_ago': '{n} min ago',
    'h_ago': '{n} h ago',
    'min': '{n} min',
    'h_min': '{h} h {m} min',
    'err_too_far': 'Too far away ({km} km). Maximum is 70 km from you',
    'err_rate_limited': 'Too many reports. Try again later',
    'err_own_marker': 'You cannot vote on your own report',
    'err_already_voted': 'You have already voted',
    'err_marker_not_found': 'This report has expired',
    'err_generic': 'Something went wrong. Try again',
    'err_location': 'Could not get your location. Turn on GPS',
    'no_server': 'Server is not configured: set SUPABASE_URL and SUPABASE_ANON_KEY in lib/config.dart',
  },
  'th': {
    'place_marker': 'ปักหมุด',
    'add_marker': 'เพิ่มหมุด',
    'comment_hint': 'เพิ่มความคิดเห็น',
    'type_checkpoint': 'ด่านตรวจ',
    'type_moto_patrol': 'สายตรวจมอไซค์',
    'type_tourist_check': 'ตรวจนักท่องเที่ยว',
    'type_alcohol': 'ตรวจแอลกอฮอล์',
    'type_drug_test': 'ตรวจสารเสพติด',
    'type_highway': 'ตำรวจทางหลวง',
    'type_camera': 'กล้อง',
    'type_hazard': 'อุบัติเหตุ / อันตราย',
    'actual': 'ยังอยู่',
    'not_actual': 'ไม่อยู่แล้ว',
    'confirmed': 'ยืนยันแล้ว: {n} · {ago}',
    'not_confirmed': 'ยังไม่ยืนยัน · {ago}',
    'expires_in': 'จะหายไปใน {t}',
    'address': 'ที่อยู่',
    'no_comments': 'ยังเงียบอยู่ เล่าให้คนอื่นฟังหน่อย',
    'send': 'ส่ง',
    'settings': 'ตั้งค่า',
    'language': 'ภาษา',
    'show_types': 'แสดงบนแผนที่',
    'pick_point': 'เลื่อนแผนที่เพื่อวางหมุด',
    'added': 'เพิ่มหมุดแล้ว',
    'voted': 'ขอบคุณ!',
    'share': 'แชร์',
    'share_text': '{type} — {address}',
    'just_now': 'เมื่อสักครู่',
    'min_ago': '{n} นาทีที่แล้ว',
    'h_ago': '{n} ชม. ที่แล้ว',
    'min': '{n} นาที',
    'h_min': '{h} ชม. {m} นาที',
    'err_too_far': 'หมุดอยู่ไกลเกินไป ({km} กม.) สูงสุด 70 กม. จากคุณ',
    'err_rate_limited': 'บ่อยเกินไป ลองใหม่ภายหลัง',
    'err_own_marker': 'โหวตหมุดของตัวเองไม่ได้',
    'err_already_voted': 'คุณโหวตไปแล้ว',
    'err_marker_not_found': 'หมุดนี้หมดอายุแล้ว',
    'err_generic': 'เกิดข้อผิดพลาด ลองอีกครั้ง',
    'err_location': 'ไม่สามารถระบุตำแหน่งได้ กรุณาเปิด GPS',
    'no_server': 'ยังไม่ได้ตั้งค่าเซิร์ฟเวอร์',
  },
};
