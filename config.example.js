// Скопируйте этот файл в config.js и вставьте свои данные из Supabase
// (Settings → API в панели Supabase). config.js в git не попадает —
// см. .gitignore. Для деплоя на GitHub Pages эти значения задаются
// через секреты репозитория (SUPABASE_URL, SUPABASE_ANON_KEY,
// OCR_SPACE_API_KEY) и подставляются автоматически workflow'ом
// .github/workflows/deploy.yml.
window.SUPABASE_URL = 'https://ваш-проект.supabase.co';
window.SUPABASE_ANON_KEY = 'ваш-anon-ключ';

// Бесплатный ключ для облачного распознавания чеков (OCR.space),
// получить на https://ocr.space/ocrapi без привязки карты. Необязателен —
// без него скан чека работает локально через Tesseract.js.
window.OCR_SPACE_API_KEY = 'ваш-ocr-space-ключ';
