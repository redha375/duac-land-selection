const CACHE='taamir-static-v2';
const FILES=['./','./index.html','./style.css','./app.js','./manifest.webmanifest','./assets/taamir-logo.jpg','./assets/icon-192.png','./assets/icon-512.png','./vendor/leaflet/leaflet.css','./vendor/leaflet/leaflet.js'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES))));
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith('duac-parcel-static-'))await caches.delete(key);await self.clients.claim()})()));
self.addEventListener('fetch',event=>{
  const url=new URL(event.request.url);
  if(url.hostname.includes('tile.openstreetmap.org')) return;
  event.respondWith(caches.match(event.request).then(cached=>cached||fetch(event.request).then(response=>{
    if(response.ok&&url.origin===location.origin)caches.open(CACHE).then(cache=>cache.put(event.request,response.clone()));
    return response;
  }).catch(()=>caches.match('./index.html'))));
});
