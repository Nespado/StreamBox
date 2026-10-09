// API catalogue et interface de démonstration pour StreamBox.
// Node.js 22 ou plus récent, sans dépendance. Écoute sur $PORT (8080 par défaut).
// Sur GCP, ce service tourne sur Cloud Run derrière le Load Balancer : /api/* et la page d'accueil
// arrivent ici, /media/* part vers le backend bucket et Cloud CDN.
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import { metadata, bloc, blocCloudRun, blocIdentite, enCache } from './gcp.mjs';

const here = new URL('.', import.meta.url);
const catalogue = JSON.parse(fs.readFileSync(new URL('catalogue.json', here), 'utf8'));
const version = process.env.APP_VERSION || 'dev';
const assets = {
  '/': ['index.html', 'text/html; charset=utf-8'],
  '/app.js': ['app.js', 'text/javascript; charset=utf-8'],
  '/kit.css': ['kit.css', 'text/css; charset=utf-8'],
  '/carte.js': ['carte.js', 'text/javascript; charset=utf-8'],
  '/load-demo.js': ['load-demo.js', 'text/javascript; charset=utf-8'],
  '/load-runner.mjs': ['load-runner.mjs', 'text/javascript; charset=utf-8'],
};

// Sur Cloud Run, K_SERVICE et K_REVISION sont fournis, et le serveur de métadonnées donne la région.
const plateforme = process.env.K_SERVICE ? 'Cloud Run' : 'local';
const region = (await metadata('instance/region'))?.split('/').pop() || 'local';
const instance = process.env.K_REVISION || os.hostname();

// La part de la carte que le serveur peut établir seul. Le navigateur ajoute ensuite ce qu'il observe
// lui-même : le passage par le Load Balancer, le routage des médias et le cache.
const deploiement = enCache(async () => ({
  plateforme,
  blocs: [
    blocCloudRun('API sur Cloud Run'),
    await blocIdentite(),
    bloc('obs', 'Logging et Monitoring', 'manuel', 'logs du Load Balancer, dashboard et alertes : invisibles depuis l’application, montrez-les dans la console'),
  ],
}));

function send(res, status, body, type = 'application/json; charset=utf-8') {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  res.end(type.startsWith('application/json') ? JSON.stringify(body) : body);
}

const server = http.createServer((req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  // Une ligne JSON par requête : Cloud Logging la lit comme un journal structuré.
  console.log(JSON.stringify({ severity: 'INFO', message: `${req.method} ${pathname}` }));

  if (req.method !== 'GET' && req.method !== 'HEAD') return send(res, 405, { erreur: 'méthode non autorisée' });
  if (pathname === '/healthz') return send(res, 200, { statut: 'ok', version });
  if (pathname === '/api/catalogue') return send(res, 200, { version, plateforme, region, instance, videos: catalogue });
  if (pathname === '/api/deploiement') return deploiement().then((carte) => send(res, 200, carte));

  const route = pathname.match(/^\/api\/catalogue\/([a-z0-9-]+)$/);
  if (route) {
    const video = catalogue.find((item) => item.id === route[1]);
    return video ? send(res, 200, video) : send(res, 404, { erreur: 'vidéo inconnue' });
  }
  if (assets[pathname]) {
    const [file, type] = assets[pathname];
    return send(res, 200, fs.readFileSync(new URL(`public/${file}`, here)), type);
  }
  if (pathname.startsWith('/media/')) {
    // Si une vidéo arrive ici, c'est que le routage vers le bucket ne s'est pas fait.
    return send(res, 404, { erreur: 'les médias ne sont pas servis par Cloud Run : passez par le Load Balancer', chemin: pathname });
  }
  send(res, 404, { erreur: 'route inconnue', chemin: pathname });
});

server.listen(Number(process.env.PORT || 8080), () => {
  console.log(JSON.stringify({ severity: 'INFO', message: `catalogue prêt sur le port ${server.address().port}, version ${version}` }));
});
process.on('SIGTERM', () => server.close(() => process.exit(0)));
