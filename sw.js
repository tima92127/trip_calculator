const CACHE = 'trip-calc-v3';
const SHELL = ['./', './index.html', './manifest.json', './icon.svg'];

self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE)
            .then(cache => cache.addAll(SHELL))
            .then(() => self.skipWaiting())
    );
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys()
            .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
            .then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const request = event.request;
    if (request.method !== 'GET') return;

    const url = new URL(request.url);

    // Запросы к Supabase не кэшируем: офлайн-очередь в приложении сама их накапливает
    if (url.hostname.endsWith('supabase.co')) return;

    // Свои файлы (включая vendor/ — supabase-js, chart.js, tesseract.js больше не
    // грузятся с CDN): сначала сеть (чтобы правки доезжали), при её отсутствии — кэш
    event.respondWith(
        fetch(request)
            .then(response => {
                const copy = response.clone();
                caches.open(CACHE).then(cache => cache.put(request, copy));
                return response;
            })
            .catch(() => caches.match(request).then(hit => hit || caches.match('./index.html')))
    );
});
