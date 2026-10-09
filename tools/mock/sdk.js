// Local stand-in for the Yandex Games SDK, served as /sdk.js by tools/serve.py.
// Lets you click through ads, rewards and the leaderboard without uploading.
(function () {
  const log = (...a) => console.log('[mock-sdk]', ...a);
  const overlay = (label, ms) => new Promise(res => {
    const d = document.createElement('div');
    d.textContent = label;
    d.style.cssText = 'position:fixed;inset:0;z-index:99;display:flex;align-items:center;justify-content:center;background:rgba(0,0,0,.85);color:#fff;font:600 28px system-ui';
    document.body.appendChild(d);
    setTimeout(() => { d.remove(); res(); }, ms);
  });
  const store = { data: {}, scores: [{ rank: 1, score: 212, player: { publicName: 'Алиса', uniqueID: 'a' } }, { rank: 2, score: 160, player: { publicName: 'Борис', uniqueID: 'b' } }] };
  const player = {
    getUniqueID: () => 'me', getMode: () => '', isAuthorized: () => true,
    getData: async () => store.data, setData: async d => { store.data = d; log('setData', d); },
  };
  window.YaGames = {
    init: async () => ({
      environment: { i18n: { lang: new URLSearchParams(location.search).get('lang') || 'ru' } },
      features: {
        LoadingAPI: { ready: () => log('LoadingAPI.ready') },
        GameplayAPI: { start: () => log('GameplayAPI.start'), stop: () => log('GameplayAPI.stop') },
      },
      on: (ev) => log('subscribed', ev),
      getPlayer: async () => player,
      auth: { openAuthDialog: async () => {} },
      adv: {
        showFullscreenAdv: ({ callbacks }) => { log('fullscreen ad'); callbacks.onOpen?.(); overlay('Реклама (тест)', 900).then(() => callbacks.onClose?.(true)); },
        showRewardedVideo: ({ callbacks }) => { log('rewarded ad'); callbacks.onOpen?.(); overlay('Видео за награду (тест)', 1200).then(() => { callbacks.onRewarded?.(); callbacks.onClose?.(); }); },
      },
      leaderboards: {
        setScore: async (n, v) => { log('setScore', n, v); const me = store.scores.find(e => e.player.uniqueID === 'me'); if (me) me.score = Math.max(me.score, v); else store.scores.push({ score: v, player: { publicName: '', uniqueID: 'me' } }); store.scores.sort((a, b) => b.score - a.score).forEach((e, i) => e.rank = i + 1); },
        getEntries: async () => ({ userRank: 0, entries: store.scores }),
      },
    }),
  };
})();
