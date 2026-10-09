import { createLoadRun, PROTOCOL } from './load-runner.mjs';

const $ = id => document.getElementById(id);
let active = null, report = null, busy = false;
function render(s) {
  $('demo-time').textContent = `${Math.floor(s.elapsedMs / 1000)} / 60 s`;
  $('demo-progress').value = s.elapsedMs / 1000;
  $('demo-count').textContent = `${s.responses} / ${PROTOCOL.maxRequests}`;
  $('demo-errors').textContent = s.errors;
  $('demo-bytes').textContent = `${(s.bytes / 1_000_000).toLocaleString('fr-FR', { maximumFractionDigits: 2 })} Mo`;
  for (const kind of ['api', 'media']) {
    $('demo-' + kind + '-count').textContent = `${s[kind].success} / ${s[kind].responses}`;
    $('demo-' + kind + '-p95').textContent = s[kind].p95 === null ? '—' : `${s[kind].p95} ms`;
  }
  $('demo-media-hits').textContent = `${s.media.hits} HIT / ${s.media.responses} réponses`;
  if (s.phase === 'checking') $('demo-status').textContent = 'Vérification de la taille du petit fichier vidéo…';
  else if (s.phase === 'running') $('demo-status').textContent = `Simulation en cours depuis ${new Date(s.startedAt).toLocaleTimeString('fr-FR')}.`;
  else $('demo-status').textContent = s.reason || 'Simulation terminée.';
}
async function simulate() {
  $('demo-stop').disabled = false;
  active = createLoadRun({ onUpdate: render });
  const ticker = setInterval(() => render(active.snapshot()), 500);
  try {
    await active.done;
    report = { origin: location.origin, ...active.report() };
    $('demo-export').disabled = false;
  } finally {
    clearInterval(ticker);
    active = null;
    $('demo-stop').disabled = true;
  }
}
$('demo-start').addEventListener('click', async () => {
  if (busy) return;
  busy = true;
  $('demo-start').disabled = true;
  $('demo-export').disabled = true;
  report = null;
  try {
    // Une seule démo à la fois entre les onglets du même site lorsque Web Locks est disponible.
    if (navigator.locks) await navigator.locks.request('streambox-load-demo', { ifAvailable: true }, async lock => {
      if (lock) await simulate();
      else $('demo-status').textContent = 'Une simulation est déjà en cours dans un autre onglet de ce site.';
    });
    else await simulate();
  } catch (error) {
    $('demo-status').textContent = `Simulation interrompue : ${error.message}`;
  } finally {
    busy = false;
    $('demo-start').disabled = false;
    $('demo-stop').disabled = true;
  }
});
$('demo-stop').addEventListener('click', () => active?.stop());
window.addEventListener('pagehide', () => active?.stop('Page fermée : simulation arrêtée.'));
$('demo-export').addEventListener('click', () => {
  if (!report) return;
  const url = URL.createObjectURL(new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = `streambox-demo-${new Date().toISOString().replaceAll(':', '-')}.json`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
