let simulatedOffline = false;
const CACHE_NAME = 'resqway-shell-v1';
const CORE_ASSETS = [
  '/manifest',
  '/dashboard',
  '/routes',
  // You might want to cache specific icons here, e.g. '/icon.png'
];

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SIMULATE_OFFLINE_TOGGLE") {
    simulatedOffline = event.data.value;
    console.log('[Service Worker] Simulated offline mode set to:', simulatedOffline);
  }
});

// Install event: Cache core assets (App Shell)
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Caching core assets');
      return cache.addAll(CORE_ASSETS);
    })
  );
  self.skipWaiting();
});

// Activate event: Clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[Service Worker] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event: Network-first for pages, Cache-first for static assets
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // 1. Navigation requests (HTML pages) - Network first, fallback to cache
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        if (simulatedOffline) {
          console.log('[Service Worker] Simulated offline navigation fallback');
          return caches.match(request);
        }

        try {
          const response = await fetch(request);
          const responseToCache = response.clone();
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, responseToCache);
          return response;
        } catch (error) {
          return caches.match(request);
        }
      })()
    );
    return;
  }

  // 2. Static Assets (CSS, JS, Images) - Cache first, fallback to network
  if (request.destination === 'style' || request.destination === 'script' || request.destination === 'image') {
    event.respondWith(
      caches.match(request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        
        if (simulatedOffline) {
          // If offline and not in cache, let it fail natively
          return Promise.reject('Simulated offline: asset not in cache');
        }

        return fetch(request).then((response) => {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
          });
          return response;
        });
      })
    );
    return;
  }
});
