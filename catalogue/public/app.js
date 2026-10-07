const $ = (selector) => document.querySelector(selector);
let current = null;
let tries = 0;
let hits = 0;
// Ce que le navigateur a observé sur le chemin des médias, pour la carte du déploiement.
const vu = { statut: null, cache: null, origine: null, via: null };

function showAlert(text) {
  $('#alert').textContent = text;
  $('#alert').hidden = !text;
}

async function timed(url) {
  const start = performance.now();
  const res = await fetch(url, { cache: 'no-store' });
  const body = await res.blob();
  return { res, body, ms: Math.round(performance.now() - start) };
}

async function loadCatalogue() {
  $('#api-status').innerHTML = '<span class="badge">…</span>';
  try {
    const { res, body, ms } = await timed('/api/catalogue');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = JSON.parse(await body.text());
    $('#api-status').innerHTML = '<span class="badge ok">200</span>';
    $('#api-ms').textContent = `${ms} ms`;
    $('#api-version').textContent = data.version;
    $('#api-instance').textContent = data.instance;
    $('#api-region').textContent = data.region;
    $('#env').innerHTML = `<b>${data.plateforme}</b> / ${data.region}`;
    renderVideos(data.videos);
  } catch (error) {
    $('#api-status').innerHTML = '<span class="badge err">erreur</span>';
    showAlert(`Le catalogue ne répond pas (${error.message}). Vérifiez la route /api/* de l’URL map et le service Cloud Run.`);
  }
}

function renderVideos(videos) {
  const list = $('#videos');
  list.replaceChildren(...videos.map((video) => {
    const button = document.createElement('button');
    button.className = 'video';
    button.style.setProperty('--c', video.couleur);
    button.innerHTML = '<span class="thumb"></span><span><strong></strong><span class="muted small"></span></span>';
    button.querySelector('strong').textContent = video.titre;
    button.querySelector('.muted').textContent = `${video.duree} / ${video.media}`;
    button.addEventListener('click', () => play(video, button));
    return button;
  }));
  if (!current && videos.length) list.firstElementChild.click();
}

function play(video, button) {
  current = video;
  document.querySelectorAll('.video').forEach((item) => item.classList.toggle('active', item === button));
  $('#player').src = video.media;
  $('#now').textContent = `${video.titre}, servie depuis ${video.media}`;
}

async function testMedia() {
  if (!current) return;
  try {
    const { res, body, ms } = await timed(current.media);
    const status = (res.headers.get('x-cache-status') || (res.headers.get('age') ? 'hit' : 'inconnu')).toUpperCase();
    const fromCache = status === 'HIT';
    vu.statut = res.status;
    vu.via = res.headers.get('via') || vu.via;
    if (fromCache) vu.cache = res.headers.get('x-cache-status') ? `X-Cache-Status: ${res.headers.get('x-cache-status')}` : `Age: ${res.headers.get('age')}`;
    const classe = res.headers.get('x-goog-storage-class');
    if (classe) vu.origine = `x-goog-storage-class: ${classe}`;
    tries += 1;
    if (fromCache) hits += 1;
    $('#hop-cdn').className = 'on';
    $('#hop-bucket').className = fromCache ? '' : 'on';
    addRow(res.status, `${Math.round(body.size / 1024)} Ko`, `${ms} ms`, status, res.ok);
    if (!res.ok) showAlert(`La vidéo renvoie ${res.status}. Vérifiez le nom exact de l’objet, le préfixe conservé par le routage et le backend choisi par l’URL map.`);
    else showAlert('');
  } catch (error) {
    tries += 1;
    vu.statut = 0;
    addRow('erreur', '', '', error.message, false);
  }
  $('#media-count').textContent = tries;
  $('#media-hits').textContent = `${hits} / ${tries}`;
  carte();
}

const bloc = (id, nom, etat, detail = '', preuve = '') => ({ id, nom, etat, detail, preuve });

// Le serveur fournit ses blocs ; le navigateur ajoute ceux qu'il est seul à pouvoir observer.
async function carte() {
  let serveur;
  try {
    serveur = await (await fetch('/api/deploiement', { cache: 'no-store' })).json();
  } catch {
    return;
  }
  const local = serveur.plateforme === 'local';
  const blocs = [...serveur.blocs];

  if (local) blocs.push(bloc('lb', 'Load Balancer et URL map', 'simule', 'nginx, local/edge.conf'));
  else if (location.hostname.endsWith('.run.app')) blocs.push(bloc('lb', 'Load Balancer et URL map', 'inconnu', 'page ouverte par l’URL run.app : ouvrez-la par l’IP ou le domaine du Load Balancer', location.hostname));
  else blocs.push(bloc('lb', 'Load Balancer et URL map', 'ok', 'la page arrive par un autre point d’entrée que l’URL directe de Cloud Run', `hôte ${location.hostname}${vu.via ? `, via: ${vu.via}` : ''}`));

  const route = 'Route /media vers le bucket';
  if (vu.statut === null) blocs.push(bloc('route', route, 'inconnu', 'aucun essai de téléchargement pour l’instant'));
  else if (vu.statut === 200) blocs.push(bloc('route', route, local ? 'simule' : 'ok', 'les vidéos répondent par le même point d’entrée que l’API', `${current?.media} : 200`));
  else blocs.push(bloc('route', route, 'echec', vu.statut === 403 ? 'accès refusé à l’objet : politique d’accès du bucket ?' : 'la vidéo ne répond pas : nom de l’objet, préfixe conservé, backend de l’URL map ?', `${current?.media} : ${vu.statut || 'erreur réseau'}`));

  if (vu.cache) blocs.push(bloc('cdn', 'Cloud CDN', local ? 'simule' : 'ok', 'au moins une réponse est venue du cache', vu.cache));
  else blocs.push(bloc('cdn', 'Cloud CDN', local ? 'simule' : 'inconnu', vu.statut === 200 ? 'aucune réponse du cache observée : CDN activé, objet cacheable ?' : 'en attente d’un téléchargement réussi'));

  if (local) blocs.push(bloc('bucket', 'Cloud Storage', 'simule', 'dossier bucket/media servi par nginx'));
  else if (vu.statut === 200) blocs.push(bloc('bucket', 'Cloud Storage', 'ok', 'l’objet est servi', vu.origine || 'en-têtes Cloud Storage absents de la réponse'));
  else blocs.push(bloc('bucket', 'Cloud Storage', 'inconnu', 'en attente d’un téléchargement réussi'));

  Carte.rendre($('#carte'), [
    { titre: 'Entrée', ids: ['lb'] },
    { titre: 'API', ids: ['run', 'identite'] },
    { titre: 'Médias', ids: ['route', 'cdn', 'bucket'] },
    { titre: 'Exploitation', ids: ['obs'] },
  ], blocs);
}

function addRow(status, size, ms, cache, ok) {
  const log = $('#media-log');
  if (!tries || log.querySelector('td[colspan]')) log.replaceChildren();
  const row = document.createElement('tr');
  const badge = cache === 'HIT' ? 'ok' : cache === 'MISS' || cache === 'EXPIRED' ? 'warn' : ok ? '' : 'err';
  row.innerHTML = `<td class="mono"></td><td></td><td></td><td class="mono"></td><td><span class="badge ${badge}"></span></td>`;
  row.children[0].textContent = new Date().toLocaleTimeString('fr-FR');
  row.children[1].textContent = status;
  row.children[2].textContent = size;
  row.children[3].textContent = ms;
  row.children[4].firstChild.textContent = cache;
  log.prepend(row);
  $('#media-ms').textContent = ms || '…';
}

$('#api-retry').addEventListener('click', loadCatalogue);
$('#media-test').addEventListener('click', testMedia);
$('#media-burst').addEventListener('click', async () => {
  for (let i = 0; i < 5; i++) await testMedia();
});

// Au chargement : le catalogue, puis deux téléchargements pour remplir la carte (le second peut venir du cache).
loadCatalogue().then(async () => {
  await testMedia();
  await testMedia();
});
carte();
setInterval(carte, 15000);
