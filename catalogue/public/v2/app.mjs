import { readProgress, saveProgress, unfinished, formatTime } from './progress.mjs';

const $ = (s, parent = document) => parent.querySelector(s);
const main = $('#main');
const search = $('#search');
const details = {
  'intro-gcp': { category: 'Cloud', image: 'cloud', description: 'Introduction à Google Cloud. Vidéo de démonstration de six secondes.' },
  'terraform-101': { category: 'Infrastructure', image: 'terraform', description: 'Premiers pas avec Terraform. Vidéo de démonstration de six secondes.' },
  'cache-cdn': { category: 'Réseaux', image: 'cdn', description: 'Comprendre le cache d’un CDN. Vidéo de démonstration de six secondes.' },
};
let videos = [], selected = 0, category = 'Tout', query = new URLSearchParams(location.search).get('q') || '';
let leavePage = () => {};
let storage;
try { storage = window.localStorage; } catch { /* La lecture reste disponible sans stockage. */ }
const escape = (s) => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const url = (v) => `/v2/video/${encodeURIComponent(v.id)}`;
const poster = (v) => `/v2/${v.image}.png`;
const play = '<span class="play-icon" aria-hidden="true"></span>';
const normalize = s => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

function artwork(v) {
  return `<div class="art"><img src="${poster(v)}" alt="" loading="lazy" width="960" height="540"><span class="duration">${escape(v.duree)}</span></div>`;
}
function card(v) {
  return `<a class="card" href="${url(v)}">${artwork(v)}<div class="card-body"><h3>${escape(v.titre)}</h3><p>${escape(v.category)}</p></div></a>`;
}
function renderCarousel() {
  const host = $('.carousel');
  if (!host || !videos.length) return;
  host.innerHTML = videos.map((v, i) => {
    const offset = (i - selected + videos.length) % videos.length;
    const position = offset === 0 ? 'center' : offset === 1 ? 'right' : 'left';
    return `<article class="feature ${position}" aria-label="${escape(v.titre)}">
      <a href="${url(v)}" tabindex="${offset ? '-1' : '0'}" aria-label="Regarder ${escape(v.titre)}">${artwork(v)}</a>
      <div class="feature-content"><h2>${escape(v.titre)}</h2><p>${escape(v.category)}</p><a class="primary" href="${url(v)}" ${offset ? 'tabindex="-1" aria-hidden="true"' : ''}>${play} Regarder</a></div>
    </article>`;
  }).join('') + '<button class="arrow prev" aria-label="Vidéo précédente">‹</button><button class="arrow next" aria-label="Vidéo suivante">›</button>';
  $('.prev', host).onclick = () => move(-1);
  $('.next', host).onclick = () => move(1);
  $('.dots').innerHTML = videos.map((v, i) => `<button class="dot" aria-label="Afficher ${escape(v.titre)}" aria-pressed="${i === selected}" data-index="${i}"></button>`).join('');
  $('.dots').querySelectorAll('button').forEach(b => b.onclick = () => { selected = Number(b.dataset.index); renderCarousel(); $('.dot[aria-pressed=true]').focus(); });
}
function move(step) {
  const old = step < 0 ? '.prev' : '.next';
  selected = (selected + step + videos.length) % videos.length;
  renderCarousel(); $(old).focus();
}
function renderResume() {
  const host = $('.resume-list');
  if (!host) return;
  const progress = readProgress(storage);
  const list = videos.filter(v => unfinished(progress[v.id])).sort((a, b) => progress[b.id].updated - progress[a.id].updated);
  host.innerHTML = list.length ? list.map(v => {
    const p = progress[v.id];
    return `<article class="resume-row"><a href="${url(v)}" aria-label="Reprendre ${escape(v.titre)}">${artwork(v)}</a><div class="resume-info"><h3>${escape(v.titre)}</h3><div class="progress-info"><span>${formatTime(p.position)} / ${formatTime(p.duration)}</span><progress max="${p.duration}" value="${p.position}" aria-label="Progression de ${escape(v.titre)}"></progress></div></div><a class="outline" href="${url(v)}">${play} Reprendre</a></article>`;
  }).join('') : '<div class="empty">Commencez une vidéo : vous pourrez reprendre votre lecture ici.</div>';
}
function renderGrid() {
  const host = $('#video-grid');
  if (!host) return;
  const list = videos.filter(v => (category === 'Tout' || category === v.category) && normalize(`${v.titre} ${v.category}`).includes(normalize(query)));
  host.innerHTML = list.length ? list.map(card).join('') : '<p class="empty">Aucune vidéo ne correspond à votre recherche.</p>';
  $('#result-count').textContent = `${list.length} vidéo${list.length > 1 ? 's' : ''}`;
  main.classList.toggle('searching', !!query);
}
function home() {
  main.innerHTML = `<section class="intro"><p class="eyebrow">APPRENDRE EN VIDÉO</p><h1>Un sujet. Une vidéo. À vous de jouer.</h1></section>
    <section class="carousel" aria-label="Vidéos à la une" aria-roledescription="carrousel"></section><div class="dots" aria-label="Choisir une vidéo"></div>
    <section id="reprendre" class="section"><h2>Reprendre la lecture</h2><p class="section-note">Sur cet appareil</p><div class="resume-list"></div></section>
    <section id="catalogue" class="section"><h2>Toutes les vidéos</h2><div class="filters" aria-label="Thématiques"></div><p id="result-count" class="count" role="status"></p><div id="video-grid" class="grid"></div></section>`;
  const categories = ['Tout', ...new Set(videos.map(v => v.category))];
  $('.filters').innerHTML = categories.map(c => `<button class="filter" aria-pressed="${c === category}">${escape(c)}</button>`).join('');
  $('.filters').querySelectorAll('button').forEach(b => b.onclick = () => {
    category = b.textContent;
    $('.filters').querySelectorAll('button').forEach(item => item.setAttribute('aria-pressed', item === b));
    renderGrid();
  });
  renderCarousel(); renderResume(); renderGrid();
}
function watch(id) {
  const v = videos.find(v => v.id === id);
  if (!v) { main.innerHTML = '<div class="loading"><h1>Vidéo introuvable</h1><a class="outline" href="/v2">Retour au catalogue</a></div>'; return; }
  document.title = `${v.titre} · StreamBox`;
  main.innerHTML = `<a class="back" href="/v2"><span aria-hidden="true">←</span> Retour au catalogue</a>
    <div class="watch-layout"><section class="watch"><div class="video-shell"><video controls playsinline preload="metadata" poster="${poster(v)}" aria-label="${escape(v.titre)}" src="${escape(v.media)}"></video></div>
      <div id="video-error" class="error-box" role="alert" hidden>La vidéo ne peut pas être chargée. <button class="outline" id="retry-video">Réessayer</button></div>
      <div class="tags"><span class="tag category">${escape(v.category)}</span><span class="tag">${escape(v.duree)}</span></div><h1>${escape(v.titre)}</h1><p class="description">${escape(v.description)}</p>
      <div class="memory"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M5 21V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v17l-7-5Z"/></svg><span id="memory-message">Votre lecture est mémorisée sur cet appareil.</span></div></section>
      <aside class="suggestions"><h2>À découvrir</h2>${videos.filter(x => x.id !== id).map(card).join('')}</aside></div>`;
  const player = $('video');
  const previous = readProgress(storage)[id];
  let played = false, lastSaved = -1;
  if (!storage) $('#memory-message').textContent = 'La mémorisation est indisponible dans ce navigateur.';
  player.addEventListener('loadedmetadata', () => { if (unfinished(previous)) player.currentTime = Math.min(previous.position, Math.max(0, player.duration - .25)); });
  function save(force = false) {
    if (!played || (!force && Math.abs(player.currentTime - lastSaved) < .25)) return;
    if (!saveProgress(storage, id, player.currentTime, player.duration)) $('#memory-message').textContent = 'La mémorisation est indisponible dans ce navigateur.';
    lastSaved = player.currentTime;
  }
  player.addEventListener('play', () => { played = true; });
  player.addEventListener('timeupdate', () => save());
  player.addEventListener('pause', () => save(true));
  player.addEventListener('ended', () => save(true));
  player.addEventListener('error', () => { $('#video-error').hidden = false; });
  $('#retry-video').onclick = () => { $('#video-error').hidden = true; player.load(); };
  const onHide = () => save(true);
  document.addEventListener('visibilitychange', onHide);
  window.addEventListener('pagehide', onHide);
  leavePage = () => { save(true); player.pause(); document.removeEventListener('visibilitychange', onHide); window.removeEventListener('pagehide', onHide); };
}
function render() {
  leavePage(); leavePage = () => {};
  main.classList.remove('searching');
  document.title = 'StreamBox · Catalogue pédagogique';
  const route = location.pathname.match(/^\/v2\/video\/([a-z0-9-]+)$/);
  if (route) watch(route[1]); else home();
  const resume = location.hash === '#reprendre';
  $('#nav-catalogue').classList.toggle('active', !resume);
  $('#nav-resume').classList.toggle('active', resume);
  if (resume) $('#reprendre')?.scrollIntoView();
}
document.addEventListener('click', e => {
  const a = e.target.closest('a');
  if (!a || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
  const next = new URL(a.href);
  if (next.origin !== location.origin || !(next.pathname === '/v2' || next.pathname.startsWith('/v2/video/')) || !videos.length) return;
  e.preventDefault();
  query = ''; search.value = ''; history.pushState({}, '', next); render();
  if (!next.hash) window.scrollTo(0, 0);
});
window.addEventListener('popstate', () => { query = new URLSearchParams(location.search).get('q') || ''; search.value = query; render(); });
window.addEventListener('storage', renderResume);
search.value = query;
search.addEventListener('input', () => {
  query = search.value.trim();
  if ($('#video-grid')) { history.replaceState({}, '', `/v2${query ? '?q=' + encodeURIComponent(query) : ''}`); renderGrid(); }
});
$('#search-form').addEventListener('submit', e => {
  e.preventDefault(); query = search.value.trim();
  history.pushState({}, '', `/v2${query ? '?q=' + encodeURIComponent(query) : ''}`); render(); $('#catalogue')?.scrollIntoView();
});
async function load() {
  try {
    const response = await fetch('/api/catalogue', { signal: AbortSignal.timeout(10000) });
    if (!response.ok) throw new Error();
    const data = await response.json();
    videos = data.videos.filter(v => /^[a-z0-9-]+$/.test(v.id) && typeof v.titre === 'string' && /^\/media\/[a-zA-Z0-9._/-]+$/.test(v.media)).map(v => ({...v, category:'Découverte', image:'cloud', description:'Vidéo de démonstration.', ...details[v.id]}));
    if (!videos.length) { main.innerHTML = '<div class="loading">Aucune vidéo disponible pour le moment.</div>'; return; }
    render();
  } catch {
    main.innerHTML = '<div class="loading"><h1>Le catalogue est indisponible</h1><p>Réessayez dans quelques instants.</p><button class="outline" id="retry-catalogue">Réessayer</button></div>';
    $('#retry-catalogue').onclick = load;
  }
}
load();
