// Kill switch, not a cache.
//
// The app is built with --pwa-strategy=none, so Flutter no longer
// generates a service worker and new visitors never register one. But
// anyone who loaded an earlier build still has the old Flutter worker
// installed, and it keeps serving that build's files from the Cache API —
// which is why deploys appeared not to land no matter how many times the
// page was reloaded.
//
// Browsers re-fetch a registered worker's script on navigation. This file
// sits at the path the old worker was registered under, so it is picked up
// as an update, takes over immediately, clears every cache it left behind,
// unregisters itself, and reloads open tabs onto the real network copy.
// After that there is no worker left to go stale.
//
// NOTE: --pwa-strategy=none does not skip this file, it writes a 0-byte
// one, which overwrites this source. So the build step copies this file
// over build/web/flutter_service_worker.js after `flutter build web`.
// Do not add caching here.

self.addEventListener('install', () => {
  // Do not wait for existing tabs to close before taking over.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        const names = await caches.keys();
        await Promise.all(names.map((name) => caches.delete(name)));
      } catch (_) {
        // A failed cache purge must not stop the unregister below.
      }

      await self.registration.unregister();

      // Reload any open tab so it leaves the dead worker behind and
      // fetches the current build.
      const clients = await self.clients.matchAll({ type: 'window' });
      for (const client of clients) {
        client.navigate(client.url);
      }
    })(),
  );
});

// Never intercept a request while this worker is briefly alive.
self.addEventListener('fetch', () => {});
