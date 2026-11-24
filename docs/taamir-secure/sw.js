const CACHE='taamir-secure-v3.3';
const FILES=['./','./index.html','../assets/icon-512.png','../assets/taamir-logo.jpg','./manifest.webmanifest'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES))));
self.addEventListener('fetch',event=>{if(event.request.url.includes('tile.')||event.request.url.includes('arcgisonline.com'))return;event.respondWith(caches.match(event.request).then(cached=>cached||fetch(event.request)));});
